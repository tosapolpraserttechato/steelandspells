class_name Combatant
extends CharacterBody3D
## Anything that fights: the player and the bots. Health, mana, stats, statuses, skills, weapon, movement physics, damage rules.
## Damage pipeline: attacker.deal(victim, base, info) -> multipliers -> victim.take_damage(amount, source, info) -> armor, statuses, barrier, health.

signal health_changed(cur: float, maximum: float)
signal mana_changed(cur: float, maximum: float)
signal damaged(amount: float, source: Node, info: Dictionary)
signal died(killer: Node)
signal respawned()
signal skill_used(slot: String, skill: Dictionary)
signal killed_enemy(victim: Node)
signal dealt(victim: Node, amount: float, info: Dictionary)
signal missed()
signal meter_full()
signal attacked()                                 # a basic attack went off (the network sends it to the other machines as a picture of it)

const GRAVITY := 24.0
const LADDER_SPEED := 4.6
const FALL_SAFE := 6.0                            # a drop of up to this many metres is free
const FALL_DAMAGE := 0.045                        # fraction of max health per metre beyond that
static var FALL_DEBUG := OS.get_environment("FALL_DEBUG") != ""
const TEAM_COLORS := {"red": Color(1.0, 0.3, 0.25), "blue": Color(0.3, 0.55, 1.0)}

var team := "red"
var class_id := "druid"
var display_name := "Bot"
var is_player := false
var is_remote := false                            # host side of a LAN game: a fighter that another machine steers (RemotePlayer)
var remote_data: Dictionary = {}                  # that player's items, cards and class level, sent when they joined
var dead := false
var stats := Stats.new()
var statuses: StatusSet
var model: CharacterModel
var match_ref: Match = null                       # the running Match (set by Match.gd)

var health := 100.0
var mana := 100.0
var shield_extra := 0.0
var kills := 0
var deaths := 0
var captures := 0                                 # flags captured (capture the flag)
var best_streak := 0
var carrying_flag: Node = null                    # the FlagNode this fighter carries (capture the flag)
var snipe_charge := 0.0                           # seconds spent aiming with a ranged weapon: at 0.9 the next shot is a sniper shot
var score_points := 0
var streak := 0                                   # kill streak: +10% damage per kill, expires 25 s after the last kill
var streak_timer := 0.0
var invulnerable_until := 0.0
var unseen_time := 0.0                            # hidden recovery
var last_seen_time := -99.0
var still_time := 0.0

# ----- skills
var skill_ids: Array = []                         # three chosen skills
var cooldowns: Dictionary = {}                    # slot -> seconds left ("s1", "s2", "s3", "sig", "ult", "quest")
var ult_charge := 0.0                             # 0..100
var meter := 0.0                                  # class meter 0..100
var free_casts := 0
var casting_lock := 0.0                           # seconds until the next skill or attack is allowed
var last_skill_slot := ""
var aim_dir := Vector3(0, 0, -1)                  # where the crosshair (or the bot's target) points, world space, unit length
var aim_point := Vector3.ZERO                     # the point the aim ray hits (ground, wall or enemy)

# ----- weapon
var weapon_item: Dictionary = {}
var weapon: Dictionary = {}                       # weapon data from Data.weapons
var ammo := 0.0
var attack_cd := 0.0
var reload_left := 0.0
var combo := 0

# ----- movement
var wish_dir := Vector3.ZERO
var impulse := Vector3.ZERO                       # knockback velocity that decays
var forced_vel := Vector3.ZERO                    # jump pads: horizontal velocity that replaces steering for a moment
var forced_time := 0.0
var move_lock := 0.0
var facing := Vector3(0, 0, -1)
var on_floor_prev := true
var air_time := 0.0
var slide_time := 0.0
var sprinting := false                            # running fast right now (Shift held and moving, or a sprint skill)
var stamina := 100.0                              # sprinting drains it, it comes back when you stop; 0 means a short rest
var _exhausted := false
var _stamina_rest := 0.0
var sprint_boost := 1.0                           # extra speed factor while a sprint skill is running
var sprint_boost_left := 0.0
var _sprint_dust: GPUParticles3D
var jumps_left := 1
var on_ladder := false                            # inside a LadderNode's volume this tick (the ladder sets it every physics frame)
var ladder_in := Vector3.ZERO                     # horizontal direction into the wall the ladder hangs on
var ladder_snap := Vector3.ZERO                   # the point on the ladder's axis at our height; we are pulled onto it while climbing
var ladder_top := 0.0                             # world height of the top rung
var climbing := false
var _ladder_block := 0.0                          # after letting go no ladder grabs us for a moment
var _fall_peak := -1000.0                         # highest point of the current fall, for fall damage
var _fall_prev_y := -1000.0
var crouching := false
var temp_mods: Dictionary = {}                    # key -> {until, mods}
var _regen_acc := 0.0
var _status_fx: Dictionary = {}
var _aura_node: Node3D
var _last_pos := Vector3.ZERO
var _revive_used := false
var _map_mod_key := "map"
var _combo_hits := 0
var _first_hit_targets: Dictionary = {}
var _last_cast_time := -99.0
var _own_class_boost := 1.5


func is_magic() -> bool:
	return Data.classes[class_id]["magic"]


