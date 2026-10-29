class_name Match
extends Node3D
## One match on one map: loads the map, spawns the player and the bots, runs capture points, pickups, crates, NPCs, hazards,
## scores, respawns and the end of the match. HUD and menus are children of this node (see Hud.gd and the ui scripts).

signal score_changed(red: int, blue: int)
signal ended(winner: String)
signal toast(text: String, color: Color)
signal player_respawn_timer(seconds: float)

const RESPAWN_TIME := 5.0
const POINT_TICK := 3.0

var map_id := ""
var mode := "domination"
var score_limit := 200
var time_left := 600.0
var score := {"red": 0, "blue": 0}
var combatants: Array[Combatant] = []
var player: Player = null
var capture_points: Array[CapturePoint] = []
var pickups: Array[PickupNode] = []
var hazards: Array[HazardNode] = []
var crates: Array[LootCrateNode] = []
var npcs: Array[NpcNode] = []
var interactables: Array[Node] = []
var surfaces: Array = []
var quests: Quests
var hud: Hud
var spawns := {"red": [], "blue": []}
var markers: Array = []
var kill_plane_y := -80.0
var map_size := Vector2(240, 240)
var reveal_loot_until := 0.0
var finished := false
var _point_acc := 0.0
var _respawn: Dictionary = {}            # combatant -> seconds left
var _surface_acc := 0.0
var _ghosts: Array = []
var _info: Dictionary = {}
var door_markers: Array = []             # Desert Tomb gates and their pressure plates
var cover_markers: Array = []            # Chess Arena: pieces that walk along a line
var plate_markers: Array = []
var plates: Array[PlateNode] = []
var lanterns: Array = []                 # Shadow Crypt: {pos, r}; enemies inside the light of a lantern show on the minimap
var moon: Dictionary = {}                # Moon Sanctuary: the phase controller marker
var moon_altars: Array = []
var moon_index := -1
var _moon_t := 0.0
var _moon_labels: Array = []
var flags: Dictionary = {}               # capture the flag: team -> FlagNode
var _client_respawn_left := 0.0          # LAN client: seconds until the host brings the player back

## What each moon phase does for both teams (the texts are in the marker, these are the numbers).
const MOON_MODS := [
	{"move_speed": {"mult": 0.08}},
	{"mana_regen": {"mult": 0.10}},
	{"weapon_damage": {"mult": 0.10}, "spell_damage": {"mult": 0.10}, "skill_damage": {"mult": 0.10}},
	{"armor": {"add": 0.12}},
	{"heal_power": {"mult": 0.15}},
	{"crit_chance": {"add": 0.10}},
	{"cooldown_reduction": {"add": 0.15}},
	{"move_speed": {"mult": 0.08}, "sight": {"mult": 0.08}},
]
var airdrops: Array[AirDropNode] = []
var _airdrop_timer := 45.0

const BOT_NAMES := ["Aldric", "Brynn", "Cael", "Dara", "Eryn", "Fenn", "Garo", "Hale", "Isolde", "Jorin", "Kestrel", "Lyra", "Maren", "Nyx", "Orrin", "Pell", "Quill", "Rhea", "Soren", "Tamsin",
	"Ulric", "Vesper", "Wren", "Xan", "Yara", "Zeph", "Arden", "Bryce", "Cora", "Dax", "Elara", "Finn", "Gwen", "Hugo", "Ivy", "Joss"]


func start(id: String, class_id: String) -> void:
	map_id = id
	mode = Game.game_mode
	if Net.active:
		seed(int(Net.match_info.get("seed", 1)))              # every machine builds the same random decor
	Game.new_run()
	MapLoader.apply_environment(self, id)
	var built := MapLoader.build(self, id)
	markers = built["markers"]
	_info = built["info"]
	var sz: Array = built["size"]
	map_size = Vector2(float(sz[0]), float(sz[1]))
	_read_markers()
	_add_extra_npcs()
	if OS.get_environment("NO_DECOR") == "":
		Decor.scatter(self, id, built["root"], map_size)
		Border.dress(self, id, built["root"], map_size)
	Perch.build(self, built["root"], map_size)
	var gov := PerfGovernor.new()
	gov.name = "PerfGovernor"
	add_child(gov)
	gov.setup(self)
	_settle_water()
	_settle_crates()
	if OS.get_environment("NO_CRITTERS") == "":
		Critters.attach(self, id, map_size, markers)
	quests = Quests.new()
	quests.match_ref = self
	add_child(quests)
	_spawn_player(class_id)
	if OS.get_environment("FX_LITE") == "":
		AtmosphereFx.attach(self, id, player)
	if not Net.is_client:                                          # on a joined machine every other fighter is a copy of one on the host
		_spawn_bots()
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(self)
	_wire_player()
	if mode == "tdm":
		score_limit = 40
	elif mode == "ctf":
		score_limit = 3
		_make_flags()
	time_left = 600.0
	var bn := String(Data.maps[id].get("buffed_class", ""))
	var dn := String(Data.maps[id].get("debuffed_class", ""))
	var buff_text := "%s buffed, %s weakened" % [bn, dn] if bn != "" and dn != "" else "a neutral board: no class is buffed or weakened"
	hud_toast("%s: %s" % [Data.maps[id]["title"], buff_text], Color(1, 0.9, 0.5))
	if Net.active:
		Net.attach(self)


