extends SceneTree
## A picture of every little animal in every colour scheme (one row per animal, enlarged).
##   godot --path game --resolution 1600x1000 --script res://tests/critter_sheet.gd -- from=0 count=7 out=critters_a
var _t := 0.0
var _built := false


func _build() -> void:
	_built = true
	var from := 0
	var count := 7
	var zoom := 2.4
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"from": from = int(kv[1])
				"count": count = int(kv[1])
				"zoom": zoom = float(kv[1])
	var root := get_root()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.62, 0.8)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.9)
	e.ambient_light_energy = 0.75
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
	gm.albedo_color = Color(0.3, 0.36, 0.26)
	ground.material_override = gm
	ground.position = Vector3(3, 0, 3)
	root.add_child(ground)
	var kinds: Array = CritterMesh.KINDS.slice(from, from + count)
	for r in kinds.size():
		for v in 5:
			var parts := CritterMesh.parts(kinds[r], v)
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 0.85
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			var g: Color = parts["glow"]
			if g.r + g.g + g.b > 0.01:
				mat.emission_enabled = true
				mat.emission = g
			var holder := Node3D.new()
			holder.position = Vector3(v * 1.4, 0.6 if kinds[r] in ["butterfly", "dragonfly", "bird", "bat", "fish", "jellyfish"] else 0.0, r * 1.5)
			holder.rotation.y = 0.6
			holder.scale = Vector3.ONE * float(parts["scale"]) * zoom
			root.add_child(holder)
			var mi := MeshInstance3D.new()
			mi.mesh = parts["body"]
			mi.material_override = mat
			holder.add_child(mi)
			if parts.has("wing"):
				for s in [1.0, -1.0]:
					var pivot := Node3D.new()
					var at: Vector3 = parts["wing_at"]
					pivot.position = Vector3(at.x * s, at.y, at.z)
					pivot.scale = Vector3(s, 1, 1)
					pivot.rotation.z = 0.35
					var wm := MeshInstance3D.new()
					wm.mesh = parts["wing"]
					wm.material_override = mat
					pivot.add_child(wm)
					holder.add_child(pivot)
			if parts.has("tail"):
				var tm := MeshInstance3D.new()
				tm.mesh = parts["tail"]
				tm.material_override = mat
				tm.position = parts["tail_at"]
				holder.add_child(tm)
		var lab := Label3D.new()
		lab.text = kinds[r]
		lab.position = Vector3(-1.6, 0.05, r * 1.5)
		lab.rotation_degrees = Vector3(-90, 0, 0)
		lab.pixel_size = 0.009
		root.add_child(lab)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 38
	var mid := Vector3(2.6, 0.3, (kinds.size() - 1) * 0.75)
	cam.position = mid + Vector3(0, 6.5, 6.0 + kinds.size() * 0.85)
	cam.look_at(mid)


func _process(delta: float) -> bool:
	if not _built:
		_build()
	_t += delta
	if _t > 2.0:
		var out := "res://shots/critter_sheet.png"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("out="):
				out = "res://shots/%s.png" % a.substr(4)
		get_root().get_texture().get_image().save_png(out)
		quit()
	return false