func setup(cls: String, team_name: String, name_text: String, local_player: bool = false) -> void:
	class_id = cls
	team = team_name
	display_name = name_text
	is_player = local_player
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	var cd: Dictionary = Data.classes[cls]
	stats.set_base("max_health", float(cd["health"]))
	stats.set_base("max_mana", float(cd["mana"]))
	stats.set_base("move_speed", float(cd["stats"]["speed"]))
	stats.set_base("accel", float(cd["stats"]["accel"]))
	stats.set_base("crit_chance", float(cd["stats"]["crit"]))
	stats.set_base("sight", float(cd["stats"]["sight"]))
	stats.set_base("size", float(cd["stats"]["size"]))
	stats.set_base("mana_regen", 4.0)
	stats.set_base("health_regen", 0.0)
	stats.set_base("jump_height", 1.0)
	statuses = StatusSet.new()
	statuses.name = "Statuses"
	add_child(statuses)
	statuses.setup(self)
	statuses.resists = cd.get("resist", {}).duplicate()
	statuses.status_added.connect(_on_status_added)
	statuses.status_removed.connect(_on_status_removed)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	model = CharacterModel.new()
	model.name = "Model"
	add_child(model)
	model.setup(cls, float(cd["stats"]["size"]), team_name, name_text, local_player)
	if not local_player:
		_dress_bot()
	for s in ["s1", "s2", "s3", "sig", "ult", "quest"]:
		cooldowns[s] = 0.0
	rebuild_stats()
	health = max_health()
	mana = max_mana()
	_last_pos = global_position
	health_changed.emit(health, max_health())


func max_health() -> float:
	return stats.value("max_health", 100.0)


func max_mana() -> float:
	return stats.value("max_mana", 100.0)


# ================================================================= stats from class, cards, gear, runes

func rebuild_stats() -> void:
	var cd: Dictionary = Data.classes[class_id]
	var passive_strength := 1.0 + stats.mult_sum("passive_strength")
	stats.set_source("class_passive", cd["passive"].get("mods", {}), passive_strength)
	var twin: float = stats.add_sum("passive_twin")
	if twin > 0.0:
		stats.set_source("class_passive_twin", cd["passive"].get("mods", {}), twin)
	else:
		stats.remove_source("class_passive_twin")
	if is_player:
		stats.set_source("cards", Game.card_mods())
		stats.set_source("class_level", Game.class_level_mods(class_id))
		_rebuild_gear()
	elif is_remote:
		stats.set_source("cards", remote_data.get("cards", {}))
		stats.set_source("class_level", remote_data.get("level", {}))
		_rebuild_gear()
	var mvmt: Dictionary = {}
	for k in temp_mods:
		mvmt[k] = temp_mods[k]["mods"]
	for k in mvmt:
		stats.set_source("temp:" + String(k), mvmt[k])
	free_casts = int(stats.add_sum("free_casts"))
	health = minf(health, max_health())
	mana = minf(mana, max_mana())
	health_changed.emit(health, max_health())
	mana_changed.emit(mana, max_mana())


## Bots wear armor too (most of them): a set of their kind (magic or not), complete half the time, otherwise a few pieces.
func _dress_bot() -> void:
	if model == null or randf() > 0.7 or OS.get_environment("NO_BOT_ARMOR") != "":
		return
	var sets: Array = Data.armor_order.filter(func(id: String) -> bool: return bool(Data.armor_sets[id]["magic"]) == is_magic())
	if sets.is_empty():
		return
	var sid: String = sets[randi() % sets.size()]
	var all := randf() < 0.5
	var pieces := {}
	for slot in ["helmet", "chestplate", "shield", "leggings", "boots"]:
		if all or randf() < 0.55:
			pieces[slot] = sid
	model.dress(pieces)


## The effect of a potion (health, mana, statuses, cleanse). Used by the player's own drink and by the host for a player on another machine.
func apply_potion(id: String) -> void:
	var fx: Dictionary = Data.potions[id]["fx"]
	if fx.has("heal"):
		heal(float(fx["heal"]) * (1.0 + stats.mult_sum("heal_pickup")), self)
	if fx.has("mana"):
		restore_mana(float(fx["mana"]))
	for s in fx.get("sts", []):
		statuses.apply(String(s["id"]), float(s.get("dur", -1.0)), 1, self)
	if fx.get("cleanse", false):
		statuses.cleanse()
	model.play_once("Consume", 1.5, true)
	Fx.ring(global_position, 2.0, Data.color_of(Data.potions[id]["color"]), 0.5)


## What this fighter wears: the player's own saved gear, or (for a fighter steered from another machine) the gear that machine sent.
func _equipped(slot: String) -> Dictionary:
	if is_remote:
		return remote_data.get("items", {}).get(slot, {})
	return Game.equipped_item(slot)


func _rebuild_gear() -> void:
	stats.clear_sources_with_prefix("item:")
	stats.clear_sources_with_prefix("set:")
	weapon_item = _equipped("weapon")
	var strength := 1.0 + stats.mult_sum("armor_passive_strength")
	var sets_count: Dictionary = {}
	for slot in ["helmet", "chestplate", "shield", "leggings", "boots"]:
		var it: Dictionary = _equipped(slot)
		if it.is_empty():
			continue
		stats.set_source("item:" + slot, Loot.item_mods(it, strength))
		sets_count[it["set"]] = int(sets_count.get(it["set"], 0)) + 1
		if it.has("aura") and _aura_node == null:
			set_aura(String(it["aura"]))
	if not weapon_item.is_empty():
		stats.set_source("item:weapon", Loot.item_mods(weapon_item))
		if weapon_item.has("aura"):
			set_aura(String(weapon_item["aura"]))
	var set_strength := 1.0 + stats.mult_sum("set_strength")
	for set_id in sets_count:
		if int(sets_count[set_id]) >= 5:
			var bonus: Dictionary = Data.armor_sets[set_id]["set_bonus"]
			stats.set_source("set:" + String(set_id), bonus.get("mods", {}), set_strength)
			var extra := {}
			for key in ["on_hit", "aura", "reflect", "heal_on_kill", "low_health_barrier", "dodge"]:
				if bonus.has(key):
					extra["set_" + key] = bonus[key]
			if not extra.is_empty():
				stats.set_source("set:" + String(set_id) + ":x", extra)
			for rid in bonus.get("resist", {}):
				statuses.resists[rid] = float(bonus["resist"][rid])
			# the signature bonus: the complete set together with the weapon it was made for
			var sig := String(Data.armor_looks.get(set_id, {}).get("weapon", ""))
			if sig != "" and not weapon_item.is_empty() and String(weapon_item["id"]) == sig:
				stats.set_source("set:" + String(set_id) + ":sig", {"weapon_damage": {"mult": 0.12}, "spell_damage": {"mult": 0.12}, "max_health": {"mult": 0.08}})
	if model != null and not is_remote:
		var worn := Game.worn_armor()
		model.dress(worn[0], worn[1], worn[2])
	equip_weapon()


