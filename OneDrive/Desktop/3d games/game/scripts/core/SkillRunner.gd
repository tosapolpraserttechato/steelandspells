class_name SkillRunner
extends RefCounted
## Runs a skill from its data (Data.skills[id].fx). Effect types: projectile, beam, cone, aoe, zone, sprint, teleport, leap, buff, heal,
## summon, wall, trap, strikes. Numbers (damage, radius, status lists) all come from tools/data_classes.py and data_extra.py.

const SLOT_LABEL := {"s1": "Skill 1", "s2": "Skill 2", "s3": "Skill 3", "sig": "Signature", "ult": "Ultimate"}


static func can_use(c: Combatant, slot: String) -> bool:
	if c.dead or c.casting_lock > 0.0:
		return false
	var skill: Dictionary = c.skill_for_slot(slot)
	if skill.is_empty():
		return false
	if not c.statuses.can_cast():
		return false
	if c.cooldowns.get(slot, 0.0) > 0.0:
		return false
	if slot == "ult" and c.ult_charge < 99.9:
		return false
	return true


## Casts the skill in `slot` ("s1", "s2", "s3", "sig", "ult"). Returns true when it went off.
static func use(c: Combatant, slot: String) -> bool:
	if not can_use(c, slot):
		return false
	var skill: Dictionary = c.skill_for_slot(slot)
	var mana: float = float(skill.get("mana", 0.0))
	if slot != "ult" and not c.spend_mana(mana):
		return false
	if c.free_casts > 0 and slot != "ult" and mana > 0.0:
		c.free_casts -= 1
	var fx: Dictionary = skill["fx"]
	var own: bool = skill.get("class", "") == c.class_id
	var color: Color = Data.color_of(skill.get("color", [1, 1, 1]))
	c.cooldowns[slot] = c.skill_cooldown_total(skill)
	if slot == "ult":
		c.ult_charge = 0.0
	c.casting_lock = maxf(0.22, float(skill.get("cast", 0.0)) / (1.0 + c.stats.mult_sum("cast_speed")))
	c.last_skill_slot = slot
	c.add_meter(12.0)
	c.add_ult(3.0)
	var t: String = fx.get("t", "aoe")
	AnimRecipes.play_skill(c, skill, slot)
	Sfx.at("whoosh" if t in ["sprint", "leap", "teleport"] else "cast", c.global_position, 0.0, 0.8 + 0.4 * float(absi(String(skill.get("id", "")).hash()) % 100) / 100.0)
	match t:
		"projectile": _projectile(c, skill, fx, own, color)
		"beam": _beam(c, skill, fx, own, color)
		"cone": _cone(c, skill, fx, own, color)
		"aoe": _aoe(c, skill, fx, own, color)
		"zone": _zone(c, skill, fx, own, color)
		"sprint": _sprint(c, skill, fx, own, color)
		"teleport": _teleport(c, skill, fx, color)
		"leap": _leap(c, skill, fx, own, color)
		"buff": _buff(c, skill, fx, color)
		"heal": _heal(c, skill, fx, color)
		"summon": _summon(c, skill, fx, color)
		"wall": _wall(c, skill, fx, own, color)
		"trap": _trap(c, skill, fx, own, color)
		"strikes": _strikes(c, skill, fx, own, color)
	var echo: float = c.stats.add_sum("echo_chance")
	if echo > 0.0 and randf() < echo and slot != "ult":
		Util.after(c, 0.4, func() -> void:
			if is_instance_valid(c) and not c.dead:
				_repeat(c, skill, fx, own, color, t))
	if slot == "ult":
		var chain: float = c.stats.add_sum("ultimate_chain_damage")
		if chain > 0.0 and c.match_ref != null:
			for e in c.match_ref.enemies_of(c.team):
				if not e.dead and e.global_position.distance_to(c.global_position) < 40.0:
					Fx.lightning_strike(e.global_position)
					c.deal(e, chain, {"magic": true, "skill": true, "no_status": true})
		var again: float = c.stats.value("ult_recast_delay", 0.0)
		if again > 0.0:
			Util.after(c, again, func() -> void:
				if is_instance_valid(c) and not c.dead:
					_repeat(c, skill, fx, own, color, t))
	c.skill_used.emit(slot, skill)
	return true


