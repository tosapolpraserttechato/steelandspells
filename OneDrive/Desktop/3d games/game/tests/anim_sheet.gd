extends SceneTree
# Contact sheet of the character clips: godot --path game --resolution 1800x1000 --script res://tests/anim_sheet.gd -- frac=0.5 out=anim_50
var _t := 0.0
var _built := false
var _players: Array = []
var _frac := 0.5
func _build() -> void:
	_built = true
	var out_frac := 0.5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frac="):
			_frac = float(a.substr(5))
	var root := get_root()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 1.0)
	e.ambient_light_energy = 0.9
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 20, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	var clips := ["Attack", "Block", "CastEnter", "CastExit", "CastIdle", "CastShoot", "ChestOpen", "Consume", "EmoteNo", "EmoteYes", "Hook", "JumpStart", "JumpLand", "MeleeA", "MeleeB", "MeleeC", "MeleeCombo", "Revive", "SlideStart", "Throw", "Knockback", "HitHead", "HitChest", "SlideExit"]
	var cols := 8
	var packed: PackedScene = load("res://models/classes/class_druid.glb")
	for i in clips.size():
		var m: Node3D = packed.instantiate()
		m.rotation.y = PI
		m.position = Vector3((i % cols) * 2.4, -(i / cols) * 2.6, 0)
		root.add_child(m)
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		_players.append([ap, clips[i]])
		var lab := Label3D.new()
		lab.text = clips[i]
		lab.pixel_size = 0.006
		lab.position = m.position + Vector3(0, -0.25, 0.1)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(lab)
	cam.position = Vector3(cols * 1.2 - 1.2, -2.2, 12.5)
	cam.fov = 38
func _process(delta: float) -> bool:
	if not _built:
		_build()
	_t += delta
	for pr in _players:
		var ap: AnimationPlayer = pr[0]
		var name: String = pr[1]
		if ap.has_animation(name):
			ap.play(name)
			ap.seek(ap.get_animation(name).length * _frac, true)
			ap.pause()
	if _t > 2.0:
		var out := "res://shots/anim_sheet.png"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("out="):
				out = "res://shots/%s.png" % a.substr(4)
		get_root().get_texture().get_image().save_png(out)
		quit()
	return false