func equip_weapon() -> void:
	var wid := ""
	if not weapon_item.is_empty():
		wid = String(weapon_item["id"])
	else:
		wid = String(Data.classes[class_id]["weapon"])
	if not Data.weapons.has(wid):
		wid = "longsword"
	weapon = Data.weapons[wid]
	ammo = weapon.get("ammo", 0) * (1.0 + stats.mult_sum("max_ammo"))
	attack_cd = 0.0
	reload_left = 0.0
	if model != null:
		model.hold_weapon(Weapons.visual_for(weapon, String(weapon_item.get("skin", "")) if weapon_item.get("new", false) else "", not weapon_item.is_empty() and not weapon_item.get("new", false)))


func add_temp_mods(key: String, mods: Dictionary, dur: float) -> void:
	temp_mods[key] = {"until": Time.get_ticks_msec() / 1000.0 + dur, "mods": mods}
	stats.set_source("temp:" + key, mods)


func set_aura(id: String) -> void:
	if _aura_node != null:
		_aura_node.queue_free()
	_aura_node = Fx.aura(id, 1.85)
	add_child(_aura_node)


# ================================================================= status effect visuals

func _on_status_added(id: String) -> void:
	if _status_fx.has(id) or model == null:
		return
	var n: Node3D = Fx.status_effect(id, 1.85 * float(stats.value("size", 1.0)))
	add_child(n)
	_status_fx[id] = n
	if id == "invisible":
		model.set_ghost(is_player)
		if not is_player:
			model.set_model_visible(false)


func _on_status_removed(id: String) -> void:
	if _status_fx.has(id):
		var n: Node = _status_fx[id]
		if is_instance_valid(n):
			for c in n.get_children():
				if c is GPUParticles3D:
					c.emitting = false
			Util.after(self, 1.2, func() -> void:
				if is_instance_valid(n):
					n.queue_free())
		_status_fx.erase(id)
	if id == "invisible" and model != null:
		model.set_ghost(false)
		model.set_model_visible(true)


func _exit_tree() -> void:
	if match_ref != null:
		match_ref.combatants.erase(self)


func set_plate_hidden() -> void:
	if model != null:
		model.set_plate_visible(false)


func has_flag(flag: String) -> bool:
	return statuses.has_flag(flag)


func is_visible_to(other: Combatant) -> bool:
	if other == null or other.team == team:
		return true
	return not statuses.has_flag("invisible") or statuses.has("marked")


# ================================================================= movement

func current_speed() -> float:
	var base := stats.value("move_speed", 5.8)
	var m := statuses.move_mult()
	if carrying_flag != null:
		m *= 0.88                                         # a flag carrier is a little slower
	if health < max_health() * 0.3:
		m += stats.add_sum("low_health_speed")
	if is_on_floor() and slide_time <= 0.0 and crouching:
		m *= 0.55 * (1.0 + stats.mult_sum("crouch_speed"))
	if streak_speed_bonus() > 0.0:
		m += streak_speed_bonus()
	return maxf(0.0, base * m)


func streak_speed_bonus() -> float:
	return stats.add_sum("speed_after_hit") if Time.get_ticks_msec() / 1000.0 - _last_hit_time < 2.0 else 0.0


var _last_hit_time := -99.0