static func _repeat(c: Combatant, skill: Dictionary, fx: Dictionary, own: bool, color: Color, t: String) -> void:
	match t:
		"projectile": _projectile(c, skill, fx, own, color)
		"beam": _beam(c, skill, fx, own, color)
		"cone": _cone(c, skill, fx, own, color)
		"aoe": _aoe(c, skill, fx, own, color)
		"zone": _zone(c, skill, fx, own, color)
		"strikes": _strikes(c, skill, fx, own, color)


static func _animate(c: Combatant, t: String) -> void:
	if c.model == null:
		return
	match t:
		"projectile", "beam":
			c.model.play_once("CastShoot" if c.is_magic() else "Throw", 1.4, true)
		"sprint", "leap":
			c.model.play_once("Hook", 1.2, true)
		"cone":
			c.model.play_once("MeleeB", 1.5, true)
		"buff", "heal", "summon":
			c.model.play_once("CastEnter", 1.5, true)
		_:
			c.model.play_once("CastShoot", 1.3, true)


# ----------------------------------------------------------------- helpers

static func _statuses_list(fx: Dictionary, key: String = "sts") -> Array:
	return fx.get(key, [])


static func _apply_list(target: Combatant, list: Array, source: Combatant) -> void:
	for s in list:
		if randf() <= float(s.get("p", 1.0)):
			target.statuses.apply(String(s["id"]), float(s.get("dur", -1.0)), int(s.get("n", 1)), source)


static func _radius(c: Combatant, r: float) -> float:
	return r * (1.0 + c.stats.mult_sum("aoe_radius"))


static func _origin(c: Combatant) -> Vector3:
	return c.chest_position() + c.forward_vector() * 0.6


static func _aim_dir(c: Combatant) -> Vector3:
	return c.aim_dir if c.aim_dir.length() > 0.1 else c.forward_vector()


static func _target_point(c: Combatant, fx: Dictionary) -> Vector3:
	if String(fx.get("at", "target")) == "self":
		return c.global_position
	return c.aim_point if c.aim_point != Vector3.ZERO else c.global_position + c.forward_vector() * 8.0


static func _element_kind(list: Array, fallback: String) -> String:
	for s in list:
		match String(s["id"]):
			"burn": return "fire"
			"chill", "freeze": return "ice"
			"shock": return "storm"
			"poison": return "leaf"
	return fallback


static func _zone_kind(fx: Dictionary, color: Color) -> String:
	for s in fx.get("sts", []):
		match String(s["id"]):
			"burn": return "fire"
			"chill", "freeze": return "frost"
			"shock": return "storm"
			"poison": return "poison"
			"blind": return "smoke"
			"root": return "thorn"
	if fx.get("heal", 0.0) > 0.0:
		return "heal"
	return "void" if color.b > 0.7 and color.r > 0.4 else "arcane"


# ----------------------------------------------------------------- projectile

static func _projectile(c: Combatant, skill: Dictionary, fx: Dictionary, own: bool, color: Color) -> void:
	var n: int = int(fx.get("count", 1))
	var spread: float = float(fx.get("spread", 0.0))
	var base := _aim_dir(c)
	var sts: Array = _statuses_list(fx)
	var kind := _element_kind(sts, "bolt")
	for i in n:
		var p := Projectile.new()
		p.speed = float(fx.get("speed", 40.0))
		p.dmg = float(fx.get("dmg", 20.0))
		p.splash = _radius(c, float(fx.get("radius", 0.0)))
		p.life = float(fx.get("life", 2.0))
		p.pierce = bool(fx.get("pierce", false))
		p.pierce_left = 99 if p.pierce else 0
		p.homing = float(fx.get("homing", 0.0))
		p.sts = sts
		p.pull = float(fx.get("pull", 0.0))
		p.knock = float(fx.get("knock", 0.0))
		p.magic = c.is_magic() or skill.get("class", "") != "pirate_captain"
		p.skill = true
		p.own_class = own
		p.color = color
		p.kind = kind
		p.arc = false
		var yaw_off := 0.0
		if n > 1:
			yaw_off = deg_to_rad(spread) * (float(i) / float(n - 1) - 0.5) * 2.0 * 0.5
		var d := base.rotated(Vector3.UP, yaw_off)
		p.launch(c, _origin(c), d)


# ----------------------------------------------------------------- beam (instant line)

