extends Node3D
## Every Hunyuan weapon (or a list: ids=a,b,c) held by one class, side by side: godot --path game res://tests/weapon_sheet.tscn --resolution 1800x600 -- class=arcanist ids=ember_staff,frost_staff view=front|3q|side out=name
var _t := 0.0
var _out := "weapon_sheet"
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = String(args.get("out", "weapon_sheet"))
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
	var ids: PackedStringArray
	if args.has("ids"):
		ids = String(args["ids"]).split(",")
	else:
		for f in DirAccess.get_files_at("res://models/weapons/hy"):
			if f.ends_with(".glb"):
				ids.append(f.trim_suffix(".glb"))
	var cls := String(args.get("class", "arcanist"))
	var spacing := 1.5
	for i in ids.size():
		var m := CharacterModel.new()
		add_child(m)
		m.setup(cls, float(Data.classes[cls]["stats"]["size"]), "red", "", true)
		m.position = Vector3(float(i % 6) * spacing, -float(i / 6) * 2.2, 0)
		m.hold_weapon(Weapons.visual_for(Data.weapons[ids[i]]))
		var lab := Label3D.new()
		lab.text = ids[i]
		lab.pixel_size = 0.004
		lab.position = m.position + Vector3(0, -0.12, 0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		add_child(lab)
	var cam := Camera3D.new()
	add_child(cam)
	var cols := mini(ids.size(), 6)
	var rows := (ids.size() + 5) / 6
	var cx := float(cols - 1) * spacing * 0.5
	var cy := 0.95 - float(rows - 1) * 1.1
	var dist := maxf(5.0, float(cols) * 1.7)
	cam.fov = 24
	match String(args.get("view", "3q")):
		"front": cam.position = Vector3(cx, cy, -dist)
		"side": cam.position = Vector3(cx + dist, cy, 0)
		_: cam.position = Vector3(cx - dist * 0.5, cy + 0.3, -dist * 0.85)
	cam.look_at(Vector3(cx, cy, 0))
func _process(d: float) -> void:
	_t += d
	if _t > 2.5:
		get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % _out)
		print("WSHEET saved")
		get_tree().quit()
