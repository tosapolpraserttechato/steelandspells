extends SceneTree
## Rocks side by side: the little procedural rocks (top two rows) and the rocks that the map files hold (bottom row, one per map).
##   godot --path game --resolution 1600x900 --script res://tests/rock_sheet.gd -- out=rocks
var _t := 0.0
var _built := false
const MAPS := ["flora_forest", "frozen_peaks", "pirate_cove", "volcano_forge", "desert_tomb", "clockwork_mines", "crystal_caves", "toxic_swamp"]


func _build() -> void:
	_built = true
	var root := get_root()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.7, 0.88)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.9)
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.42, 0.24)
	ground.material_override = gm
	ground.position = Vector3(8, 0, 4)
	root.add_child(ground)
	var kinds := ["rock", "rock_mossy", "rock_snowy", "boulder", "boulder_mossy", "boulder_snowy"]
	var cols := ["granite", "sandstone", "slate", "rust", "basalt", "pale"]
	for r in 2:
		for c in 6:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = DecorMesh.make(kinds[c], r * 3 + c % 3 + 1)
			mm.instance_count = 1
			var s := 3.0 if c < 3 else 1.6
			mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * s), Vector3(c * 2.6, 0, r * 2.6)))
			mm.set_instance_color(0, Color.WHITE)
			mm.set_instance_custom_data(0, Decor.PAL[cols[(c + r * 2) % cols.size()]].srgb_to_linear() * Color(1, 1, 1, 0) + Color(0, 0, 0, 0.4))
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = Decor._material(0.0)
			root.add_child(mi)
	var x := 0.0
	for m in MAPS:
		var scene: Node3D = (load("res://maps/%s/%s.glb" % [m, m]) as PackedScene).instantiate()
		var pick: MeshInstance3D = null
		for ch in scene.get_children():
			var n := String(ch.name)
			if ch is MeshInstance3D and (n.begins_with("rock") or n.begins_with("basalt") or n.begins_with("cm_ore_crag")) and not "lod" in n and not "face" in n and not "arch" in n:
				pick = ch
				break
		if pick == null:
			scene.free()
			continue
		var holder := Node3D.new()
		root.add_child(holder)
		var inst := MeshInstance3D.new()
		inst.mesh = pick.mesh
		holder.add_child(inst)
		var box := pick.mesh.get_aabb()
		var k := 2.2 / maxf(0.1, maxf(box.size.x, maxf(box.size.y, box.size.z)))
		holder.scale = Vector3.ONE * k
		holder.position = Vector3(x, -box.position.y * k, 6.0)
		x += 2.6
		var lab := Label3D.new()
		lab.text = "%s (%s)" % [m, pick.name]
		lab.position = Vector3(holder.position.x, 0.02, 7.6)
		lab.rotation_degrees = Vector3(-90, 0, 0)
		lab.pixel_size = 0.0045
		root.add_child(lab)
		scene.free()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 36
	cam.position = Vector3(8, 9.5, 17)
	cam.look_at(Vector3(8, 0.5, 3.5))


func _process(delta: float) -> bool:
	if not _built:
		_build()
	_t += delta
	if _t > 2.0:
		var out := "res://shots/rock_sheet.png"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("out="):
				out = "res://shots/%s.png" % a.substr(4)
		get_root().get_texture().get_image().save_png(out)
		quit()
	return false