static func _beam(c: Combatant, skill: Dictionary, fx: Dictionary, own: bool, color: Color) -> void:
	var range_m: float = float(fx.get("range", 30.0))
	var width: float = float(fx.get("width", 0.4)) + 0.5
	var from := c.eye_position()
	var dir := _aim_dir(c)
	var end := from + dir * range_m
	var space := c.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, end, 1))
	if not hit.is_empty():
		end = hit["position"]
	var seg := end - from
	var len2 := maxf(seg.length_squared(), 0.001)
	var victims: Array = []
	for e in c.match_ref.enemies_of(c.team):
		if e.dead:
			continue
		var p: Vector3 = e.chest_position()
		var t := clampf((p - from).dot(seg) / len2, 0.0, 1.0)
		if (from + seg * t).distance_to(p) < width + 0.4 * float(e.stats.value("size", 1.0)):
			victims.append([t, e])
	victims.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var pierce: bool = bool(fx.get("pierce", false))
	for v in victims:
		var e: Combatant = v[1]
		var dealt := c.deal(e, float(fx.get("dmg", 20.0)), {"magic": true, "skill": true, "own_class": own, "ranged": true, "no_status": true})
		_apply_list(e, fx.get("sts", []), c)
		if fx.has("pull"):
			var d := c.global_position - e.global_position
			d.y = 0.0
			e.add_impulse(d.normalized() * float(fx["pull"]) * 1.4)
		if fx.has("knock"):
			e.add_impulse(dir * float(fx["knock"]) * 0.6 + Vector3(0, 2.0, 0))
		if fx.has("lifesteal"):
			c.heal(dealt * float(fx["lifesteal"]), null)
		if not pierce:
			end = e.chest_position()
			break
	Fx.beam(c.chest_position() + dir * 0.5, end, color, 0.25 + 0.2 * width, 0.2)
	Fx.impact(end, color, false)


# ----------------------------------------------------------------- cone

static func _cone(c: Combatant, skill: Dictionary, fx: Dictionary, own: bool, color: Color) -> void:
	var range_m: float = _radius(c, float(fx.get("range", 8.0)))
	var half: float = deg_to_rad(float(fx.get("angle", 60.0)) * 0.5)
	var fwd := _aim_dir(c)
	fwd.y = 0.0
	fwd = fwd.normalized()
	Fx.slash_trail(c.model, color, float(fx.get("angle", 60.0)), range_m * 0.9, 1.0 * float(c.stats.value("size", 1.0)))
	for e in c.match_ref.enemies_of(c.team):
		if e.dead:
			continue
		var rel: Vector3 = e.global_position - c.global_position
		rel.y = 0.0
		if rel.length() > range_m + 0.5:
			continue
		if rel.length() > 0.5 and fwd.angle_to(rel.normalized()) > half:
			continue
		c.deal(e, float(fx.get("dmg", 30.0)), {"magic": c.is_magic(), "skill": true, "aoe": true, "own_class": own, "melee": true, "no_status": true})
		_apply_list(e, fx.get("sts", []), c)
		if fx.has("knock"):
			e.add_impulse(rel.normalized() * float(fx["knock"]) + Vector3(0, 2.0, 0))
		Fx.impact(e.chest_position(), color, false)


# ----------------------------------------------------------------- aoe (delayed burst)

static func _aoe(c: Combatant, skill: Dictionary, fx: Dictionary, own: bool, color: Color) -> void:
	var at: Vector3 = _target_point(c, fx)
	var r := _radius(c, float(fx.get("radius", 6.0)))
	var delay: float = float(fx.get("delay", 0.3))
	if String(fx.get("at", "target")) == "target":
		var maxd := 38.0
		var rel := at - c.global_position
		if rel.length() > maxd:
			at = c.global_position + rel.normalized() * maxd
	var follow_self := String(fx.get("at", "target")) == "self"
	var tele := Fx.telegraph(at, r, color, delay, c if follow_self else null)
	if follow_self:
		tele.position = Vector3.ZERO
	var team := c.team
	Util.after(c, delay, func() -> void:
		if not is_instance_valid(c):
			return
		var center: Vector3 = c.global_position if follow_self else at
		_burst(c, center, r, fx, own, color)
		var again: float = c.stats.add_sum("aoe_second_hit")
		if again > 0.0:
			Util.after(c, 0.5, func() -> void:
				if is_instance_valid(c):
					var f2 := fx.duplicate()
					f2["dmg"] = float(fx.get("dmg", 10.0)) * again
					_burst(c, center, r, f2, own, color)))


