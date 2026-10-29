extends Node
## LAN multiplayer. One machine HOSTS: it runs the real match (bots, capture points, pickups, damage, deaths) and every other player is a RemotePlayer there. The other machines JOIN:
## each one runs its own copy of the map and moves its own character (so the controls feel instant), sends where it stands and which buttons are held, and gets the rest of the world back:
##   host -> clients, about 20 times a second: position, facing, animation and health of every fighter, the score and clock, the capture points and pickups;
##   host -> clients, when it happens: spawns, attacks and skills (played again on the client as pictures, with all damage switched off), damage numbers, deaths, respawns, toasts, the end.
## Nothing here runs unless a game was hosted or joined (active == false), so the single-player game is untouched.

signal peers_changed()
signal start_requested()
signal lost(reason: String)

const PORT := 24565
const SNAP_DT := 0.05
const SELF_DT := 0.1
const INPUT_DT := 0.033

var active := false
var is_host := false
var is_client := false
var peers := {}                      # host: peer id -> {name, class, skills, items, cards, level, team, ready, proxy}
var my_team := "red"
var my_net_id := -1
var match_info := {}                 # {map, mode, seed, bots, team}
var ids := {}                        # net id -> Combatant (a RemotePlayer / Bot / Player on the host, a NetPuppet or the local Player on a client)
var status := ""

var _m: Match
var _next_id := 1
var _acc_snap := 0.0
var _acc_self := 0.0
var _acc_in := 0.0
var _spawn_queue: Array = []
var _dbg_t := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)


# ================================================================= starting and stopping

func host_game(port: int = PORT) -> int:
	stop()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, 8)
	if err != OK:
		status = "Could not host: port %d is busy" % port
		return err
	multiplayer.multiplayer_peer = p
	active = true
	is_host = true
	status = "Hosting on port %d" % port
	peers_changed.emit()
	return OK


func join_game(address: String, port: int = PORT) -> int:
	stop()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(address, port)
	if err != OK:
		status = "Could not connect to %s" % address
		return err
	multiplayer.multiplayer_peer = p
	active = true
	is_client = true
	status = "Connecting to %s ..." % address
	peers_changed.emit()
	return OK


func stop() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	active = false
	is_host = false
	is_client = false
	peers.clear()
	ids.clear()
	_m = null
	my_net_id = -1
	my_team = "red"
	match_info = {}


## The addresses other machines on the network can use to reach this one.
func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


func human_count() -> int:
	return 1 + peers.size() if is_host else 0


# ================================================================= connection events

## Building a map freezes a machine for a while (a slow PC: half a minute); the connection must not be dropped meanwhile.
func _patient(id: int) -> void:
	var p := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if p != null and p.get_peer(id) != null:
		p.get_peer(id).set_timeout(32, 120000, 180000)


func _on_peer_connected(id: int) -> void:
	_patient(id)
	if is_host:
		status = "A player is connecting ..."
		peers_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	var info: Dictionary = peers.get(id, {})
	var proxy = info.get("proxy")
	if proxy != null and is_instance_valid(proxy):
		if _m != null:
			_m.combatants.erase(proxy)
		proxy.queue_free()
	peers.erase(id)
	status = "%s left" % String(info.get("name", "A player"))
	peers_changed.emit()


func _on_connected() -> void:
	_patient(1)
	status = "Connected. Waiting for the host to start the match ..."
	srv_hello.rpc_id(1, _hello_info())
	peers_changed.emit()


func _on_connect_failed() -> void:
	stop()
	status = "Could not connect"
	lost.emit("Could not connect to the host.")


func _on_server_lost() -> void:
	stop()
	status = "The host closed the game"
	lost.emit("The host closed the game.")


func _hello_info() -> Dictionary:
	var cls := Game.selected_class
	var items := {}
	for slot in ["weapon", "helmet", "chestplate", "shield", "leggings", "boots"]:
		items[slot] = Game.equipped_item(slot)
	var nm := OS.get_environment("USERNAME")
	return {"name": nm if nm != "" else "Guest", "class": cls, "skills": Game.skills_for(cls), "items": items, "cards": Game.card_mods(), "level": Game.class_level_mods(cls)}


# ================================================================= the start of a match