# ================================================================= setup

func _read_markers() -> void:
	for m in markers:
		var kind: String = m.get("kind", "")
		var name: String = m["name"]
		match kind:
			"spawn":
				var t := "red" if name.begins_with("team_red") else "blue"
				spawns[t].append(m["pos"])
			"capture":
				var cp := CapturePoint.new()
				add_child(cp)
				cp.position = m["pos"]
				cp.setup(String(m.get("point", "A")), float(m.get("radius", 8.0)))
				cp.captured.connect(_on_captured)
				capture_points.append(cp)
			"pickup":
				var p := PickupNode.new()
				add_child(p)
				p.position = m["pos"]
				p.setup(String(m.get("item", "health")))
				pickups.append(p)
			"loot_crate":
				var cr := LootCrateNode.new()
				add_child(cr)
				cr.position = m["pos"]
				cr.match_ref = self
				cr.setup(String(m.get("rarity", "roll")) == "gold", float(m.get("respawn_seconds", 90.0)))
				cr.opened.connect(_on_crate_opened)
				crates.append(cr)
				interactables.append(cr)
			"npc":
				var n := NpcNode.new()
				add_child(n)
				n.setup(m, self)
				npcs.append(n)
				interactables.append(n)
			"hazard", "jump_pad", "bounce_pad", "slide", "current", "updraft", "spore_pod", "cannon":
				var h := HazardNode.new()
				add_child(h)
				h.setup(m, self)
				hazards.append(h)
				if kind == "cannon":
					interactables.append(h)
			"moving_cover":
				cover_markers.append(m)
			"door":
				door_markers.append(m)
			"plate":
				plate_markers.append(m)
			"lantern":
				lanterns.append({"pos": m["pos"], "r": float(m.get("reveal_radius", 12.0))})
			"moon_phases":
				moon = m
			"moon_altar":
				moon_altars.append(m["pos"])
			"kill_plane":
				kill_plane_y = float(m["pos"].y)
	if kill_plane_y < -200.0:
		kill_plane_y = -80.0
	var root := get_node("Map")
	_make_doors_and_plates(root)
	_make_moon()
	var first_pad := true
	for pad in root.get_meta("mushroom_pads", []):
		if first_pad and OS.get_environment("TOAST_DEBUG") != "":
			first_pad = false
			print("MUSHPAD ", pad["pos"], " r ", snappedf(pad["radius"], 0.1), " speed ", snappedf(pad["launch_speed"], 0.1))
		var hz := HazardNode.new()
		add_child(hz)
		hz.setup(pad, self)
		hazards.append(hz)
	for c in root.get_children():
		if c is StaticBody3D and c.has_meta("surface"):
			surfaces.append(c)


func spawn_point(team: String) -> Vector3:
	var list: Array = spawns[team]
	if list.is_empty():
		return Vector3(0, 5, 0)
	var best: Vector3 = list[0]
	var best_d := -1.0
	for i in 5:
		var p: Vector3 = list[randi() % list.size()]
		var dmin := 1e9
		for c in combatants:
			if not c.dead and c.team != team:
				dmin = minf(dmin, c.global_position.distance_to(p))
		if dmin > best_d:
			best_d = dmin
			best = p
	return best + Vector3(randf_range(-1.5, 1.5), 0.3, randf_range(-1.5, 1.5))