static func _burst(c: Combatant, center: Vector3, r: float, fx: Dictionary, own: bool, color: Color) -> void:
	Fx.impact(center + Vector3(0, 0.4, 0), color, true)
	Fx.ring(center, r, color, 0.45)
	var targets := c.match_ref.enemies_of(c.team)
	for e in targets:
		if e.dead:
			continue
		if e.global_position.distance_to(center) > r + 0.4:
			continue
		var dealt := c.deal(e, float(fx.get("dmg", 30.0)), {"magic": true, "skill": true, "aoe": true, "own_class": own, "no_status": true})
		_apply_list(e, fx.get("sts", []), c)
		var d: Vector3 = e.global_position - center
		d.y = 0.0
		if fx.has("knock"):
			e.add_impulse(d.normalized() * float(fx["knock"]) + Vector3(0, 3.0, 0))
		if fx.has("pull") or c.stats.add_sum("signature_pull") > 0.0 and String(c.last_skill_slot) == "sig":
			var pull_m: float = float(fx.get("pull", 0.0)) + c.stats.add_sum("signature_pull")
			e.add_impulse(-d.normalized() * pull_m * 1.6)
		if c.stats.add_sum("signature_burn") > 0.0 and String(c.last_skill_slot) == "sig":
			e.statuses.apply("burn", 5.0, 2, c)
		if fx.get("finisher", false) and e.health <= 0.0:
			c.model.play_once("EmoteYes", 1.2, false)
	if fx.has("sts_self"):
		_apply_list(c, fx["sts_self"], c)
	if fx.get("queen", false) or fx.get("rook", false):
		for i in 12:
			if i % 3 == 0:
				var a := TAU * i / 12.0
				Fx.lightning_strike(center + Vector3(cos(a), 0, sin(a)) * r * 0.7, 25.0)


# ----------------------------------------------------------------- zone

static func _zone(c: Combatant, skill: Dictionary, fx: Dictionary, own: bool, color: Color) -> void:
	var at: Vector3 = _target_point(c, fx)
	var z := Zone.new()
	z.radius = _radius(c, float(fx.get("radius", 5.0)))
	z.tick = float(fx.get("tick", 1.0))
	z.dmg = float(fx.get("dmg", 0.0))
	z.heal_amount = float(fx.get("heal", 0.0))
	z.sts = fx.get("sts", [])
	z.pull = float(fx.get("pull", 0.0))
	z.magic = true
	z.own_class = own
	z.affects_allies = z.heal_amount > 0.0
	var dur: float = float(fx.get("dur", 5.0)) * (1.0 + c.stats.mult_sum("zone_duration"))
	c.match_ref.add_child(z)
	if String(fx.get("at", "target")) == "self":
		z.follow = c
	z.start(c, at, z.radius, dur, _zone_kind(fx, color))
	if c.stats.add_sum("skill_puddle_heal") > 0.0:
		z.heal_amount = maxf(z.heal_amount, c.stats.add_sum("skill_puddle_heal"))
		z.affects_allies = true


# ----------------------------------------------------------------- sprint

## A sprint skill: for `dur` seconds you run `speed` faster than a normal sprint, for free. Enemies you run into take `dmg` and the statuses once each,
## and you can leave a trail behind you (fire, slow...) with "trail".
static func _sprint(c: Combatant, skill: Dictionary, fx: Dictionary, own: bool, color: Color) -> void:
	var dur: float = float(fx.get("dur", 3.0))
	c.sprint_boost = 1.0 + float(fx.get("speed", 0.5))
	c.sprint_boost_left = dur
	c.stamina = 100.0
	c.set_meta("last_sprint", Time.get_ticks_msec() / 1000.0)
	var runner := SprintRunner.new()
	runner.c = c
	runner.time_left = dur
	runner.fx = fx
	runner.own = own
	runner.color = color
	runner.fire_dps = c.stats.add_sum("sprint_fire_dps")
	runner.arc_damage = c.stats.add_sum("sprint_lightning")
	c.match_ref.add_child(runner)
	Fx.ring(c.global_position, 1.6, color, 0.35)