@rpc("any_peer", "call_remote", "reliable")
func srv_hello(info: Dictionary) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	info["ready"] = false
	info["team"] = _pick_team()
	peers[id] = info
	status = "%s joined" % String(info.get("name", "A player"))
	peers_changed.emit()
	if _m != null and is_instance_valid(_m) and not _m.finished:
		_send_start(id)                                  # joined while a match runs: start for them at once


func _pick_team() -> String:
	var red := 1                                          # the host is red
	var blue := 0
	for id in peers:
		if String(peers[id].get("team", "")) == "blue":
			blue += 1
		elif peers[id].has("team"):
			red += 1
	return "blue" if blue <= red else "red"


## Host: call right before the match is built.
func host_begin_match() -> void:
	if not is_host:
		return
	if Game.game_mode == "ctf":
		Game.game_mode = "domination"                    # the flags are not shared over the network yet
	match_info = {"map": Game.map_id, "mode": Game.game_mode, "seed": randi(), "bots": Game.bots_per_team}
	_m = null
	for id in peers:
		peers[id]["ready"] = false
		peers[id]["proxy"] = null
		_send_start(id)


func _send_start(id: int) -> void:
	var info: Dictionary = match_info.duplicate()
	info["team"] = peers[id]["team"]
	cl_start.rpc_id(id, info)


@rpc("authority", "call_remote", "reliable")
func cl_start(info: Dictionary) -> void:
	match_info = info
	my_team = String(info["team"])
	Game.map_id = String(info["map"])
	Game.game_mode = String(info["mode"])
	Game.bots_per_team = int(info["bots"])
	start_requested.emit()


## Both sides: the match is built (Match.start calls this last).
func attach(m: Match) -> void:
	_m = m
	ids.clear()
	_next_id = 1
	_spawn_queue.clear()
	_acc_snap = 0.0
	if is_host:
		_register(m.player)
	elif is_client:
		srv_ready.rpc_id(1)


func detach() -> void:
	_m = null
	ids.clear()


@rpc("any_peer", "call_remote", "reliable")
func srv_ready() -> void:
	if not is_host or _m == null:
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id):
		return
	var info: Dictionary = peers[id]
	var proxy = info.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		proxy = _m._add_remote(id, info)
		info["proxy"] = proxy
	_register(proxy)
	info["ready"] = true
	cl_assign.rpc_id(id, int(proxy.get_meta("net_id")))
	for nid in ids:
		if is_instance_valid(ids[nid]):
			cl_spawn.rpc_id(id, _spawn_info(ids[nid]))
	status = "%d players in the match" % human_count()
	peers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func cl_assign(nid: int) -> void:
	my_net_id = nid
	if _m != null and is_instance_valid(_m.player):
		ids[nid] = _m.player
		_m.player.set_meta("net_id", nid)


# ================================================================= host: who exists, what happens

func _ready_peers() -> Array:
	var out: Array = []
	for id in peers:
		if bool(peers[id].get("ready", false)):
			out.append(id)
	return out


func _spawn_info(c: Combatant) -> Dictionary:
	var minion := c is Bot and (c as Bot).minion_of != null
	return {"id": int(c.get_meta("net_id")), "class": c.class_id, "team": c.team, "name": c.display_name if c != _m.player else "Host", "weapon": String(c.weapon.get("id", "")),
		"skills": c.skill_ids, "pos": c.global_position, "minion": minion}


func _register(c: Combatant) -> void:
	if c.has_meta("net_id"):
		return
	var nid := _next_id
	_next_id += 1
	c.set_meta("net_id", nid)
	ids[nid] = c
	c.died.connect(func(killer: Node) -> void: _ev_died(c, killer))
	c.respawned.connect(func() -> void: _ev_respawned(c))
	c.damaged.connect(func(amount: float, src: Node, info: Dictionary) -> void: _ev_damage(c, amount, src, info))
	c.attacked.connect(func() -> void: _ev_attack(c, "w"))
	c.skill_used.connect(func(slot: String, _sk: Dictionary) -> void: _ev_attack(c, slot))
	for p in _ready_peers():
		cl_spawn.rpc_id(p, _spawn_info(c))


func _ev_attack(c: Combatant, slot: String) -> void:
	if not is_instance_valid(c) or slot == "quest":
		return
	for p in _ready_peers():
		cl_attack.rpc_id(p, int(c.get_meta("net_id")), slot, c.aim_dir, c.aim_point)


