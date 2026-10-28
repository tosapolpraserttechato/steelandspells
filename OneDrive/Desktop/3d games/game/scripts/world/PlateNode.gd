class_name PlateNode
extends Node3D
## A pressure plate (Desert Tomb): step on it and the gate it controls slides open (or closed again). It needs a few seconds to recharge.

var door: DoorNode = null
var radius := 1.7
var cooldown := 8.0
var match_ref: Match = null
var _cool := 0.0
var _inside := false
var _disc: MeshInstance3D
var _t := 0.0


func setup(marker: Dictionary, ref: Match) -> void:
	match_ref = ref
	position = marker["pos"]
	radius = float(marker.get("radius", 1.7))
	cooldown = float(marker.get("cooldown_seconds", 8.0))
	_disc = MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = 0.12
	_disc.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.7, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 0.6
	_disc.material_override = mat
	_disc.position = Vector3(0, 0.08, 0)
	add_child(_disc)
	add_child(Fx.hazard("moon_dust", radius * 0.8))


func tick(delta: float, combatants: Array) -> void:
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	var on := false
	for c in combatants:
		if not c.dead and Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z).length() < radius and absf(c.global_position.y - global_position.y) < 2.0:
			on = true
			break
	if on and not _inside and _cool <= 0.0 and door != null:
		door.toggle()
		_cool = cooldown
		match_ref.hud_toast("A gate %s" % ("opens" if door.is_open else "closes"), Color(1.0, 0.85, 0.5))
	_inside = on
	var charged := _cool <= 0.0
	(_disc.material_override as StandardMaterial3D).emission_energy_multiplier = (0.6 + 0.4 * sin(_t * 3.0)) if charged else 0.1