func _spawn_player(class_id: String) -> void:
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.match_ref = self
	var my_team := Net.my_team if Net.is_client else "red"
	player.setup_player(class_id, "You", my_team)
	player.global_position = spawn_point(my_team)
	player.face_toward(-player.global_position, true)
	combatants.append(player)
	player.died.connect(_on_died.bind(player))


func _spawn_bots() -> void:
	var n := Game.bots_per_team
	var classes: Array = Data.class_order
	var names: Array = BOT_NAMES.duplicate()
	names.shuffle()
	var k := 0
	for i in n:
		var b := _add_bot("red", classes[randi() % classes.size()], names[k % names.size()])
		b.set_meta("ctf_role", "defend" if i % 3 == 0 else "attack")
		k += 1
	for i in n + 1:
		var b := _add_bot("blue", classes[randi() % classes.size()], names[k % names.size()])
		b.set_meta("ctf_role", "defend" if i % 3 == 0 else "attack")
		k += 1


func _add_bot(team: String, cls: String, nm: String) -> Bot:
	var b := Bot.new()
	b.name = nm
	add_child(b)
	b.match_ref = self
	b.setup_bot(cls, team, nm, randf_range(0.35, 0.8))
	b.global_position = spawn_point(team)
	b.face_toward(-b.global_position, true)
	b.died.connect(_on_died.bind(b))
	combatants.append(b)
	return b


## LAN host: a fighter that another machine steers. It stands where that player's own copy of the game says and fights with that player's gear.
func _add_remote(peer_id: int, info: Dictionary) -> RemotePlayer:
	var r := RemotePlayer.new()
	r.name = "Remote%d" % peer_id
	add_child(r)
	r.match_ref = self
	r.peer_id = peer_id
	r.setup_remote(info)
	r.global_position = spawn_point(String(info["team"]))
	r.died.connect(_on_died.bind(r))
	combatants.append(r)
	return r


## LAN client: the host says a fighter died (killer may be null). Kill feed, death screen and respawn countdown.
func client_died(victim: Combatant, killer: Combatant, respawn_in: float) -> void:
	hud.add_kill_feed(killer, victim)
	if victim == player:
		hud.on_player_died(killer)
		quests.on_event("death", {})
		_client_respawn_left = respawn_in


func client_respawned(c: Combatant) -> void:
	if c == player:
		_client_respawn_left = 0.0
		hud.on_respawn()


## LAN client: the host's score, clock and point ownership arrive about twenty times a second.
func client_world(time_left_host: float, red: int, blue: int, cps: Array, pickups_up: Array) -> void:
	time_left = time_left_host
	if red != score["red"] or blue != score["blue"]:
		score["red"] = red
		score["blue"] = blue
		score_changed.emit(red, blue)
	for i in mini(cps.size(), capture_points.size()):
		var cp := capture_points[i]
		var before := cp.owner_team
		cp.progress = float(cps[i][0])
		cp.owner_team = String(cps[i][1])
		cp._paint()
		cp.present_red = 0
		cp.present_blue = 0
		if before != cp.owner_team and cp.owner_team != "":
			Sfx.play("coin")
	for i in mini(pickups_up.size(), pickups.size()):
		pickups[i].set_up(bool(pickups_up[i]))


func client_end(winner: String) -> void:
	if finished:
		return
	finished = true
	Game.record_match(self, winner)
	ended.emit(winner)
	hud.show_result(winner)


func _client_tick(delta: float) -> void:
	for pl in plates:
		pl.tick(delta, combatants)
	for h in hazards:
		h.tick(delta, [player])                                  # pads, currents and updrafts move the local player at once; the host does the damage
	if _client_respawn_left > 0.0:
		_client_respawn_left -= delta
		player_respawn_timer.emit(maxf(_client_respawn_left, 0.0))