func _ev_damage(c: Combatant, amount: float, src: Node, info: Dictionary) -> void:
	var col: Array = info.get("color", [])
	var dot := String(info.get("dot", "")) != ""
	var sid := int(src.get_meta("net_id", -1)) if src != null and is_instance_valid(src) else -1
	for p in _ready_peers():
		cl_damage.rpc_id(p, int(c.get_meta("net_id")), amount, bool(info.get("crit", false)), col, dot, sid)


func _ev_died(c: Combatant, killer: Node) -> void:
	var kid := int(killer.get_meta("net_id", -1)) if killer != null and is_instance_valid(killer) else -1
	for p in _ready_peers():
		cl_died.rpc_id(p, int(c.get_meta("net_id")), kid, Match.RESPAWN_TIME)


func _ev_respawned(c: Combatant) -> void:
	for p in _ready_peers():
		cl_respawned.rpc_id(p, int(c.get_meta("net_id")), c.global_position)


func toast_all(text: String, color: Color) -> void:
	if not is_host:
		return
	for p in _ready_peers():
		cl_toast.rpc_id(p, text, color)


func host_ended(winner: String) -> void:
	if not is_host:
		return
	for p in _ready_peers():
		cl_end.rpc_id(p, winner)


func _physics_process(delta: float) -> void:
	if _m == null or not is_instance_valid(_m):
		return
	if OS.get_environment("NET_DEBUG") != "":
		_dbg_t += delta
		if _dbg_t >= 3.0:
			_dbg_t = 0.0
			var line := "NETDBG %s ids %d combatants %d" % ["host" if is_host else "client", ids.size(), _m.combatants.size()]
			if is_host:
				for id in peers:
					var pr = peers[id].get("proxy")
					line += " | peer %d ready %s proxy %s" % [id, str(peers[id].get("ready")), (str(pr.global_position.snapped(Vector3(0.1, 0.1, 0.1))) + " hp " + str(int(pr.health))) if pr != null and is_instance_valid(pr) else "none"]
			else:
				line += " | my id %d me %s hp %d time %d score %s" % [my_net_id, str(_m.player.global_position.snapped(Vector3(0.1, 0.1, 0.1))), int(_m.player.health), int(_m.time_left), str(_m.score)]
				var n := 0
				for c in _m.combatants:
					if c is NetPuppet:
						n += 1
				line += " puppets %d" % n
			print(line)
	if is_host:
		_host_tick(delta)


func _host_tick(delta: float) -> void:
	_acc_snap += delta
	if _acc_snap < SNAP_DT:
		return
	_acc_snap = 0.0
	for c in _m.combatants:
		if is_instance_valid(c) and not c.has_meta("net_id"):
			_register(c)
	var rp := _ready_peers()
	for nid in ids.keys():
		var c = ids[nid]
		if not is_instance_valid(c) or not _m.combatants.has(c):
			ids.erase(nid)
			for p in rp:
				cl_despawn.rpc_id(p, nid)
	if rp.is_empty():
		return
	var entries: Array = []
	for nid in ids:
		var c: Combatant = ids[nid]
		entries.append([nid, c.global_position, c.model.rotation.y, c.model._state, c.dead, c.health, c.max_health()])
	var cps: Array = []
	for cp in _m.capture_points:
		cps.append([cp.progress, cp.owner_team])
	var ups: Array = []
	for pu in _m.pickups:
		ups.append(pu.is_up())
	for p in rp:
		cl_snap.rpc_id(p, entries, _m.time_left, int(_m.score["red"]), int(_m.score["blue"]), cps, ups)
	_acc_self += SNAP_DT
	if _acc_self >= SELF_DT:
		_acc_self = 0.0
		for p in rp:
			var proxy = peers[p].get("proxy")
			if proxy != null and is_instance_valid(proxy):
				cl_self.rpc_id(p, _self_state(proxy))


func _self_state(c: Combatant) -> Dictionary:
	var sts: Array = []
	for id in c.statuses.active:
		var e: Dictionary = c.statuses.active[id]
		sts.append([id, int(e["stacks"]), float(e["time"]), float(e["total"])])
	return {"hp": c.health, "mp": c.mana, "cd": c.cooldowns, "ult": c.ult_charge, "meter": c.meter, "ammo": c.ammo, "reload": c.reload_left, "sts": sts, "kills": c.kills, "deaths": c.deaths,
		"streak": c.streak, "shield": c.statuses.absorb_left}