## Shared movement step. `wish` is the horizontal direction (world space, length <= 1).
func physics_move(delta: float, wish: Vector3, want_jump: bool, sprint: bool = false, slide: bool = false) -> void:
	if dead:
		velocity = Vector3.ZERO
		return
	# sprinting: hold Shift while moving. Faster than running, drains stamina; a sprint skill runs faster still and costs nothing.
	var boosted := sprint_boost_left > 0.0
	var want := (sprint or boosted) and wish.length() > 0.1 and not _exhausted and statuses.can_move() and slide_time <= 0.0
	if want and not boosted:
		stamina = maxf(0.0, stamina - 24.0 * delta / (1.0 + stats.mult_sum("sprint_stamina")))
		_stamina_rest = 0.7
		if stamina <= 0.0:
			_exhausted = true
	else:
		_stamina_rest -= delta
		if _stamina_rest <= 0.0 or boosted:
			stamina = minf(100.0, stamina + 18.0 * delta)
			if _exhausted and stamina > 30.0 and not sprint:
				_exhausted = false
	sprinting = want
	_set_sprint_dust(want)
	var spd := current_speed()
	if want:
		spd *= 1.5 * (1.0 + stats.mult_sum("sprint_speed")) * (sprint_boost if boosted else 1.0)
	if not statuses.can_move() or move_lock > 0.0:
		wish = Vector3.ZERO
	var accel: float = stats.value("accel", 9.0) * (1.0 if is_on_floor() else 0.35 * (1.0 + stats.mult_sum("air_control")))
	var target := wish * spd
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.move_toward(target, accel * maxf(spd, 1.0) * 0.35 * delta * 3.0)
	if slide and is_on_floor() and slide_time <= 0.0 and hv.length() > 3.0:
		slide_time = 0.75 * (1.0 + stats.mult_sum("slide_distance"))
		hv = hv.normalized() * (spd * 1.9)
		if model != null:
			model.play_once("SlideStart", 1.3, true)
	if slide_time > 0.0:
		slide_time -= delta
		hv = hv.move_toward(Vector3.ZERO, 5.0 * delta)
		if slide_time <= 0.0 and model != null:
			model.play_once("SlideExit", 1.3, false)
	_ladder_block = maxf(0.0, _ladder_block - delta)
	climbing = on_ladder and _ladder_block <= 0.0 and statuses.can_move()
	if climbing and is_on_floor():
		# from the ground you take hold by walking into the ladder (up the bottom, off the ledge at the top)
		var into := wish.dot(ladder_in)
		var high := global_position.y > ladder_top - 0.6
		climbing = (into > 0.25 and not high) or (into < -0.25 and high)
	if climbing:
		# on a ladder: no gravity; walking into the wall climbs, walking away climbs down, jump kicks off, the top hops onto the ledge
		var into := wish.dot(ladder_in)
		var climb := 0.0
		if into > 0.2:
			climb = LADDER_SPEED
		elif into < -0.2:
			climb = -LADDER_SPEED
		var pull := Vector3(ladder_snap.x - global_position.x, 0, ladder_snap.z - global_position.z) * 10.0
		hv = pull.limit_length(4.0)
		velocity.y = climb
		jumps_left = 1 + int(stats.add_sum("extra_jumps"))
		if want_jump:
			_ladder_block = 0.35
			climbing = false
			velocity.y = sqrt(2.0 * GRAVITY * 1.2)
			hv = -ladder_in * 5.5
			Fx.ring(global_position, 1.0, Color(0.8, 0.9, 1.0), 0.25)
		elif climb > 0.0 and global_position.y >= ladder_top - 0.15 and not is_on_floor():
			_ladder_block = 0.5
			climbing = false
			velocity.y = 5.5
			hv = ladder_in * 3.4
	elif is_on_floor():
		jumps_left = 1 + int(stats.add_sum("extra_jumps"))              # everyone can double jump
		velocity.y = maxf(velocity.y, -1.0)
		if want_jump and statuses.can_move():
			velocity.y = sqrt(2.0 * GRAVITY * 1.35 * stats.value("jump_height", 1.0))
			if model != null:
				model.play_state("jump", true)
	else:
		if want_jump and jumps_left > 0 and statuses.can_move():
			jumps_left -= 1
			velocity.y = sqrt(2.0 * GRAVITY * 1.2 * stats.value("jump_height", 1.0))
			Fx.ring(global_position, 1.2, Color(0.8, 0.9, 1.0), 0.3)
		velocity.y -= GRAVITY * delta
		if stats.add_sum("glide") > 0.0 and velocity.y < -3.0:
			velocity.y = -3.0
	if forced_time > 0.0:
		forced_time -= delta
		hv = Vector3(forced_vel.x, 0, forced_vel.z)
	hv += Vector3(impulse.x, 0, impulse.z)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y += impulse.y
	impulse = impulse.move_toward(Vector3.ZERO, (14.0 if is_on_floor() else 4.0) * delta * maxf(impulse.length(), 1.0))
	if impulse.length() < 0.2:
		impulse = Vector3.ZERO
	move_and_slide()
	hv = Vector3(velocity.x, 0, velocity.z)
	velocity.x -= impulse.x
	velocity.z -= impulse.z
	if hv.length() > 0.5 and wish.length() > 0.1:
		facing = wish.normalized()
	_track_fall()
	on_ladder = false                                    # a ladder sets it again next tick if we are still inside it
	_animate(hv, delta)
	on_floor_prev = is_on_floor()


## Fall damage: remembers the highest point of a fall and hurts on landing if the drop was more than FALL_SAFE metres. Ladders, teleports and respawns reset it.
func _track_fall() -> void:
	var y := global_position.y
	if absf(y - _fall_prev_y) > 5.0 or climbing or dead:
		_fall_peak = y                                   # a teleport (respawn, test script) or a ladder: not a fall
	_fall_prev_y = y
	if not is_on_floor():
		_fall_peak = maxf(_fall_peak, y)
		return
	var drop := _fall_peak - y
	_fall_peak = y
	if drop <= FALL_SAFE or on_floor_prev:
		return
	var dmg := max_health() * (drop - FALL_SAFE) * FALL_DAMAGE * maxf(0.0, 1.0 + stats.mult_sum("fall_damage"))
	if dmg <= 0.0:
		return
	Fx.ring(global_position, 1.8 + minf(drop - FALL_SAFE, 8.0) * 0.25, Color(0.85, 0.75, 0.6), 0.35)
	if Net.is_client:
		Net.client_fall(dmg)                                 # the host applies it to this player
	else:
		take_damage(dmg, null, {"dot": "fall", "no_status": true, "color": [1.0, 0.72, 0.35]})
	if model != null and not dead:
		model.play_once("JumpLand", 1.0, true)
	if FALL_DEBUG:
		print("FALL drop ", snappedf(drop, 0.1), " damage ", int(dmg), " health ", int(health))


func _animate(hv: Vector3, delta: float) -> void:
	if model == null:
		return
	if dead:
		return
	if climbing:
		air_time = 0.0
		model.climb_vy = velocity.y
		model.play_state("climb")                          # the arms reach up and take turns, the knees come up (CharacterModel._make_climb)
		return
	if not is_on_floor():
		air_time += delta
		if air_time > 0.12:
			# moving fast through the air: a leaping stride; otherwise the falling pose
			model.play_state("air" if hv.length() > 2.4 else "fall")
			model.set_loco_speed(hv.length())
	else:
		if air_time > 0.35:
			model.play_once("JumpLand", 1.6, true)
		air_time = 0.0
		if slide_time > 0.0:
			model.play_state("slide")
		elif hv.length() > current_speed() * 1.1 and hv.length() > 5.0:
			model.play_state("sprint")
		elif hv.length() > CharacterModel.WALK_MAX:
			model.play_state("run")
		elif hv.length() > 0.7:
			model.play_state("walk")
		else:
			model.play_state("idle")
		model.set_loco_speed(hv.length())                  # feet keep pace with the ground


