class_name GhostNode
extends Node3D
## A ghost released by a cursed grave: floats after the nearest living combatant and hurts it once on touch.

var match_ref: Match = null
var speed := 4.5
var dmg := 18.0
var _life := 20.0
var _fx: Node3D


func setup(ref: Match, spd: float, d: float) -> void:
	match_ref = ref
	speed = spd
	dmg = d
	_fx = Fx.status_effect("silence", 1.6)
	add_child(_fx)
	add_child(Fx.particles({"tex": "smoke", "amount": 14, "life": 1.2, "shape": "sphere", "radius": 0.3, "dir": Vector3.DOWN, "spread": 30, "vel": [0.2, 0.7], "size": [0.7, 1.2],
		"additive": false, "colors": [Color(0.7, 0.8, 1.0, 0), Color(0.7, 0.8, 1.0, 0.5), Color(0.5, 0.6, 0.9, 0)], "local": false}))
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.8, 1.0)
	l.light_energy = 1.2
	l.omni_range = 7.0
	add_child(l)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or match_ref == null:
		queue_free()
		return
	var best: Combatant = null
	var bd := 1e9
	for c in match_ref.combatants:
		if c.dead:
			continue
		var d: float = c.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = c
	if best == null:
		return
	var dir := (best.chest_position() - global_position).normalized()
	global_position += dir * speed * delta
	global_position.y += sin(Time.get_ticks_msec() / 300.0) * 0.01
	if bd < 1.1:
		best.take_damage(dmg, null, {"dot": "ghost", "no_status": true, "color": [0.7, 0.85, 1.0]})
		best.statuses.apply("slow", 2.0, 1, null)
		Fx.impact(global_position, Color(0.7, 0.85, 1.0), true)
		queue_free()