# ================================================================= client: what the host sends

@rpc("authority", "call_remote", "reliable")
func cl_spawn(info: Dictionary) -> void:
	if _m == null or not is_instance_valid(_m):
		return
	var nid := int(info["id"])
	if ids.has(nid) and is_instance_valid(ids[nid]):
		return
	if nid == my_net_id:
		ids[nid] = _m.player
		_m.player.set_meta("net_id", nid)
		return
	var pup := NetPuppet.new()
	pup.name = "Puppet%d" % nid
	_m.add_child(pup)
	pup.match_ref = _m
	pup.setup_puppet(info)
	pup.global_position = info["pos"]
	pup.set_meta("net_id", nid)
	_m.combatants.append(pup)
	ids[nid] = pup


@rpc("authority", "call_remote", "reliable")
func cl_despawn(nid: int) -> void:
	var c = ids.get(nid)
	ids.erase(nid)
	if c != null and is_instance_valid(c) and c != _m.player:
		_m.combatants.erase(c)
		c.queue_free()


@rpc("authority", "call_remote", "unreliable")
func cl_snap(entries: Array, time_left: float, red: int, blue: int, cps: Array, ups: Array) -> void:
	if _m == null or not is_instance_valid(_m):
		return
	for e in entries:
		var c = ids.get(int(e[0]))
		if c is NetPuppet and is_instance_valid(c):
			(c as NetPuppet).net_apply(e)
	_m.client_world(time_left, red, blue, cps, ups)


@rpc("authority", "call_remote", "unreliable")
func cl_self(st: Dictionary) -> void:
	if _m == null or not is_instance_valid(_m) or _m.player == null:
		return
	var p: Player = _m.player
	if p.dead:
		return
	var hp := float(st["hp"])
	if absf(hp - p.health) > 0.01:
		p.health = hp
		p.health_changed.emit(p.health, p.max_health())
	var mp := float(st["mp"])
	if absf(mp - p.mana) > 0.01:
		p.mana = mp
		p.mana_changed.emit(p.mana, p.max_mana())
	for k in st["cd"]:
		p.cooldowns[k] = float(st["cd"][k])
	p.ult_charge = float(st["ult"])
	p.meter = float(st["meter"])
	p.ammo = float(st["ammo"])
	p.reload_left = float(st["reload"])
	p.kills = int(st["kills"])
	p.deaths = int(st["deaths"])
	p.streak = int(st["streak"])
	var have := {}
	for s in st["sts"]:
		have[String(s[0])] = true
		if not p.statuses.has(String(s[0])):
			p.statuses.apply(String(s[0]), maxf(float(s[2]), 0.1), int(s[1]), null)
	for id in p.statuses.active.keys():
		if not have.has(id):
			p.statuses.remove(id)
	p.statuses.absorb_left = float(st["shield"])


@rpc("authority", "call_remote", "reliable")
func cl_attack(nid: int, slot: String, aim_dir: Vector3, aim_point: Vector3) -> void:
	var c = ids.get(nid)
	if c == null or not is_instance_valid(c) or c.dead:
		return
	replay(c, slot, aim_dir, aim_point)


## An attack or skill of the host's world, played again here for the picture. Everything it would cost or need is topped up first, and damage does nothing on this machine.
func replay(c: Combatant, slot: String, aim_dir: Vector3, aim_point: Vector3) -> void:
	c.aim_dir = aim_dir
	c.aim_point = aim_point
	c.attack_cd = 0.0
	c.casting_lock = 0.0
	c.reload_left = 0.0
	c.mana = c.max_mana()
	if c.weapon.has("ammo"):
		c.ammo = float(c.weapon["ammo"]) + 1.0
	if slot == "w":
		WeaponRunner.attack(c)
	else:
		c.cooldowns[slot] = 0.0
		if slot == "ult":
			c.ult_charge = 100.0
		SkillRunner.use(c, slot)


