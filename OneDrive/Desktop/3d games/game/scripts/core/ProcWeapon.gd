class_name ProcWeapon
extends RefCounted
## Weapons that have no model in the free packs are built here from simple shapes. `make(id)` returns a Node3D standing upright (long axis Y, the grip near the
## bottom), or null when the weapon uses a pack model. GM Ravn's staff: an ebony shaft with gold rings, topped with an ivory chess king.


static func make(id: String) -> Node3D:
	match id:
		"chess_staff": return _chess_staff()
	return null


static func _mat(col: Color, metal: float = 0.0, rough: float = 0.5, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


## A shape of revolution around Y from a profile of (radius, height) points.
static func _lathe(profile: Array, sides: int = 18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		for k in sides:
			var t0 := TAU * k / sides
			var t1 := TAU * (k + 1) / sides
			var p00 := Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x)
			var p01 := Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x)
			var p10 := Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)
			var p11 := Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x)
			for p in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


static func _chess_staff() -> Node3D:
	var root := Node3D.new()
	var ebony := _mat(Color(0.1, 0.09, 0.11), 0.2, 0.35)
	var gold := _mat(Color(1.0, 0.82, 0.35), 0.8, 0.28, 0.25)
	var ivory := _mat(Color(0.96, 0.93, 0.84), 0.0, 0.45)
	# the shaft with a few gold rings and a pointed foot
	var shaft := MeshInstance3D.new()
	shaft.mesh = _lathe([Vector2(0.0, 0.0), Vector2(0.014, 0.02), Vector2(0.02, 0.1), Vector2(0.02, 1.15), Vector2(0.026, 1.2)], 12)
	shaft.material_override = ebony
	root.add_child(shaft)
	for y in [0.38, 0.7, 1.12]:
		var ring := MeshInstance3D.new()
		ring.mesh = _lathe([Vector2(0.021, y - 0.012), Vector2(0.03, y - 0.008), Vector2(0.03, y + 0.008), Vector2(0.021, y + 0.012)], 14)
		ring.material_override = gold
		root.add_child(ring)
	# the king: a stepped, rounded piece (a base, a waist, a collar, a crown) with a small gold cross
	var king := MeshInstance3D.new()
	king.mesh = _lathe([Vector2(0.0, 1.2), Vector2(0.075, 1.2), Vector2(0.078, 1.225), Vector2(0.05, 1.25), Vector2(0.034, 1.33), Vector2(0.04, 1.36), Vector2(0.06, 1.38),
		Vector2(0.062, 1.405), Vector2(0.05, 1.425), Vector2(0.056, 1.46), Vector2(0.06, 1.5), Vector2(0.048, 1.54), Vector2(0.0, 1.55)], 22)
	king.material_override = ivory
	root.add_child(king)
	var collar := MeshInstance3D.new()
	collar.mesh = _lathe([Vector2(0.05, 1.352), Vector2(0.066, 1.358), Vector2(0.066, 1.374), Vector2(0.05, 1.38)], 18)
	collar.material_override = gold
	root.add_child(collar)
	for dims in [Vector3(0.016, 0.1, 0.016), Vector3(0.06, 0.016, 0.016)]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = dims
		bar.mesh = bm
		bar.position = Vector3(0, 1.6 if dims.y > 0.05 else 1.615, 0)
		bar.material_override = gold
		root.add_child(bar)
	return root
