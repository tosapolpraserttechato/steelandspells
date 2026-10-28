class_name Bot
extends Combatant
## A computer-controlled fighter for offline matches. Heads for capture points, fights the nearest visible enemy, uses skills and its ultimate.
## No navigation mesh: it steers straight at its goal, feels for walls with whisker rays, jumps small obstacles and slides off when stuck.

var skill_level := 0.6                        # 0..1, aim and reaction quality
var target: Combatant = null
var goal := Vector3.ZERO                      # where to walk when there is no fight
var goal_timer := 0.0
var strafe_dir := 1.0
var strafe_timer := 0.0
var think_timer := 0.0
var stuck_timer := 0.0
var last_pos := Vector3.ZERO
var avoid := Vector3.ZERO
var minion_of: Combatant = null
var life_left := -1.0                         # minions live for a while
var is_decoy := false
var _aim_noise := Vector3.ZERO
var _burst_left := 0
var _skill_timer := 1.5


func setup_bot(cls: String, team_name: String, name_text: String, skill: float) -> void:
	setup(cls, team_name, name_text, false)
	skill_level = skill
	var all: Array = Data.classes[cls]["skills"]
	var picks: Array = []
	var pool := all.duplicate()
	pool.shuffle()
	for i in 3:
		picks.append(pool[i])
	skill_ids = picks
	_skill_timer = randf_range(1.0, 3.0)
	strafe_dir = 1.0 if randf() < 0.5 else -1.0


func _physics_process(delta: float) -> void:
	tick(delta)
	if life_left >= 0.0:
		life_left -= delta
		if life_left <= 0.0:
			Fx.impact(global_position + Vector3(0, 1, 0), Color(0.7, 0.8, 1.0), true)
			queue_free()
			return
	if dead:
		physics_move(delta, Vector3.ZERO, false)
		return
	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = lerpf(0.5, 0.2, skill_level)
		_think()
	var wish := Vector3.ZERO
	var jump := false
	var sprint := false
	if is_decoy:
		wish = facing
	elif target != null and is_instance_valid(target) and not target.dead:
		var to_t := target.global_position - global_position
		var flat := Vector3(to_t.x, 0, to_t.z)
		var dist := flat.length()
		var ideal := _ideal_range()
		_aim_at(target, delta)
		strafe_timer -= delta
		if strafe_timer <= 0.0:
			strafe_timer = randf_range(0.8, 2.2)
			strafe_dir = -strafe_dir if randf() < 0.6 else strafe_dir
		if dist > ideal + 2.0:
			wish = flat.normalized()
			sprint = dist > ideal + 12.0
		elif dist < ideal - 3.0:
			wish = -flat.normalized() * 0.6
		var side := flat.normalized().cross(Vector3.UP) * strafe_dir
		wish += side * 0.7
		if dist <= ideal + 6.0:
			_fight(delta, dist)
	else:
		aim_dir = forward_vector()
		goal_timer -= delta
		var to_g := goal - global_position
		to_g.y = 0.0
		if goal_timer <= 0.0 or to_g.length() < 4.0:
			_pick_goal()
		wish = to_g.normalized()
		sprint = to_g.length() > 25.0
	wish = _steer(wish, delta)
	if wish.length() > 1.0:
		wish = wish.normalized()
	wish_dir = wish
	if stuck_timer > 0.6:
		jump = true
		if stuck_timer > 1.4:
			avoid = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			stuck_timer = 0.0
	if target != null and is_instance_valid(target) and not target.dead:
		face_toward(target.global_position - global_position, false, delta)
	elif wish.length() > 0.1:
		face_toward(wish, false, delta)
	physics_move(delta, wish, jump, sprint)
	if global_position.distance_to(last_pos) < 0.04 and wish.length() > 0.3:
		stuck_timer += delta
	else:
		stuck_timer = maxf(0.0, stuck_timer - delta * 2.0)
	last_pos = global_position
	if match_ref != null and global_position.y < match_ref.kill_plane_y:
		take_damage(9999.0, null, {"dot": "void"})


func _ideal_range() -> float:
	if weapon.is_empty():
		return 12.0
	match String(weapon["fire"]):
		"melee": return 2.6
		"thrown": return 14.0
	return 10.0 + 12.0 * skill_level