func add_impulse(v: Vector3) -> void:
	var r := 1.0 - clampf(stats.fraction("knockback_resist", 0.9) + stats.add_sum("knockback_taken") * -1.0 * 0.0, 0.0, 0.9)
	r *= maxf(0.1, 1.0 + stats.mult_sum("knockback_taken"))
	impulse += v * r
	if v.y > 0.1:
		velocity.y = maxf(velocity.y, v.y)
		impulse.y = 0.0


func model_forward() -> Vector3:
	return Vector3(facing.x, 0, facing.z).normalized()


func face_toward(dir: Vector3, instant: bool = false, delta: float = 0.0) -> void:
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() < 0.01:
		return
	var target := atan2(-d.x, -d.z)                 # yaw so that -Z points along d
	if instant:
		model.rotation.y = target
	else:
		model.rotation.y = lerp_angle(model.rotation.y, target, clampf(delta * 14.0, 0.0, 1.0))
	facing = d.normalized()


func forward_vector() -> Vector3:
	var yaw := model.rotation.y
	return Vector3(-sin(yaw), 0, -cos(yaw))


func eye_position() -> Vector3:
	return global_position + Vector3(0, 1.55 * float(stats.value("size", 1.0)), 0)


func chest_position() -> Vector3:
	return global_position + Vector3(0, 1.1 * float(stats.value("size", 1.0)), 0)


# ================================================================= health, damage, healing

func heal(amount: float, source: Node, show_number: bool = true) -> float:
	if dead or amount <= 0.0:
		return 0.0
	amount *= statuses.heal_taken_mult() * (1.0 + stats.mult_sum("heal_power"))
	var before := health
	health = minf(health + amount, max_health())
	var got := health - before
	if got > 0.5 and show_number and (is_player or (match_ref != null and match_ref.player != null and global_position.distance_to(match_ref.player.global_position) < 40.0)):
		Fx.damage_number(global_position + Vector3(0, 2.0, 0), got, Color.WHITE, false, true)
	health_changed.emit(health, max_health())
	if source != null and source is Combatant and source != self:
		(source as Combatant).add_meter(got * 0.3)
	return got


func spend_mana(amount: float) -> bool:
	var cost := amount * maxf(0.0, 1.0 + stats.mult_sum("mana_cost"))
	if free_casts > 0 and amount > 0.0:
		return true
	if mana + 0.001 < cost:
		return false
	mana -= cost
	mana_changed.emit(mana, max_mana())
	return true


func restore_mana(amount: float) -> void:
	mana = minf(mana + amount, max_mana())
	mana_changed.emit(mana, max_mana())


func add_meter(amount: float) -> void:
	var cap := 100.0 + stats.add_sum("meter_overfill") * 100.0
	var before := meter
	meter = minf(cap, meter + amount * (1.0 + stats.mult_sum("meter_gain")))
	if before < 99.9 and meter >= 99.9:
		meter_full.emit()


func add_ult(amount: float) -> void:
	ult_charge = minf(100.0, ult_charge + amount * (1.0 + stats.mult_sum("ultimate_charge")))


## Damage this combatant deals to `victim`. `base` is before multipliers. info: magic, skill (bool), aoe (bool), melee (bool), tags.
func deal(victim: Combatant, base: float, info: Dictionary = {}) -> float:
	if victim == null or victim.dead or victim.team == team and not info.get("friendly", false):
		return 0.0
	var amt := base * statuses.damage_dealt_mult()
	var is_spell: bool = info.get("magic", false)
	var is_skill: bool = info.get("skill", false)
	if is_spell:
		amt *= 1.0 + stats.mult_sum("spell_damage")
	else:
		amt *= 1.0 + stats.mult_sum("weapon_damage")
		if info.get("melee", false):
			amt *= 1.0 + stats.mult_sum("melee_damage")
	if is_skill:
		amt *= 1.0 + stats.mult_sum("skill_damage")
		if info.get("own_class", false):
			amt *= _own_class_boost + stats.mult_sum("own_class_damage")
	if info.get("aoe", false):
		amt *= 1.0 + stats.mult_sum("aoe_damage")
	amt *= 1.0 + 0.1 * minf(streak, 10.0)                          # kill streak: +10% each, up to +100%
	var dist := global_position.distance_to(victim.global_position)
	if dist > 25.0:
		amt *= 1.0 + stats.mult_sum("damage_far")
	elif dist < 8.0:
		amt *= 1.0 + stats.mult_sum("damage_near")
	var hp_frac := victim.health / maxf(victim.max_health(), 1.0)
	if hp_frac < 0.3:
		amt *= 1.0 + stats.add_sum("damage_vs_low")
	if hp_frac >= 0.999 and not info.get("dot", false):
		amt *= 1.0 + stats.add_sum("first_hit_bonus")
	if victim.statuses.has("marked"):
		amt *= 1.0 + stats.add_sum("mark_bonus")
	if _combo_hits > 0:
		amt *= 1.0 + minf(float(_combo_hits), 10.0) * stats.add_sum("combo_per_hit")
	if stats.add_sum("full_mana_damage") > 0.0 and mana >= max_mana() * 0.98 and is_skill:
		amt *= 1.0 + stats.add_sum("full_mana_damage")
	if stats.add_sum("full_meter_damage") > 0.0 and meter >= 99.0:
		amt *= 1.0 + stats.add_sum("full_meter_damage")
	var crit := false
	if not info.get("no_crit", false) and randf() < stats.fraction("crit_chance", 0.95):
		amt *= 1.5 + 0.0
		crit = true
	var inf := info.duplicate()
	inf["crit"] = crit
	inf["from"] = self
	var done := victim.take_damage(amt, self, inf)
	if done > 0.0:
		_after_hit(victim, done, inf)
	return done


