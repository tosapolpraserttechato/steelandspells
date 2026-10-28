extends SceneTree
# godot --path game --resolution 1600x900 --script res://tests/feet_view.gd -- class_druid
var _t := 0.0
var _built := false
var _models: Array = []
func _build() -> void:
	_built = true
	var root := get_root()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.27, 0.35)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 1.0)
	e.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = e
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(3.6, 0.7, 3.2)
	cam.look_at(Vector3(3.6, 0.45, 0))
	cam.fov = 38
	var names: Array = OS.get_cmdline_user_args()
	if names.is_empty():
		names = ["druid", "sea_king", "flame_lord", "frost_mage", "thunder_god", "desert_assassin", "necromancer"]
	var i := 0
	for cls in names:
		var packed: PackedScene = load("res://models/classes/class_%s.glb" % cls)
		var m: Node3D = packed.instantiate()
		m.position = Vector3(i * 1.0, 0, 0)
		root.add_child(m)
		_models.append(m)
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("Idle")
		i += 1
	cam.position = Vector3((i - 1) * 0.5, 0.55, 3.0)
	cam.look_at(Vector3((i - 1) * 0.5, 0.4, 0))
	cam.fov = 40
func _process(delta: float) -> bool:
	if not _built:
		_build()
	_t += delta
	if _t > 1.5:
		get_root().get_texture().get_image().save_png("res://shots/feet.png")
		quit()
	return false