func _aim_at(t: Combatant, delta: float) -> void:
	var target_pos := t.chest_position()
	# lead the target a little for projectiles
	if not weapon.is_empty() and String(weapon["fire"]) != "melee":
		var speed := float(weapon.get("speed", 60.0))
		var tt := global_position.distance_to(target_pos) / maxf(speed, 10.0)
		target_pos += t.velocity * tt * (0.4 + 0.6 * skill_level)
	_aim_noise = _aim_noise.lerp(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (1.4 - skill_level), clampf(delta * 3.0, 0.0, 1.0))
	aim_point = target_pos + _aim_noise
	aim_dir = (aim_point - chest_position()).normalized()


func _fight(delta: float, dist: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not has_line_of_sight(target):
		return
	if not weapon.is_empty():
		var reach: float = float(weapon.get("range", 3.0)) * 0.95
		if dist <= reach or String(weapon["fire"]) != "melee" and dist < 60.0:
			WeaponRunner.attack(self)
	_skill_timer -= delta
	if _skill_timer <= 0.0:
		_skill_timer = randf_range(1.2, 3.2) / (0.5 + skill_level)
		var order := ["s1", "s2", "s3", "sig"]
		order.shuffle()
		for s in order:
			if SkillRunner.can_use(self, s):
				var sk: Dictionary = skill_for_slot(s)
				var need := _skill_range(sk)
				if dist <= need and mana >= float(sk.get("mana", 0.0)):
					SkillRunner.use(self, s)
					break
	if SkillRunner.can_use(self, "ult") and _enemies_near(16.0) >= 2:
		SkillRunner.use(self, "ult")
	if health < max_health() * 0.4 and Game.potions.has("potion_health") and false:
		pass


func _skill_range(sk: Dictionary) -> float:
	var fx: Dictionary = sk.get("fx", {})
	match String(fx.get("t", "")):
		"projectile", "beam": return 40.0
		"cone": return float(fx.get("range", 8.0))
		"sprint", "leap": return 18.0
		"buff", "heal": return 30.0
		"aoe", "zone", "strikes":
			return 30.0 if String(fx.get("at", "target")) == "target" else float(fx.get("radius", 6.0)) * 0.9
	return 25.0


func _enemies_near(r: float) -> int:
	var n := 0
	if match_ref == null:
		return 0
	for e in match_ref.enemies_of(team):
		if not e.dead and e.global_position.distance_to(global_position) < r:
			n += 1
	return n


func _think() -> void:
	if match_ref == null:
		return
	var best: Combatant = null
	var bd := float(stats.value("sight", 70.0))
	for e in match_ref.enemies_of(team):
		if e.dead or not e.is_visible_to(self):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < bd and (d < 14.0 or has_line_of_sight(e)):
			bd = d
			best = e
	target = best
	if match_ref.mode == "ctf":
		# a flag carrier runs home; everyone else re-aims quickly while their own flag is out
		var own: FlagNode = match_ref.flags.get(team)
		if carrying_flag != null or (own != null and own.state != "home"):
			goal = match_ref.bot_goal(self)
			goal_timer = 1.5
	if health < max_health() * 0.3 and target != null and randf() < 0.5:
		var home: Vector3 = match_ref.spawn_point(team)
		goal = home
		target = null
		goal_timer = 4.0


func _pick_goal() -> void:
	goal_timer = randf_range(6.0, 14.0)
	if match_ref == null:
		goal = global_position
		return
	goal = match_ref.bot_goal(self)


## Steering: bend the wish direction away from walls found by three short rays; stay inside the map bounds.
func _steer(wish: Vector3, delta: float) -> Vector3:
	if wish.length() < 0.1:
		return wish
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.6, 0)
	var dir := wish.normalized()
	var result := dir
	var side := dir.cross(Vector3.UP)
	var best_clear := -1.0
	var pick := dir
	for k: float in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var d := (dir + side * k).normalized()
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * 2.4, 1)
		var hit := space.intersect_ray(q)
		var clear: float = 2.4 if hit.is_empty() else (hit["position"] - origin).length()
		if hit.is_empty() and k == 0.0:
			result = dir
			pick = dir
			best_clear = 99.0
			break
		if clear > best_clear:
			best_clear = clear
			pick = d
	result = pick
	if avoid.length() > 0.1:
		result = (result + avoid * 0.8).normalized()
		avoid = avoid.move_toward(Vector3.ZERO, delta)
	return result