func spawn_minion(kind: String, pos: Vector3, owner_c: Combatant, dur: float) -> void:
	if Net.is_client:
		return                                                   # the host makes the summons; they arrive like any other fighter
	var cls := owner_c.class_id if kind in ["mirror", "decoy"] else "necromancer"
	var b := Bot.new()
	b.name = "Minion"
	add_child(b)
	b.match_ref = self
	b.setup_bot(cls, owner_c.team, "", 0.5)
	b.global_position = pos
	b.minion_of = owner_c
	b.life_left = dur
	b.is_decoy = kind == "decoy"
	b.skill_ids = owner_c.skill_ids.duplicate()
	if kind == "mirror":
		b.stats.set_source("minion", {"weapon_damage": {"mult": -0.6}, "spell_damage": {"mult": -0.6}, "skill_damage": {"mult": -0.6}, "max_health": {"mult": -0.5}})
		b.health = b.max_health()
	elif kind == "skeleton":
		b.model.scale *= 0.8
		b.stats.set_source("minion", {"max_health": {"mult": -0.6}, "weapon_damage": {"mult": -0.5}})
		b.health = b.max_health()
	b.set_plate_hidden()
	b.died.connect(func(_k: Node) -> void:
		combatants.erase(b)
		Util.after(self, 1.5, func() -> void:
			if is_instance_valid(b):
				b.queue_free()))
	combatants.append(b)
	Fx.impact(pos + Vector3(0, 1, 0), Color(0.7, 0.8, 1.0), true)


func spawn_ghost(pos: Vector3, speed: float, dmg: float) -> void:
	if Net.is_client:
		return
	var g := GhostNode.new()
	add_child(g)
	g.global_position = pos
	g.setup(self, speed, dmg)


func _wire_player() -> void:
	player.killed_enemy.connect(_on_player_kill)
	player.damaged.connect(func(amount: float, _s: Node, info: Dictionary) -> void:
		quests.on_event("damage_taken", {"amount": amount, "projectile": info.get("ranged", false)}))
	player.dealt.connect(func(_v: Node, amount: float, info: Dictionary) -> void:
		quests.on_event("damage_dealt", {"amount": amount, "aoe": info.get("aoe", false)})
		quests.on_event("hit", {"crit": info.get("crit", false)}))
	player.missed.connect(func() -> void: quests.on_event("miss", {}))
	player.skill_used.connect(func(slot: String, _sk: Dictionary) -> void:
		quests.on_event("skill_used", {"slot": slot})
		if slot in ["s1", "s2", "s3", "sig"]:
			pass)
	player.meter_full.connect(func() -> void: quests.on_event("meter_full", {}))
	player.statuses.status_removed.connect(func(id: String) -> void:
		if Data.statuses[id]["harmful"]:
			quests.on_event("status_removed", {}))
	player.interact_prompt.connect(hud.set_prompt)


# ================================================================= per frame

func _physics_process(delta: float) -> void:
	if finished:
		return
	if Net.is_client:
		_client_tick(delta)
		return
	time_left -= delta
	if mode == "ctf":
		for t in flags:
			(flags[t] as FlagNode).tick(delta, combatants)
		if OS.get_environment("TOAST_DEBUG") != "" and int(time_left) % 10 == 0 and int(time_left * 10.0) % 10 == 0:
			for t in flags:
				var fl: FlagNode = flags[t]
				var near := 999.0
				for c in combatants:
					if c.team != t and not c.dead:
						near = minf(near, c.global_position.distance_to(fl.global_position))
				print("FLAG ", t, " ", fl.state, " at ", fl.global_position.snapped(Vector3.ONE), " nearest enemy ", snappedf(near, 0.1))
	else:
		for cp in capture_points:
			cp.tick(delta, combatants)
	_tick_airdrops(delta)
	_tick_moon(delta)
	for pl in plates:
		pl.tick(delta, combatants)
	for p in pickups:
		p.tick(delta, combatants)
	for h in hazards:
		h.tick(delta, combatants)
	quests.tick(delta)
	_tick_respawns(delta)
	_tick_surfaces(delta)
	if mode == "domination":
		_point_acc += delta
		if _point_acc >= POINT_TICK:
			_point_acc -= POINT_TICK
			for cp in capture_points:
				if cp.owner_team != "":
					_add_score(cp.owner_team, 1)
	for c in combatants:
		if not c.dead and c.global_position.y < kill_plane_y:
			c.take_damage(99999.0, null, {"dot": "void", "no_status": true})
	if time_left <= 0.0:
		_end("red" if score["red"] > score["blue"] else ("blue" if score["blue"] > score["red"] else "draw"))


func _tick_surfaces(delta: float) -> void:
	if surfaces.is_empty():
		return
	_surface_acc += delta
	if _surface_acc < 0.2:
		return
	var step := _surface_acc
	_surface_acc = 0.0
	for c in combatants:
		if c.dead:
			continue
		var space := c.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(c.global_position + Vector3(0, 1.2, 0), c.global_position - Vector3(0, 1.6, 0), 8)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var kind: String = String(hit["collider"].get_meta("surface", ""))
		if kind == "lava":
			c.statuses.apply("burn", 3.0, 2, null)
			c.take_damage(30.0 * step, null, {"dot": "lava", "no_status": true, "color": [1.0, 0.5, 0.1]})
		elif kind == "shallow_water":
			c.statuses.apply("slow", 0.6, 1, null)