@rpc("authority", "call_remote", "reliable")
func cl_damage(nid: int, amount: float, crit: bool, col: Array, dot: bool, src_id: int) -> void:
	var c = ids.get(nid)
	if c == null or not is_instance_valid(c) or _m == null:
		return
	var pl: Combatant = _m.player
	if c == pl or c.global_position.distance_to(pl.global_position) < 30.0:
		var color := Color(col[0], col[1], col[2]) if col.size() >= 3 else (Color(1, 0.4, 0.35) if c == pl else Color(1, 1, 1))
		Fx.damage_number(c.global_position + Vector3(0, 2.1, 0), amount, color, crit)
	if not dot and c.model != null and not c.dead:
		c.model.flash(Color(1, 0.3, 0.3))
		if amount > c.max_health() * 0.08:
			c.model.play_once("HitChest", 1.2, true)
	if c == pl:
		pl.damaged.emit(amount, null, {"dot": "net" if dot else ""})
	if src_id >= 0 and src_id == my_net_id and c != pl:
		pl.dealt.emit(c, amount, {"crit": crit})                 # the crosshair's hit marker and the quests count it


@rpc("authority", "call_remote", "reliable")
func cl_died(nid: int, killer_id: int, respawn_in: float) -> void:
	var c = ids.get(nid)
	if c == null or not is_instance_valid(c):
		return
	var k = ids.get(killer_id)
	if k != null and not is_instance_valid(k):
		k = null
	c.die(k)
	_m.client_died(c, k, respawn_in)


@rpc("authority", "call_remote", "reliable")
func cl_respawned(nid: int, pos: Vector3) -> void:
	var c = ids.get(nid)
	if c == null or not is_instance_valid(c):
		return
	c.respawn(pos)
	_m.client_respawned(c)


@rpc("authority", "call_remote", "reliable")
func cl_toast(text: String, color: Color) -> void:
	if _m != null and is_instance_valid(_m):
		_m.hud_toast(text, color)


@rpc("authority", "call_remote", "reliable")
func cl_end(winner: String) -> void:
	if _m != null and is_instance_valid(_m):
		_m.client_end(winner)


# ================================================================= client: what this machine sends

## Called by the local Player every physics frame on a joined machine.
func client_update(p: Player, delta: float) -> void:
	_acc_in += delta
	if _acc_in < INPUT_DT:
		return
	_acc_in = 0.0
	var attack := not p.ui_blocked and Input.is_action_pressed("attack")
	srv_input.rpc_id(1, [p.global_position, p.model.rotation.y, p.model._state, p.velocity, p.aim_dir, p.aim_point, attack, p.dead])


@rpc("any_peer", "call_remote", "unreliable_ordered")
func srv_input(a: Array) -> void:
	if not is_host:
		return
	var proxy = peers.get(multiplayer.get_remote_sender_id(), {}).get("proxy")
	if proxy != null and is_instance_valid(proxy):
		(proxy as RemotePlayer).net_in(a)


func client_skill(slot: String, aim_dir: Vector3, aim_point: Vector3) -> void:
	srv_skill.rpc_id(1, slot, aim_dir, aim_point)


@rpc("any_peer", "call_remote", "reliable")
func srv_skill(slot: String, aim_dir: Vector3, aim_point: Vector3) -> void:
	if not is_host:
		return
	var proxy = peers.get(multiplayer.get_remote_sender_id(), {}).get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return
	var r := proxy as RemotePlayer
	r.aim_dir = aim_dir
	r.aim_point = aim_point
	SkillRunner.use(r, slot)


func client_drink(id: String) -> void:
	srv_drink.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func srv_drink(id: String) -> void:
	if not is_host or not Data.potions.has(id):
		return
	var proxy = peers.get(multiplayer.get_remote_sender_id(), {}).get("proxy")
	if proxy != null and is_instance_valid(proxy):
		(proxy as RemotePlayer).apply_potion(id)


func client_fall(amount: float) -> void:
	srv_fall.rpc_id(1, amount)


@rpc("any_peer", "call_remote", "reliable")
func srv_fall(amount: float) -> void:
	if not is_host:
		return
	var proxy = peers.get(multiplayer.get_remote_sender_id(), {}).get("proxy")
	if proxy != null and is_instance_valid(proxy):
		(proxy as RemotePlayer).take_damage(minf(amount, 9999.0), null, {"dot": "fall", "no_status": true, "color": [1.0, 0.72, 0.35]})