class SprintRunner extends Node:
	var c: Combatant
	var time_left := 3.0
	var fx: Dictionary = {}
	var own := false
	var color := Color.WHITE
	var fire_dps := 0.0
	var arc_damage := 0.0
	var _hit: Dictionary = {}
	var _trail_t := 0.0
	var _drop_t := 0.0
	var _arc_t := 0.0

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(c) or c.dead or time_left <= 0.0:
			if is_instance_valid(c):
				c.sprint_boost_left = minf(c.sprint_boost_left, 0.0)
			queue_free()
			return
		time_left -= delta
		c.sprint_boost_left = maxf(c.sprint_boost_left, 0.05)
		_trail_t += delta
		if _trail_t > 0.06:
			_trail_t = 0.0
			Fx.impact(c.global_position + Vector3(0, 0.8, 0), color, false)
		if c.match_ref != null:
			for e in c.match_ref.enemies_of(c.team):
				if e.dead or _hit.has(e):
					continue
				if e.global_position.distance_to(c.global_position) < 1.8:
					_hit[e] = true
					if float(fx.get("dmg", 0.0)) > 0.0:
						c.deal(e, float(fx["dmg"]), {"magic": c.is_magic(), "skill": true, "own_class": own, "melee": true, "no_status": true})
					SkillRunner._apply_list(e, fx.get("sts", []), c)
					e.add_impulse((e.global_position - c.global_position).normalized() * 3.0)
		# a trail on the ground behind you
		var trail: Dictionary = fx.get("trail", {})
		_drop_t -= delta
		if (not trail.is_empty() or fire_dps > 0.0) and _drop_t <= 0.0 and c.is_on_floor():
			_drop_t = 0.28
			var z := Zone.new()
			z.dmg = float(trail.get("dmg", 0.0)) + fire_dps * 0.5
			z.sts = trail.get("sts", [{"id": "burn", "dur": 2.0}] if fire_dps > 0.0 else [])
			z.tick = 0.5
			c.match_ref.add_child(z)
			z.start(c, c.global_position, float(trail.get("radius", 1.6)), float(trail.get("dur", 2.5)), "fire" if fire_dps > 0.0 or trail.get("fire", false) else "ice")
		# lightning arcs to the nearest enemy while sprinting (card: Thunderstep)
		_arc_t -= delta
		if arc_damage > 0.0 and _arc_t <= 0.0:
			_arc_t = 0.8
			var t: Combatant = c.nearest_enemy(14.0)
			if t != null:
				Fx.lightning_strike(t.global_position)
				c.deal(t, arc_damage, {"magic": true, "skill": true, "no_status": true})


# ----------------------------------------------------------------- teleport

static func _teleport(c: Combatant, skill: Dictionary, fx: Dictionary, color: Color) -> void:
	var from := c.global_position
	c.set_meta("last_sprint", Time.get_ticks_msec() / 1000.0)
	var dest: Vector3
	if fx.get("behind", false):
		var e := c.nearest_enemy(40.0)
		if e != null:
			var back := -e.forward_vector()
			dest = e.global_position + back * 1.6
			c.face_toward(e.global_position - dest, true)
		else:
			dest = from + c.forward_vector() * float(fx.get("dist", 10.0))
	else:
		var dir := c.forward_vector() if c.wish_dir.length() < 0.1 else c.wish_dir.normalized()
		var dist: float = float(fx.get("dist", 10.0))
		var space := c.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 1, 0), from + Vector3(0, 1, 0) + dir * dist, 1)
		var hit := space.intersect_ray(q)
		dest = from + dir * (dist if hit.is_empty() else maxf(0.5, (hit["position"] - from - Vector3(0, 1, 0)).length() - 0.6))
	Fx.impact(from + Vector3(0, 1, 0), color, true)
	var space2 := c.get_world_3d().direct_space_state
	var down := space2.intersect_ray(PhysicsRayQueryParameters3D.create(dest + Vector3(0, 3, 0), dest - Vector3(0, 6, 0), 1))
	if not down.is_empty():
		dest.y = down["position"].y
	c.global_position = dest
	c.velocity = Vector3.ZERO
	Fx.impact(dest + Vector3(0, 1, 0), color, true)
	if fx.has("sts_self"):
		_apply_list(c, fx["sts_self"], c)
	if fx.has("leave_zone"):
		var lz: Dictionary = fx["leave_zone"]
		var z := Zone.new()
		z.dmg = float(lz.get("dmg", 5.0))
		z.sts = lz.get("sts", [])
		z.tick = 0.5
		c.match_ref.add_child(z)
		z.start(c, from, float(lz.get("radius", 2.0)), float(lz.get("dur", 2.0)), "storm")