func _tick_respawns(delta: float) -> void:
	for c in _respawn.keys():
		_respawn[c] -= delta
		if c == player:
			player_respawn_timer.emit(maxf(_respawn[c], 0.0))
		if _respawn[c] <= 0.0:
			_respawn.erase(c)
			if is_instance_valid(c):
				c.respawn(spawn_point(c.team))
				if c == player:
					hud.on_respawn()


# ================================================================= events

func _on_died(killer: Node, c: Combatant) -> void:
	if Net.is_client:
		return                                                   # the host sends the deaths (client_died)
	if c is Bot and (c as Bot).life_left >= 0.0:
		return
	if killer is Combatant and killer != c:
		if mode != "ctf":                      # in capture the flag only flags score
			_add_score((killer as Combatant).team, 1)
		(killer as Combatant).score_points += 1
	_respawn[c] = RESPAWN_TIME
	if c == player:
		hud.on_player_died(killer)
		quests.on_event("death", {})
	hud.add_kill_feed(killer, c)


func _on_player_kill(victim: Node) -> void:
	var v := victim as Combatant
	var behind := false
	var to_attacker := player.global_position - v.global_position
	to_attacker.y = 0.0
	if to_attacker.length() > 0.1 and v.forward_vector().dot(to_attacker.normalized()) < -0.2:
		behind = true
	var info := v.last_damage_info
	quests.on_event("kill", {"behind": behind, "aoe": info.get("aoe", false), "own_hp": player.health / player.max_health(),
		"high": player.global_position.y - v.global_position.y > 3.0, "oneshot": v.hp_before_last >= v.max_health() * 0.95,
		"slot": player.last_skill_slot if info.get("skill", false) else "", "after_sprint": Time.get_ticks_msec() / 1000.0 - float(player.get_meta("last_sprint", -99.0)) < 3.0})
	hud.on_player_kill(v)
	if v.has_meta("hunter_mark_by") and v.get_meta("hunter_mark_by") == player:
		for s in player.cooldowns:
			player.cooldowns[s] = 0.0


func _on_captured(team: String, cp: CapturePoint) -> void:
	if team == "red" and cp.present_red > 0:
		quests.on_event("capture", {})
	hud_toast("%s captured point %s" % [team.capitalize(), cp.point_name], Color(1.0, 0.4, 0.35) if team == "red" else Color(0.4, 0.6, 1.0))
	Net.toast_all("%s captured point %s" % [team.capitalize(), cp.point_name], Color(1.0, 0.4, 0.35) if team == "red" else Color(0.4, 0.6, 1.0))
	_add_score(team, 5)


func _on_crate_opened(crate: LootCrateNode, result: Dictionary) -> void:
	quests.on_event("crate", {})
	hud.show_crate_open(crate, result)


func _add_score(team: String, n: int) -> void:
	score[team] += n
	score_changed.emit(score["red"], score["blue"])
	if score[team] >= score_limit:
		_end(team)


func _end(winner: String) -> void:
	if finished:
		return
	finished = true
	Game.record_match(self, winner)
	ended.emit(winner)
	hud.show_result(winner)
	Net.host_ended(winner)


func hud_toast(text: String, color: Color = Color.WHITE) -> void:
	if OS.get_environment("TOAST_DEBUG") != "":
		print("TOAST ", snappedf(180.0 * 10.0 - time_left, 0.1), " ", text)
	toast.emit(text, color)


func explosion(pos: Vector3, r: float, dmg: float, source: Combatant, color: Color) -> void:
	Fx.impact(pos + Vector3(0, 0.5, 0), color, true)
	Fx.ring(pos, r, color, 0.5)
	for e in enemies_of(source.team):
		if not e.dead and e.global_position.distance_to(pos) <= r:
			source.deal(e, dmg, {"magic": true, "aoe": true, "skill": true, "no_status": true})


# ================================================================= queries

func enemies_of(team: String) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in combatants:
		if c.team != team and is_instance_valid(c):
			out.append(c)
	return out


