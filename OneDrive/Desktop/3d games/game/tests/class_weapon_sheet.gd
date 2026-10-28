extends Node3D
## All 12 classes with their own weapon in a chosen clip, to look for stretched bodies or weapons: godot --path game res://tests/class_weapon_sheet.tscn --resolution 2000x900 -- pose=Run frac=0.3 view=front|side out=name
var _t := 0.0
var _out := "class_weapon_sheet"
var _models: Array = []
var _pose := "Idle"
var _frac := 0.3
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = String(args.get("out", "class_weapon_sheet"))
	_pose = String(args.get("pose", "Idle"))
	_frac = float(args.get("frac", "0.3"))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 1.0)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	add_child(sun)
	var ids: Array = Data.class_order
	var spacing := 1.9
	for i in ids.size():
		var cls: String = ids[i]
		var m := CharacterModel.new()
		add_child(m)
		m.setup(cls, float(Data.classes[cls]["stats"]["size"]), "red", "", true)
		m.position = Vector3(float(i % 6) * spacing, -float(i / 6) * 2.5, 0)
		var wid := String(Data.classes[cls]["weapon"])
		if Data.weapons.has(wid):
			m.hold_weapon(Weapons.visual_for(Data.weapons[wid]))
		_models.append(m)
		var lab := Label3D.new()
		lab.text = cls
		lab.pixel_size = 0.0045
		lab.position = m.position + Vector3(0, -0.12, 0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		add_child(lab)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 30
	var cx := 2.5 * spacing
	var cy := 0.95 - 1.25
	var dist := 14.0
	match String(args.get("view", "front")):
		"side": cam.position = Vector3(cx + dist, cy, 0)
		_: cam.position = Vector3(cx, cy, -dist)
	cam.look_at(Vector3(cx, cy, 0))
func _process(d: float) -> void:
	_t += d
	for m in _models:
		var cm := m as CharacterModel
		if cm.anim != null and cm.anim.has_animation(_pose):
			cm.anim.play(_pose)
			cm.anim.seek(cm.anim.get_animation(_pose).length * _frac, true)
			cm.anim.pause()
	if _t > 3.0:
		get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % _out)
		print("CSHEET saved")
		get_tree().quit()