func _after_hit(victim: Combatant, amount: float, info: Dictionary) -> void:
	dealt_damage_total += amount
	dealt.emit(victim, amount, info)
	_last_hit_time = Time.get_ticks_msec() / 1000.0
	_combo_hits += 1
	var ls := stats.add_sum("lifesteal") + stats.add_sum("ally_lifesteal") * 0.0
	if ls > 0.0:
		heal(amount * ls, null, false)
	add_meter(amount * 0.15)
	add_ult(amount * 0.04)
	if not info.get("no_status", false):
		_apply_on_hit(victim, info)
	if victim.dead:
		return


func _apply_on_hit(victim: Combatant, info: Dictionary) -> void:
	var hits: Array = []
	if not weapon.is_empty() and weapon.has("on_hit") and not info.get("skill", false):
		hits.append(weapon["on_hit"])
	var cp: Dictionary = Data.classes[class_id]["passive"]
	if cp.has("on_hit_status"):
		hits.append(cp["on_hit_status"])
	for p in stats.payloads("_on_hit"):
		hits.append(p)
	for p in stats.payloads("set_on_hit"):
		hits.append(p)
	for p in stats.payloads("on_hit"):
		hits.append(p)
	for rid in Data.rune_order:
		var t: Variant = null
		var arr: Array = stats.payloads("trigger_" + rid)
		if arr.size() > 0 and typeof(arr[0]) == TYPE_DICTIONARY and arr[0].has("on_hit"):
			hits.append(arr[0]["on_hit"])
	for h in hits:
		if randf() < float(h.get("p", 1.0)):
			victim.statuses.apply(String(h["id"]), float(h.get("dur", -1.0)), int(h.get("n", 1)), self)
	var elem := stats.add_sum("elemental_chance")
	if elem > 0.0 and randf() < elem:
		victim.statuses.apply("burn" if randf() < 0.5 else "chill", -1.0, 1, self)
	var tip := stats.add_sum("poison_tip_dps")
	if tip > 0.0 and info.get("melee", true):
		victim.statuses.apply("poison", 4.0, 1, self)
	var slow := stats.add_sum("hit_slow")
	if slow > 0.0:
		victim.statuses.apply("slow", 1.5, 1, self)


func take_damage(amount: float, source: Variant, info: Dictionary = {}) -> float:
	if Net.is_client:
		return 0.0                                       # on a joined machine the host decides who is hurt; it sends health and the hit effects
	if source != null and not is_instance_valid(source):
		source = null                                # the attacker was freed meanwhile (a minion that timed out...)
	if dead or amount <= 0.0:
		return 0.0
	var now := Time.get_ticks_msec() / 1000.0
	if now < invulnerable_until:
		return 0.0
	if info.get("dot", "") == "":
		last_seen_time = now
	var magic: bool = info.get("magic", false)
	var amt := amount * statuses.damage_taken_mult()
	if info.get("dot", "") != "":
		amt *= 1.0                                   # damage over time ignores armor
	elif magic:
		amt *= 1.0 - clampf(stats.fraction("spell_res", 0.8), 0.0, 0.8)
	else:
		var arm := stats.fraction("armor", 0.8)
		if still_time > 2.0:
			arm += stats.add_sum("still_armor")
		amt *= 1.0 - clampf(arm, 0.0, 0.85)
		if info.get("ranged", false):
			amt *= 1.0 - clampf(stats.add_sum("ranged_block"), 0.0, 0.9)
	if still_time > 3.0:
		amt *= 1.0 - clampf(stats.add_sum("still_damage_reduction"), 0.0, 0.7)
	if now - last_seen_time < 3.0 and stats.add_sum("hurt_armor") > 0.0:
		amt *= 1.0 - stats.add_sum("hurt_armor")
	if randf() < stats.add_sum("set_dodge") and info.get("dot", "") == "":
		Fx.damage_number(global_position + Vector3(0, 2.2, 0), 0, Color(0.8, 0.8, 1.0))
		return 0.0
	if source is Combatant:
		# the first hit of a type against a mythic style "deflect" etc. could go here; keep the rule table small and readable
		pass
	var left := statuses.absorb(amt)
	if left < amt and left <= 0.01:
		Fx.impact(global_position + Vector3(0, 1.2, 0), Color(0.5, 0.8, 1.0))
	if left <= 0.0:
		return 0.0
	# arcane armor: part of the damage drains mana instead
	var mana_part := stats.add_sum("mana_shield")
	if mana_part > 0.0 and mana > 0.0:
		var m := minf(mana, left * mana_part)
		mana -= m
		left -= m
		mana_changed.emit(mana, max_mana())
	hp_before_last = health
	last_damage_info = info
	Sfx.at("hurt" if name == "Player" else "hit", global_position, -2.0, 0.9 + 0.2 * randf())
	health -= left
	if stats.add_sum("last_stand") > 0.0 and health < 1.0:
		health = 1.0
	_last_hit_time_taken = now
	health_changed.emit(health, max_health())
	damaged.emit(left, source, info)
	var crit: bool = info.get("crit", false)
	if model != null and info.get("dot", "") == "":
		model.flash(TEAM_COLORS.get(team, Color.WHITE) if false else Color(1, 0.3, 0.3))
		if left > max_health() * 0.08:
			model.play_once("HitChest", 1.2, true)
	if match_ref != null and match_ref.player != null:
		var pl: Combatant = match_ref.player
		if source == pl or self == pl or global_position.distance_to(pl.global_position) < 30.0:
			var col: Color = Color(info["color"][0], info["color"][1], info["color"][2]) if info.has("color") else (Color(1, 0.4, 0.35) if self == pl else Color(1, 1, 1))
			Fx.damage_number(global_position + Vector3(0, 2.1, 0), left, col, crit)
	if model != null:
		model.set_health_fraction(health / max_health())
	if source is Combatant and source != self:
		var src := source as Combatant
		var thorns := stats.add_sum("reflect") + stats.add_sum("set_reflect") + (stats.add_sum("reflect_melee") if info.get("melee", false) else 0.0)
		if thorns > 0.0 and info.get("dot", "") == "" and not info.get("reflected", false):
			src.take_damage(left * thorns, self, {"reflected": true, "no_status": true})
		if info.get("dot", "") == "":
			var aura: Array = stats.payloads("set_aura")
			for a in aura:
				if global_position.distance_to(src.global_position) <= float(a.get("radius", 4)) + 1.0:
					for s in a["sts"]:
						src.statuses.apply(String(s["id"]), float(s.get("dur", -1.0)), int(s.get("n", 1)), self)
		src.add_ult(left * 0.03)
	if stats.add_sum("low_health_explosion") > 0.0 and health < max_health() * 0.25 and not _explosion_used:
		_explosion_used = true
		if match_ref != null:
			match_ref.explosion(global_position, 5.0, stats.add_sum("low_health_explosion"), self, Color(1, 0.5, 0.2))
	var low_b := float(stats.payloads("set_low_health_barrier")[0]) if stats.payloads("set_low_health_barrier").size() > 0 else 0.0
	if low_b > 0.0 and health < max_health() * 0.5 and now - _barrier_time > 40.0:
		_barrier_time = now
		statuses.apply("barrier", 6.0, 1, self, low_b / 60.0)
	if health <= 0.0:
		die(source)
	return left