func allies_of(team: String) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in combatants:
		if c.team == team and is_instance_valid(c):
			out.append(c)
	return out


func in_enemy_half(c: Combatant) -> bool:
	var p := c.global_position
	var blender_sum := p.x + (-p.z)                  # x + y in Blender axes: red owns the negative half
	return blender_sum > 0.0 if c.team == "red" else blender_sum < 0.0


func player_on_capture_point() -> bool:
	for cp in capture_points:
		if cp.global_position.distance_to(player.global_position) <= cp.radius:
			return true
	return false


## Desert Tomb: gates that slide into the ground, and the pressure plates that work them.
func _make_doors_and_plates(root: Node) -> void:
	var parts_by_name: Dictionary = root.get_meta("door_parts", {})
	var doors := {}
	for dm in door_markers:
		var nm := String(dm["name"])
		if not parts_by_name.has(nm):
			continue
		var d := DoorNode.new()
		add_child(d)
		d.setup(parts_by_name[nm], float(dm.get("slide_down", 7.0)), String(dm.get("state", "closed")) == "open")
		doors[nm] = d
	for cm in cover_markers:
		var nm := String(cm.get("object", ""))
		if not parts_by_name.has(nm) or not cm.has("path_xy"):
			continue
		var pxy: Array = cm["path_xy"]
		var lp := LivingPiece.new()
		add_child(lp)
		lp.setup(parts_by_name[nm], Vector3(float(pxy[2]) - float(pxy[0]), 0.0, -(float(pxy[3]) - float(pxy[1]))), float(cm.get("move_seconds", 6.0)), float(cm.get("pause_seconds", 10.0)),
			bool(cm.get("ping_pong", true)), 1.0 + 7.0 * float(absi(nm.hash()) % 1000) / 1000.0)      # the same on every machine of a LAN game
	for pm in plate_markers:
		var p := PlateNode.new()
		add_child(p)
		p.setup(pm, self)
		p.door = doors.get(String(pm.get("controls", "")))
		plates.append(p)


## Moon Sanctuary: the phase of the moon changes now and then and gives both teams its bonus. The altars show the phase.
func _make_moon() -> void:
	if moon.is_empty():
		return
	for pos in moon_altars:
		var l := Label3D.new()
		l.font_size = 48
		l.pixel_size = 0.012
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.modulate = Color(0.85, 0.9, 1.0)
		l.outline_size = 12
		add_child(l)
		l.global_position = pos + Vector3(0, 4.0, 0)
		_moon_labels.append(l)
	_moon_t = 0.0


func _tick_moon(delta: float) -> void:
	if moon.is_empty():
		return
	_moon_t -= delta
	if _moon_t > 0.0:
		return
	var phases: Array = moon.get("phases", [])
	if phases.is_empty():
		return
	_moon_t = float(moon.get("phase_seconds", 60.0))
	moon_index = (moon_index + 1) % phases.size()
	var mods: Dictionary = MOON_MODS[moon_index % MOON_MODS.size()]
	for c in combatants:
		c.stats.set_source("moon", mods)
	var text := String(phases[moon_index])
	for l in _moon_labels:
		(l as Label3D).text = text.replace(": ", "\n")
	hud_toast(text, Color(0.8, 0.88, 1.0))


## Is this fighter standing in the light of a lantern (Shadow Crypt)? Then everyone can see it.
func is_lit(c: Combatant) -> bool:
	for l in lanterns:
		if c.global_position.distance_to(l["pos"]) <= float(l["r"]):
			return true
	return false


func current_moon_text() -> String:
	var phases: Array = moon.get("phases", [])
	return String(phases[moon_index]) if moon_index >= 0 and moon_index < phases.size() else ""


## A map with fewer than two mission NPCs (Crystal Caves had none) gets two glowing beacons with a mission giver on each half, between the spawns and the middle.
func _add_extra_npcs() -> void:
	var have := 0
	for n in npcs:
		if n.npc_type == "mission":
			have += 1
	if have >= 2:
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var count := 0
	for t in ["red", "blue"]:
		var list: Array = spawns[t]
		if list.is_empty():
			continue
		var base := Vector3.ZERO
		for s in list:
			base += s
		base = base / float(list.size())
		for k in 2:
			var want := base.lerp(Vector3(0, base.y, 0), 0.4 + 0.12 * k) + Vector3(18.0 * (1.0 if k == 0 else -1.0), 0, 6.0 * (k - 0.5))
			for attempt in 8:
				var p := want + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)) * (float(attempt) / 4.0)
				var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 200.0, p.z), Vector3(p.x, -80.0, p.z), 1)
				var r := space.intersect_ray(q)
				if r.is_empty() or not (r["collider"] as Node).has_meta("ground") or (r["normal"] as Vector3).y < 0.9:
					continue
				var npc := NpcNode.new()
				add_child(npc)
				npc.setup({"name": "npc_mission_extra_%d" % count, "pos": r["position"], "npc_type": "mission"}, self)
				npcs.append(npc)
				interactables.append(npc)
				_beacon(r["position"])
				count += 1
				break


