class_name Zone
extends Node3D
## A lasting area on the ground made by a skill, hazard or item: ticks damage, statuses and healing on whoever stands in it.
## Also covers traps (hidden until an enemy steps in) and walls of fire. Removes itself when its time is up.

var owner_c: Combatant = null
var team := "red"
var radius := 5.0
var duration := 6.0
var tick := 1.0
var dmg := 0.0
var heal_amount := 0.0
var sts: Array = []                  # [{id, dur, n, p}]
var pull := 0.0
var knock := 0.0
var magic := true
var own_class := false
var kind := "arcane"                 # visual
var trap := false
var trap_burst := 0.0                # trap: damage of the burst when triggered
var affects_allies := false
var allies_only := false
var line_len := 0.0                  # >0 makes the zone a wall (line) of this length along `line_dir`
var line_dir := Vector3.RIGHT
var follow: Node3D = null
var match_ref: Match = null

var _age := 0.0
var _acc := 0.0
var _armed := true
var _fx: Node3D


func start(c: Combatant, pos: Vector3, r: float, dur: float, visual: String) -> void:
	owner_c = c
	team = c.team if c != null else "red"
	match_ref = c.match_ref if c != null else null
	radius = r
	duration = dur
	kind = visual
	global_position = pos
	if not trap:
		_fx = Fx.zone(pos, r, visual, dur)
	else:
		_fx = Fx.zone(pos, r * 0.4, visual, dur)       # a quiet marker only the owner's team really notices


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position
		if _fx != null:
			_fx.global_position = global_position
	_acc += delta
	if trap:
		_check_trap()
		return
	if _acc >= tick:
		_acc -= tick
		_apply()


func _members() -> Array[Combatant]:
	var out: Array[Combatant] = []
	if match_ref == null:
		return out
	for c in match_ref.combatants:
		if c.dead:
			continue
		if line_len > 0.0:
			var rel: Vector3 = c.global_position - global_position
			var along := rel.dot(line_dir)
			var side := (rel - line_dir * along).length()
			if absf(along) > line_len * 0.5 + 0.5 or side > radius:
				continue
		elif c.global_position.distance_to(global_position) > radius + 0.4:
			continue
		var enemy: bool = c.team != team
		if (enemy and not allies_only) or ((not enemy) and (affects_allies or allies_only)):
			out.append(c)
	return out


func _apply() -> void:
	for c in _members():
		var enemy: bool = c.team != team
		if enemy:
			if dmg > 0.0 and owner_c != null:
				owner_c.deal(c, dmg, {"magic": magic, "skill": true, "aoe": true, "own_class": own_class, "no_status": true})
			for s in sts:
				if randf() < float(s.get("p", 1.0)):
					c.statuses.apply(String(s["id"]), float(s.get("dur", -1.0)), int(s.get("n", 1)), owner_c)
			if pull > 0.0:
				var d := (global_position - c.global_position)
				d.y = 0.0
				c.add_impulse(d.normalized() * pull * 0.5)
		else:
			if heal_amount > 0.0:
				c.heal(heal_amount, owner_c)
			for s in sts:
				c.statuses.apply(String(s["id"]), float(s.get("dur", -1.0)), int(s.get("n", 1)), owner_c)


func _check_trap() -> void:
	if not _armed or match_ref == null:
		return
	for c in match_ref.combatants:
		if not c.dead and c.team != team and c.global_position.distance_to(global_position) < radius * 0.7:
			_armed = false
			Fx.impact(global_position + Vector3(0, 0.5, 0), Fx.zone_color(kind), true)
			Fx.ring(global_position, radius, Fx.zone_color(kind), 0.5)
			for t in match_ref.combatants:
				if not t.dead and t.team != team and t.global_position.distance_to(global_position) <= radius + 0.5:
					if trap_burst > 0.0 and owner_c != null:
						owner_c.deal(t, trap_burst, {"magic": magic, "skill": true, "aoe": true, "own_class": own_class, "no_status": true})
					for s in sts:
						t.statuses.apply(String(s["id"]), float(s.get("dur", -1.0)), int(s.get("n", 1)), owner_c)
					if knock > 0.0:
						var d: Vector3 = t.global_position - global_position
						d.y = 0.0
						t.add_impulse(d.normalized() * knock + Vector3(0, 4.0, 0))
			queue_free()
			return


func _exit_tree() -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_free()
