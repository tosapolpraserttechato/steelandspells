extends Node3D
## The six chests in a row (Chest.gd) from a chosen side, lid at a chosen angle: godot --path game res://tests/chest_sheet.tscn --resolution 1500x500 -- view=front|side|back|top|inside lid=60 near=1 out=chest_sheet
var _t := 0.0
var _args := {}
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_color = Color(0.2, 0.22, 0.3)
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.9)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	add_child(sun)
	var lid := float(_args.get("lid", "0"))
	for i in Data.rarity_ids.size():
		var c := Chest.make(Data.rarity_ids[i])
		c.position = Vector3(float(i) * 2.0, 0, 0)
		add_child(c)
		c.set_lid(lid)
	var cam := Camera3D.new()
	add_child(cam)
	var near := float(_args.get("near", "1"))
	var cx := 5.0
	match String(_args.get("view", "front")):
		"front": cam.position = Vector3(cx, 0.9, 4.5 * near)
		"side": cam.position = Vector3(cx + 7.0 * near, 0.7, 0.0)
		"back": cam.position = Vector3(cx, 0.9, -4.5 * near)
		"top": cam.position = Vector3(cx, 5.0 * near, 0.3)
		_: cam.position = Vector3(cx, 2.0, 2.5)
	cam.fov = 40
	cam.look_at(Vector3(cx, 0.3, 0))
func _process(delta: float) -> void:
	_t += delta
	if _t > 1.2:
		var out := "res://shots/%s.png" % String(_args.get("out", "chest_sheet"))
		get_viewport().get_texture().get_image().save_png(out)
		get_tree().quit()