# ----------------------------------------------------------------- leap with slam

static func _leap(c: Combatant, skill: Dictionary, fx: Dictionary, own: bool, color: Color) -> void:
	var dir := _aim_dir(c)
	dir.y = 0.0
	dir = dir.normalized()
	c.velocity.y = float(fx.get("up", 9.0)) * 0.9
	c.add_impulse(dir * float(fx.get("fwd", 10.0)) * 1.4)
	var runner := LeapRunner.new()
	runner.c = c
	runner.fx = fx
	runner.own = own
	runner.color = color
	c.match_ref.add_child(runner)


class LeapRunner extends Node:
	var c: Combatant
	var fx: Dictionary = {}
	var own := false
	var color := Color.WHITE
	var _t := 0.0

	func _physics_process(delta: float) -> void:
		_t += delta
		if not is_instance_valid(c) or c.dead or _t > 3.0:
			queue_free()
			return
		if _t > 0.25 and c.is_on_floor():
			var slam: Dictionary = fx.get("slam", {})
			var r: float = SkillRunner._radius(c, float(slam.get("radius", 5.0)))
			var f2 := {"dmg": float(slam.get("dmg", 40.0)), "sts": slam.get("sts", [])}
			SkillRunner._burst(c, c.global_position, r, f2, own, color)
			queue_free()


# ----------------------------------------------------------------- buff, heal, summon

static func _buff(c: Combatant, skill: Dictionary, fx: Dictionary, color: Color) -> void:
	var dur: float = float(fx.get("dur", 6.0))
	if fx.has("mods"):
		c.add_temp_mods("skill:" + String(skill["id"]), fx["mods"], dur)
	if fx.has("sts_self"):
		_apply_list(c, fx["sts_self"], c)
	if fx.has("on_hit"):
		c.add_temp_mods("onhit:" + String(skill["id"]), {"_on_hit": fx["on_hit"][0] if fx["on_hit"].size() > 0 else {}}, dur)
	if fx.has("reflect"):
		c.add_temp_mods("reflect:" + String(skill["id"]), {"reflect": {"add": float(fx["reflect"])}}, dur)
	if fx.has("mana"):
		c.restore_mana(float(fx["mana"]))
	if fx.has("reveal"):
		for e in c.match_ref.enemies_of(c.team):
			if e.global_position.distance_to(c.global_position) <= float(fx["reveal"]) and not e.dead:
				e.statuses.apply("marked", dur, 1, c)
	if fx.has("aura"):
		var a: Dictionary = fx["aura"]
		var z := Zone.new()
		z.sts = a.get("sts", [])
		z.tick = 0.5
		c.match_ref.add_child(z)
		z.follow = c
		z.start(c, c.global_position, float(a.get("radius", 4.0)), dur, "frost")
	Fx.ring(c.global_position, 2.2, color, 0.6)
	Fx.impact(c.global_position + Vector3(0, 1.0, 0), color, false)
	c.rebuild_stats()


static func _heal(c: Combatant, skill: Dictionary, fx: Dictionary, color: Color) -> void:
	var r := _radius(c, float(fx.get("radius", 0.0)))
	var amount: float = float(fx.get("amount", 30.0))
	var targets: Array = [c]
	if fx.get("allies", false) and r > 0.0:
		for a in c.match_ref.allies_of(c.team):
			if a != c and not a.dead and a.global_position.distance_to(c.global_position) <= r:
				targets.append(a)
	for t in targets:
		t.heal(amount * (1.0 + c.stats.mult_sum("spell_damage") * 0.5), c)
		if fx.has("regen"):
			t.statuses.apply("regen", float(fx["regen"]), 1, c)
		if fx.get("cleanse", false):
			t.statuses.cleanse()
		Fx.impact(t.global_position + Vector3(0, 1.0, 0), color, false)
	if fx.has("sts_self"):
		_apply_list(c, fx["sts_self"], c)
	Fx.ring(c.global_position, maxf(r, 2.0), color, 0.6)