## A small glowing crystal cluster that marks a mission giver without a model of its own.
func _beacon(pos: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = DecorMesh.make("crystals", 2)
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * 3.2), pos))
	mm.set_instance_color(0, Color.WHITE)
	var c := Color(1.0, 0.82, 0.35).srgb_to_linear()
	mm.set_instance_custom_data(0, Color(c.r, c.g, c.b, 0.3))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Decor._material(1.3)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Capture the flag: each team's flag stands in the middle of its spawns (the base).
func _make_flags() -> void:
	for cp in capture_points:
		cp.visible = false
	for t in ["red", "blue"]:
		var list: Array = spawns[t]
		var at := Vector3.ZERO
		for s in list:
			at += s
		at = at / maxf(1.0, float(list.size()))
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 200.0, at.z), Vector3(at.x, -80.0, at.z), 1)
		var r := space.intersect_ray(q)
		if not r.is_empty():
			at = r["position"]
		var f := FlagNode.new()
		f.name = "Flag_" + t
		add_child(f)
		f.setup(self, t, at)
		flags[t] = f


## A flag carrier reached their own base with the enemy flag while their own flag was home.
func flag_captured(flag: FlagNode, carrier: Combatant) -> void:
	carrier.captures += 1
	var cap_team := carrier.team
	flag.return_home(null)
	hud_toast("%s captured the %s flag!" % [carrier.display_name, flag.team.to_upper()], FlagNode.TEAM_COLOR[cap_team])
	Sfx.play("coin")
	Fx.ring(flags[cap_team].home, 7.0, FlagNode.TEAM_COLOR[cap_team], 0.9)
	if carrier == player:
		quests.on_event("capture", {})
	_add_score(cap_team, 1)


## An air drop every minute or so, once the fighting has started.
func _tick_airdrops(delta: float) -> void:
	_airdrop_timer -= delta
	if _airdrop_timer > 0.0:
		return
	_airdrop_timer = randf_range(70.0, 100.0)
	if airdrops.size() >= 2:
		return
	var space := get_world_3d().direct_space_state
	for attempt in 14:
		var p := Vector2(randf_range(-0.42, 0.42) * map_size.x, randf_range(-0.42, 0.42) * map_size.y)
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 200.0, p.y), Vector3(p.x, -80.0, p.y), 1)
		var r := space.intersect_ray(q)
		if r.is_empty() or not (r["collider"] as Node).has_meta("ground") or (r["normal"] as Vector3).y < 0.9:
			continue
		if not spot_is_clear(r["position"], 2.2):                    # not against a cliff, wall or rock
			continue
		var drop := AirDropNode.new()
		drop.name = "AirDrop"
		add_child(drop)
		drop.setup(self, r["position"])
		airdrops.append(drop)
		hud_toast("An AIR DROP is coming down! Follow the golden light.", Color(1.0, 0.85, 0.4))
		Sfx.play("whoosh")
		return


## Where a bot should head: in capture the flag, to take the enemy flag, guard its own, chase a carrier or bring a flag home; otherwise the capture points
## (and sometimes an air drop that has landed).
func bot_goal(b: Bot) -> Vector3:
	if mode == "ctf" and flags.size() == 2:
		var own: FlagNode = flags[b.team]
		var enemy: FlagNode = flags["blue" if b.team == "red" else "red"]
		if b.carrying_flag != null:
			return own.home
		if own.state != "home":                                    # our flag is out: everyone chases it (the carrier, or the dropped flag)
			return own.global_position
		var role: String = String(b.get_meta("ctf_role", "attack"))
		if role == "defend":
			return own.home + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
		if enemy.state == "carried" and enemy.carrier != null and enemy.carrier.team == b.team:
			return own.home + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))        # a teammate has it: wait at home to cover
		return enemy.global_position
	for d in airdrops:
		if d.landed and not d.open_done and randf() < 0.3:
			return d.global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
	if capture_points.is_empty():
		return Vector3(randf_range(-40, 40), b.global_position.y, randf_range(-40, 40))
	var pool: Array = []
	for cp in capture_points:
		if cp.owner_team != b.team:
			pool.append(cp)
	if pool.is_empty():
		pool = capture_points
	var pick: CapturePoint = pool[randi() % pool.size()]
	return pick.global_position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))


