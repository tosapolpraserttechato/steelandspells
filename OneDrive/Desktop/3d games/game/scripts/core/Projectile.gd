class_name Projectile
extends Node3D
## A flying bolt, arrow, orb or thrown weapon. Moves by hand (no physics body): each step it checks the segment it just flew
## against the world (ray) and against enemy combatants (distance to the segment). Splash, pierce, homing, pull, knockback, statuses.

var owner_c: Combatant = null
var dir := Vector3.FORWARD
var speed := 50.0
var dmg := 20.0
var splash := 0.0                    # explosion radius on impact (0 = direct hit only)
var hit_radius := 0.5
var life := 2.0
var pierce := false
var pierce_left := 0
var homing := 0.0
var sts: Array = []
var pull := 0.0
var knock := 0.0
var magic := false
var skill := false
var own_class := false
var ranged := true
var arc := false                     # thrown: falls with gravity
var color := Color(1, 0.9, 0.6)
var kind := "bolt"
var chain := 0
var match_ref: Match = null
var on_hit_cb: Callable = Callable()

var _vel := Vector3.ZERO
var _age := 0.0
var _hit: Dictionary = {}
var _visual: Node3D


func launch(c: Combatant, from: Vector3, direction: Vector3) -> void:
	owner_c = c
	match_ref = c.match_ref
	dir = direction.normalized()
	_vel = dir * speed
	_visual = Fx.projectile_visual(kind, color, 1.0 if splash <= 0.0 else 1.4)
	add_child(_visual)
	_world().add_child(self)
	global_position = from
	if kind == "arrow" or kind == "dart":
		look_at(from + dir, Vector3.UP)


func _world() -> Node:
	return match_ref if match_ref != null else owner_c.get_tree().current_scene


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > life:
		_explode(global_position, null)
		return
	if homing > 0.0:
		var tgt := _nearest_enemy(global_position, 25.0)
		if tgt != null:
			var want := (tgt.chest_position() - global_position).normalized()
			dir = dir.lerp(want, clampf(homing * delta, 0.0, 1.0)).normalized()
			_vel = dir * speed
	if arc:
		_vel.y -= 14.0 * delta
	var from := global_position
	var to := from + _vel * delta
	# world hit
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(q)
	var seg_end := to
	var world_hit := false
	if not hit.is_empty():
		seg_end = hit["position"]
		world_hit = true
	# enemy hit: nearest along the segment
	var best: Combatant = null
	var best_t := 2.0
	if match_ref != null:
		var seg := seg_end - from
		var seg_len2 := maxf(seg.length_squared(), 0.0001)
		for c in match_ref.combatants:
			if c.dead or c.team == owner_c.team or _hit.has(c):
				continue
			if not c.is_visible_to(owner_c) and not c.statuses.has("marked") and false:
				continue
			var p: Vector3 = c.chest_position()
			var t := clampf((p - from).dot(seg) / seg_len2, 0.0, 1.0)
			var closest := from + seg * t
			var r := hit_radius + 0.45 * float(c.stats.value("size", 1.0))
			if closest.distance_to(p) < r + 0.15 and closest.distance_to(c.global_position + Vector3(0, 0.5, 0)) < 1.6 + r and t < best_t:
				best = c
				best_t = t
	if best != null:
		var at := from + (seg_end - from) * best_t
		global_position = at
		_impact(at, best)
		return
	global_position = to
	if world_hit:
		global_position = seg_end
		_explode(seg_end, null)
		return
	if kind == "arrow" or kind == "dart":
		look_at(global_position + _vel, Vector3.UP)


func _nearest_enemy(pos: Vector3, within: float) -> Combatant:
	var best: Combatant = null
	var bd := within
	if match_ref == null:
		return null
	for c in match_ref.combatants:
		if c.dead or c.team == owner_c.team:
			continue
		var d: float = c.chest_position().distance_to(pos)
		if d < bd:
			bd = d
			best = c
	return best


func _impact(at: Vector3, victim: Combatant) -> void:
	if splash > 0.0:
		_explode(at, victim)
		return
	_hit[victim] = true
	_damage(victim)
	Fx.impact(at, color, false)
	if pierce and pierce_left > 0:
		pierce_left -= 1
		return
	if pierce and randf() < 0.0:
		return
	queue_free()


func _explode(at: Vector3, direct: Combatant) -> void:
	if splash > 0.0 and match_ref != null and owner_c != null:
		Fx.impact(at, color, true)
		Fx.ring(at, splash, color, 0.35)
		for c in match_ref.combatants:
			if c.dead or c.team == owner_c.team:
				continue
			if c.chest_position().distance_to(at) <= splash + 0.45:
				_damage(c)
	elif direct == null:
		Fx.impact(at, color, false)
	queue_free()


func _damage(victim: Combatant) -> void:
	if owner_c == null or not is_instance_valid(owner_c):
		return
	var info := {"magic": magic, "skill": skill, "own_class": own_class, "ranged": ranged, "aoe": splash > 0.0, "no_status": skill}
	owner_c.deal(victim, dmg, info)
	for s in sts:
		if randf() < float(s.get("p", 1.0)):
			victim.statuses.apply(String(s["id"]), float(s.get("dur", -1.0)), int(s.get("n", 1)), owner_c)
	if knock > 0.0:
		victim.add_impulse(dir * knock * 0.6 + Vector3(0, minf(knock * 0.12, 3.0), 0))
	if pull > 0.0:
		var d := owner_c.global_position - victim.global_position
		d.y = 0.0
		victim.add_impulse(d.normalized() * pull * 1.4)
	if on_hit_cb.is_valid():
		on_hit_cb.call(victim)