var dealt_damage_total := 0.0
var last_damage_info: Dictionary = {}
var hp_before_last := 0.0
var _last_hit_time_taken := 0.0
var _explosion_used := false
var _barrier_time := -99.0


func die(killer: Node) -> void:
	if dead:
		return
	# second life effects
	if stats.add_sum("revive_health") > 0.0 and not _revive_used and not Net.is_client:
		_revive_used = true
		health = max_health() * clampf(stats.add_sum("revive_health"), 0.1, 1.0)
		health_changed.emit(health, max_health())
		Fx.level_up(self)
		return
	dead = true
	deaths += 1
	health = 0.0
	Sfx.at("death", global_position)
	streak = 0
	statuses.clear_all()
	collision_layer = 0
	if model != null:
		# a ragdoll: the hit that killed pushes the body away from the attacker (a random way when nobody is to blame, like a fall)
		var pushed := false
		if bool(Settings.v.get("ragdoll", true)):
			var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
			if killer is Combatant and is_instance_valid(killer) and killer != self:
				var away: Vector3 = global_position - (killer as Combatant).global_position
				away.y = 0.0
				if away.length() > 0.1:
					dir = away.normalized()
			var kick := 4.5 if dead_by_big_hit() else 3.0
			pushed = model.start_ragdoll(dir * kick + Vector3(0, 2.0, 0) + Vector3(velocity.x, 0, velocity.z) * 0.5)
		if not pushed:
			model.play_once("Death", 1.0, true)
			model.play_state("death", true)
		model.set_plate_visible(false)
	health_changed.emit(0.0, max_health())
	died.emit(killer)
	if killer is Combatant and killer != self:
		(killer as Combatant)._on_kill(self)


## GM Ravn's finisher: a kill with the ultimate is a CHECKMATE: a golden burst where the victim fell, a announcement, a quarter of the ultimate back and some health.
func _checkmate(victim: Combatant) -> void:
	var at := victim.global_position
	Fx.crate_burst(at, "legendary")
	Fx.ring(at, 7.0, Color(1.0, 0.85, 0.4), 0.9)
	Fx.lightning_strike(at, 30.0)
	ult_charge = minf(100.0, ult_charge + 25.0)
	heal(max_health() * 0.12, null)
	Sfx.at("chest", at)
	if match_ref != null:
		match_ref.hud_toast("CHECKMATE! %s is taken" % victim.display_name, Color(1.0, 0.88, 0.45))


func _on_kill(victim: Combatant) -> void:
	kills += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	streak_timer = 25.0
	killed_enemy.emit(victim)
	if class_id == "gm_ravn" and last_skill_slot == "ult" and bool(victim.last_damage_info.get("skill", false)):
		_checkmate(victim)
	var heal_k: float = stats.add_sum("heal_on_kill") + stats.add_sum("set_heal_on_kill") + stats.add_sum("kill_temp_health") * max_health()
	if heal_k > 0.0:
		heal(heal_k, null)
	var bar := stats.add_sum("kill_barrier")
	if bar > 0.0:
		statuses.apply("barrier", 5.0, 1, self, bar * max_health() / 60.0)
	restore_mana(stats.add_sum("kill_mana") * max_mana())
	add_meter(stats.add_sum("kill_meter") * 100.0)
	var cdr := stats.add_sum("kill_cdr")
	if cdr > 0.0:
		for s in cooldowns:
			cooldowns[s] = maxf(0.0, cooldowns[s] * (1.0 - cdr))
	var inv := stats.add_sum("kill_invisible")
	if inv > 0.0:
		statuses.apply("invisible", inv, 1, self)
	var ref := stats.add_sum("ammo_refund_on_kill")
	if ref > 0.0 and weapon.has("ammo"):
		ammo = minf(float(weapon["ammo"]) * (1.0 + stats.mult_sum("max_ammo")), ammo + float(weapon["ammo"]) * ref)
	add_ult(12.0)
	if is_player:
		Game.add_xp(40.0 + 3.0 * float(victim.get_meta("level", 1)))


var _history: Array = []
var _hist_t := 0.0


func rewind(seconds: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var pick: Array = []
	for h in _history:
		if now - float(h[2]) >= seconds:
			pick = h
	if pick.is_empty() and not _history.is_empty():
		pick = _history[0]
	if pick.is_empty():
		return
	Fx.impact(global_position + Vector3(0, 1, 0), Color(0.9, 0.8, 0.4), true)
	global_position = pick[0]
	health = maxf(health, float(pick[1]))
	velocity = Vector3.ZERO
	health_changed.emit(health, max_health())
	Fx.impact(global_position + Vector3(0, 1, 0), Color(0.9, 0.8, 0.4), true)


func snap_to_ground() -> void:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 60, 0), global_position - Vector3(0, 30, 0), 1))
	if not hit.is_empty():
		global_position.y = hit["position"].y + 0.05


