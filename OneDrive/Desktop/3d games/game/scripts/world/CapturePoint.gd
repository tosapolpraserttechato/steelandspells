class_name CapturePoint
extends Node3D
## A domination capture point: stand in the ring to take it. Progress runs from -1 (blue owns it) to +1 (red owns it).

signal captured(team: String, point: CapturePoint)
signal contested(point: CapturePoint)

var point_name := "A"
var radius := 8.0
var owner_team := ""                    # "", "red", "blue"
var progress := 0.0
var present_red := 0
var present_blue := 0
var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _label: Label3D
var _fill: MeshInstance3D


func setup(name_text: String, r: float) -> void:
	point_name = name_text
	radius = r
	_ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	_ring.mesh = q
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.albedo_texture = Fx.TEX["ring"]
	_mat.albedo_color = Color(0.9, 0.9, 0.9, 0.8)
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = _mat
	_ring.position = Vector3(0, 0.12, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.9
	cyl.height = 30.0
	_beam.mesh = cyl
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.albedo_color = Color(1, 1, 1, 0.14)
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = _beam_mat
	_beam.position = Vector3(0, 15.0, 0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_label = Label3D.new()
	_label.text = point_name
	_label.font_size = 96
	_label.pixel_size = 0.02
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.outline_size = 16
	_label.position = Vector3(0, 6.5, 0)
	add_child(_label)
	_paint()


func tick(delta: float, combatants: Array) -> void:
	present_red = 0
	present_blue = 0
	for c in combatants:
		if c.dead:
			continue
		var d: float = (c.global_position - global_position).length()
		if d <= radius:
			if c.team == "red":
				present_red += 1
			else:
				present_blue += 1
	var speed_mult := 1.0
	var dir := 0.0
	if present_red > 0 and present_blue == 0:
		dir = 1.0
	elif present_blue > 0 and present_red == 0:
		dir = -1.0
	elif present_red > 0 and present_blue > 0:
		contested.emit(self)
	if dir != 0.0:
		var n := present_red if dir > 0.0 else present_blue
		var before := progress
		progress = clampf(progress + dir * delta * 0.08 * (1.0 + 0.5 * (n - 1)) * speed_mult, -1.0, 1.0)
		if progress >= 1.0 and owner_team != "red":
			owner_team = "red"
			captured.emit("red", self)
		elif progress <= -1.0 and owner_team != "blue":
			owner_team = "blue"
			captured.emit("blue", self)
		elif owner_team == "red" and progress < 0.5 and dir < 0.0:
			owner_team = ""
		elif owner_team == "blue" and progress > -0.5 and dir > 0.0:
			owner_team = ""
		if before != progress:
			_paint()


func _paint() -> void:
	var c := Color(0.85, 0.85, 0.85)
	if progress > 0.02:
		c = Color(0.85, 0.85, 0.85).lerp(Color(1.0, 0.3, 0.25), clampf(progress, 0.0, 1.0))
	elif progress < -0.02:
		c = Color(0.85, 0.85, 0.85).lerp(Color(0.3, 0.55, 1.0), clampf(-progress, 0.0, 1.0))
	_mat.albedo_color = Color(c.r, c.g, c.b, 0.85)
	_beam_mat.albedo_color = Color(c.r, c.g, c.b, 0.16)
	_label.modulate = c