## Water in a map file sometimes hangs above the ground (the oasis of the Desert Tomb is a flat disc 45 cm over flat sand). When the ground just outside its edge is lower than its
## surface, nothing holds the water up: it is lowered to rest just above the ground under it. A real pool (a bank around it) is left alone.
func _settle_water() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var root := get_node_or_null("Map")
	if root == null:
		return
	var space := get_world_3d().direct_space_state
	for c in root.find_children("*", "MeshInstance3D", false, false):
		var mi := c as MeshInstance3D
		var base := MapLoader._base_name(String(mi.name))
		if mi.mesh == null or not base.contains("water") or base.contains("waterfall"):
			continue
		var bb := mi.global_transform * mi.get_aabb()
		if bb.size.y > 0.5 or bb.size.x < 2.0:
			continue
		var inside_max := -1e9
		for i in 5:
			for j in 5:
				var x := bb.position.x + bb.size.x * (float(i) + 0.5) / 5.0
				var z := bb.position.z + bb.size.z * (float(j) + 0.5) / 5.0
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, bb.end.y + 40.0, z), Vector3(x, bb.position.y - 40.0, z), 1))
				if not hit.is_empty():
					inside_max = maxf(inside_max, hit["position"].y)
		var rim_max := -1e9
		for k in 16:
			var ang := TAU * float(k) / 16.0
			var rx := bb.get_center().x + cos(ang) * (bb.size.x * 0.5 + 1.2)
			var rz := bb.get_center().z + sin(ang) * (bb.size.z * 0.5 + 1.2)
			var rh := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(rx, bb.end.y + 40.0, rz), Vector3(rx, bb.position.y - 40.0, rz), 1))
			if not rh.is_empty():
				rim_max = maxf(rim_max, rh["position"].y)
		if inside_max < -1e8 or rim_max < -1e8:
			continue
		if bb.position.y > rim_max + 0.15 and bb.position.y > inside_max + 0.15:
			mi.global_position.y += (inside_max + 0.05) - bb.position.y


## Is there room for a crate (about 1.6 m radius) at this point of the ground, with no wall, rock or building touching it?
func spot_is_clear(p: Vector3, radius: float = 1.7) -> bool:
	var space := get_world_3d().direct_space_state
	for h in [0.4, 1.1]:
		for k in 8:
			var a := TAU * float(k) / 8.0
			var from := p + Vector3(0, h, 0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(cos(a), 0, sin(a)) * radius, 1))
			if not hit.is_empty():
				return false
	# not inside something solid: a ray straight up from the ground must not hit anything within 2 m
	var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.1, 0), p + Vector3(0, 2.2, 0), 1))
	return up.is_empty()


## The nearest clear piece of ground to `p` (a spiral of rays from above), or `p` itself when it is already clear or nothing better is found within 10 m.
func find_clear_ground(p: Vector3, radius: float = 1.7) -> Vector3:
	var space := get_world_3d().direct_space_state
	for ring in range(0, 11):
		var n := 1 if ring == 0 else ring * 6
		for k in n:
			var a := TAU * float(k) / float(n)
			var xz := Vector3(p.x + cos(a) * float(ring), 0, p.z + sin(a) * float(ring))
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(xz.x, p.y + 6.0, xz.z), Vector3(xz.x, p.y - 8.0, xz.z), 1))
			if hit.is_empty() or float((hit["normal"] as Vector3).y) < 0.85:
				continue
			var q: Vector3 = hit["position"]
			if spot_is_clear(q, radius):
				return q
	return p


## Loot crates from the map's markers are moved out of walls and rocks.
func _settle_crates() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for cr in crates:
		if not is_instance_valid(cr):
			continue
		if not spot_is_clear(cr.global_position, 1.4):
			var q := find_clear_ground(cr.global_position, 1.4)
			if q != cr.global_position:
				cr.global_position = q