func respawn(pos: Vector3) -> void:
	dead = false
	collision_layer = 2
	global_position = pos
	velocity = Vector3.ZERO
	impulse = Vector3.ZERO
	health = max_health()
	mana = max_mana()
	statuses.clear_all()
	invulnerable_until = Time.get_ticks_msec() / 1000.0 + 2.5
	_explosion_used = false
	for s in cooldowns:
		if s != "ult":
			cooldowns[s] = 0.0
	meter = meter * stats.add_sum("meter_keep")
	if model != null:
		model.stop_ragdoll()
		model.anim.stop()
		model.play_state("idle", true)
		model.set_plate_visible(true)
		model.set_health_fraction(1.0)
	if not is_player:
		weapon_item = weapon_item
	health_changed.emit(health, max_health())
	mana_changed.emit(mana, max_mana())
	respawned.emit()
	statuses.apply("barrier", 2.5, 1, self, 0.5)


# ================================================================= per-frame upkeep (called by Player / Bot / Match)

func tick(delta: float) -> void:
	if dead:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_hist_t += delta
	if _hist_t >= 0.25:
		_hist_t = 0.0
		_history.append([global_position, health, now])
		if _history.size() > 28:
			_history.pop_front()
	for s in cooldowns:
		if cooldowns[s] > 0.0:
			cooldowns[s] = maxf(0.0, cooldowns[s] - delta * (1.0 + stats.add_sum("cooldown_reduction") * 0.0))
	if attack_cd > 0.0:
		attack_cd -= delta
	if casting_lock > 0.0:
		casting_lock -= delta
	if move_lock > 0.0:
		move_lock -= delta
	if sprint_boost_left > 0.0:
		sprint_boost_left -= delta
		if sprint_boost_left <= 0.0:
			sprint_boost = 1.0
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0 and weapon.has("ammo"):
			ammo = float(weapon["ammo"]) * (1.0 + stats.mult_sum("max_ammo"))
	if streak_timer > 0.0:
		streak_timer -= delta
		if streak_timer <= 0.0:
			streak = 0
	for k in temp_mods.keys():
		if now > float(temp_mods[k]["until"]):
			temp_mods.erase(k)
			stats.remove_source("temp:" + String(k))
	# regeneration
	var hr := stats.value("health_regen", 0.0)
	_regen_acc += delta
	if _regen_acc >= 0.5:
		var step := _regen_acc
		_regen_acc = 0.0
		if hr > 0.0:
			heal(hr * step, null, false)
		restore_mana(stats.value("mana_regen", 4.0) * step)
		# hidden recovery: heal while unseen and moving
		if unseen_time > 3.0 and velocity.length() > 1.0:
			heal(3.0 * step, null, false)
			restore_mana(2.0 * step)
		# class meter decays slowly
		var decay: float = float(Data.classes[class_id]["meter"].get("decay", 3.0)) * maxf(0.1, 1.0 + stats.mult_sum("meter_decay"))
		meter = maxf(0.0, meter - decay * step)
	var spd := velocity.length()
	if spd < 0.3:
		still_time += delta
	else:
		still_time = 0.0
	if _combo_hits > 0 and now - _last_hit_time > 2.5:
		_combo_hits = 0
	if statuses.has_flag("invisible") and not is_player and model != null:
		pass
	if _aura_node != null:
		pass
	if model != null:
		model.set_health_fraction(health / max_health())


func has_line_of_sight(other: Combatant) -> bool:
	var from := eye_position()
	var to := other.chest_position()
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func nearest_enemy(within: float = 60.0) -> Combatant:
	var best: Combatant = null
	var bd := within
	if match_ref == null:
		return null
	for e in match_ref.enemies_of(team):
		if e.dead or not e.is_visible_to(self):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	return best


func skill_for_slot(slot: String) -> Dictionary:
	if slot == "s1" and has_meta("force_skill"):
		return get_meta("force_skill")
	var d: Dictionary = Data.classes[class_id]
	match slot:
		"s1": return Data.skills.get(skill_ids[0], {}) if skill_ids.size() > 0 else {}
		"s2": return Data.skills.get(skill_ids[1], {}) if skill_ids.size() > 1 else {}
		"s3": return Data.skills.get(skill_ids[2], {}) if skill_ids.size() > 2 else {}
		"sig": return Data.skills[d["signature"]]
		"ult": return Data.skills[d["ultimate"]]
	return {}


func skill_cooldown_total(skill: Dictionary) -> float:
	var cd := float(skill.get("cooldown", 10.0))
	cd *= maxf(0.2, 1.0 - clampf(stats.add_sum("cooldown_reduction"), 0.0, 0.6))
	if String(skill.get("fx", {}).get("t", "")) == "sprint":
		cd *= maxf(0.3, 1.0 + stats.mult_sum("sprint_cooldown"))
	return cd


## A little cloud of dust behind the feet while sprinting.
func _set_sprint_dust(on: bool) -> void:
	if on and _sprint_dust == null:
		_sprint_dust = Fx.particles({"tex": "smoke", "amount": 12, "life": 0.5, "shape": "point", "dir": Vector3.UP, "spread": 40, "vel": [0.3, 0.9], "size": [0.25, 0.5],
			"colors": [Color(0.85, 0.82, 0.75, 0.0), Color(0.85, 0.82, 0.75, 0.35), Color(0.85, 0.82, 0.75, 0.0)], "local": false, "additive": false})
		add_child(_sprint_dust)
		_sprint_dust.position = Vector3(0, 0.1, 0)
	if _sprint_dust != null:
		_sprint_dust.emitting = on


## Did the hit that killed this fighter take a large part of its health in one blow (the body is then thrown harder)?
func dead_by_big_hit() -> bool:
	return hp_before_last > 0.0 and hp_before_last >= max_health() * 0.5 and last_damage_info.get("dot", "") == ""
