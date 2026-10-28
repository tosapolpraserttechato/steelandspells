extends SceneTree
var _t := 0.0
var _built := false
func _build() -> void:
	_built = true
	var root := get_root()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.27, 0.35)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 1.0)
	root.add_child(WorldEnvironment.new())
	(root.get_child(root.get_child_count() - 1) as WorldEnvironment).environment = e
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	var i := 0
	for cls in ["flame_lord", "thunder_god", "desert_assassin"]:
		var rigged: Node3D = (load("res://models/classes/class_%s.glb" % cls) as PackedScene).instantiate()
		rigged.position = Vector3(i * 2.2, 0, 0)
		root.add_child(rigged)
		var ap: AnimationPlayer = rigged.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("Idle")
		var st: Node3D = (load("res://models/static_test/class_%s.glb" % cls) as PackedScene).instantiate()
		st.position = Vector3(i * 2.2 + 1.1, 0, 0)
		root.add_child(st)
		var box := AABB()
		for mi in st.find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			var b := st.global_transform.affine_inverse() * g.global_transform * g.get_aabb()
			box = b if box.size == Vector3.ZERO else box.merge(b)
		print("STATIC ", cls, " aabb ", box)
		var box2 := AABB()
		for mi in rigged.find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			box2 = g.get_aabb()
		print("RIGGED ", cls, " aabb ", box2)
		i += 1
	cam.position = Vector3(2.4, 0.5, 3.0)
	cam.look_at(Vector3(2.4, 0.4, 0))
	cam.fov = 40
func _process(delta: float) -> bool:
	if not _built:
		_build()
	_t += delta
	if _t > 1.5:
		get_root().get_texture().get_image().save_png("res://shots/feet_compare.png")
		quit()
	return false
