extends SceneTree
## A picture of every decoration kind (flowers, grass, mushrooms, crystals, corals...): one row per kind, eight columns = four shapes x eight colours.
##   godot --path game --resolution 1600x1000 --script res://tests/decor_sheet.gd -- from=0 count=7 out=decor_a [glow=1.0]
var _t := 0.0
var _built := false
const COLS := ["red", "yellow", "blue", "pink", "white", "purple", "orange", "lime"]


func _build() -> void:
	_built = true
	var from := 0
	var count := 7
	var glow := 0.0
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"from": from = int(kv[1])
				"count": count = int(kv[1])
				"glow": glow = float(kv[1])
	var root := get_root()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.62, 0.8)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.9)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.24, 0.3, 0.2)
	ground.material_override = gm
	ground.position = Vector3(3.5, 0, 3)
	root.add_child(ground)
	var kinds: Array = DecorMesh.KINDS.slice(from, from + count)
	for r in kinds.size():
		for c in 8:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = DecorMesh.make(kinds[r], c % 4 + 1)
			mm.instance_count = 1
			mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * 1.8), Vector3(c * 1.1, 0, r * 1.2)))
			mm.set_instance_color(0, Color.WHITE)
			mm.set_instance_custom_data(0, Color(Decor.PAL[COLS[c]]).srgb_to_linear() * Color(1, 1, 1, 0) + Color(0, 0, 0, 0.37 + 0.07 * c))
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = Decor._material(glow)
			root.add_child(mi)
		var lab := Label3D.new()
		lab.text = kinds[r]
		lab.position = Vector3(-1.4, 0.05, r * 1.2)
		lab.rotation_degrees = Vector3(-90, 0, 0)
		lab.pixel_size = 0.008
		root.add_child(lab)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 38
	var mid := Vector3(3.5, 0.2, (kinds.size() - 1) * 0.6)
	cam.position = mid + Vector3(0, 7.0, 7.5 + kinds.size() * 0.5)
	cam.look_at(mid)


func _process(delta: float) -> bool:
	if not _built:
		_build()
	_t += delta
	if _t > 2.0:
		var out := "res://shots/decor_sheet.png"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("out="):
				out = "res://shots/%s.png" % a.substr(4)
		get_root().get_texture().get_image().save_png(out)
		quit()
	return false