static func _summon(c: Combatant, skill: Dictionary, fx: Dictionary, color: Color) -> void:
	var n: int = int(fx.get("count", 1))
	for i in n:
		var a := TAU * (float(i) + randf()) / maxf(n, 1)
		var pos := c.global_position + Vector3(cos(a), 0, sin(a)) * 2.0
		c.match_ref.spawn_minion(String(fx.get("what", "skeleton")), pos, c, float(fx.get("dur", 12.0)))
	Fx.ring(c.global_position, 3.0, color, 0.6)


# ----------------------------------------------------------------- wall, trap, strikes

static func _wall(c: Combatant, skill: Dictionary, fx: Dictionary, own: bool, color: Color) -> void:
	var at: Vector3 = _target_point(c, fx)
	var dir := _aim_dir(c)
	dir.y = 0.0
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var length: float = float(fx.get("len", 8.0))
	var height: float = float(fx.get("height", 3.0))
	var dur: float = float(fx.get("dur", 6.0))
	if fx.has("dmg"):
		var z := Zone.new()
		z.radius = 1.6
		z.line_len = length
		z.line_dir = side
		z.dmg = float(fx["dmg"])
		z.tick = float(fx.get("tick", 0.5))
		z.sts = fx.get("sts", [])
		z.own_class = own
		c.match_ref.add_child(z)
		z.start(c, at, 1.6, dur, "fire" if color.r > 0.8 else "arcane")
		for i in int(length / 1.5):
			var p := at + side * (-length * 0.5 + 1.5 * (i + 0.5))
			Fx.impact(p, color, false)
	else:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(length, height, 1.0)
		cs.shape = box
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = box.size
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color.r, color.g, color.b, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.15
		m.emission_enabled = true
		m.emission = color * 0.4
		mi.material_override = m
		body.add_child(mi)
		c.match_ref.add_child(body)
		body.global_position = at + Vector3(0, height * 0.5, 0)
		body.look_at(body.global_position + dir, Vector3.UP)
		Fx.impact(at, color, true)
		Util.after(c, dur, func() -> void:
			if is_instance_valid(body):
				Fx.impact(body.global_position, color, true)
				body.queue_free())


static func _trap(c: Combatant, skill: Dictionary, fx: Dictionary, own: bool, color: Color) -> void:
	var z := Zone.new()
	z.trap = true
	z.radius = _radius(c, float(fx.get("radius", 4.0)))
	z.trap_burst = float(fx.get("dmg", 30.0))
	z.sts = fx.get("sts", [])
	z.knock = float(fx.get("knock", 0.0))
	z.own_class = own
	c.match_ref.add_child(z)
	z.start(c, c.global_position + c.forward_vector() * 2.0, z.radius, float(fx.get("dur", 20.0)), "arcane" if color.b > color.r else "fire")


static func _strikes(c: Combatant, skill: Dictionary, fx: Dictionary, own: bool, color: Color) -> void:
	var center: Vector3 = _target_point(c, fx)
	var r := _radius(c, float(fx.get("radius", 8.0)))
	var count: int = int(fx.get("count", 5))
	var delay: float = float(fx.get("delay", 0.6))
	var storm := false
	for s in fx.get("sts", []):
		if String(s["id"]) == "shock":
			storm = true
	for i in count:
		var a := randf() * TAU
		var rr := sqrt(randf()) * r
		var p := center + Vector3(cos(a) * rr, 0, sin(a) * rr)
		Fx.telegraph(p, 2.0, color, delay + 0.08 * i)
		Util.after(c, delay + 0.08 * i, func() -> void:
			if not is_instance_valid(c):
				return
			if storm:
				Fx.lightning_strike(p)
			else:
				Fx.impact(p + Vector3(0, 0.3, 0), color, true)
				Fx.ring(p, 2.0, color, 0.3)
			for e in c.match_ref.enemies_of(c.team):
				if not e.dead and e.global_position.distance_to(p) <= 2.4:
					c.deal(e, float(fx.get("dmg", 20.0)), {"magic": true, "skill": true, "aoe": true, "own_class": own, "no_status": true})
					_apply_list(e, fx.get("sts", []), c))
