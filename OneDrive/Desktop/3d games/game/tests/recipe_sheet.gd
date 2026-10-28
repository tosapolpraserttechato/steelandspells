extends Node3D
## Plays every animation recipe on its own character and takes pictures at two moments:
## godot --path game --resolution 1800x1000 res://tests/recipe_sheet.tscn -- from=0 count=24 at=0.45 out=recipes_a
var _t := 0.0
var _at := 0.45
var _out := "recipes_a"
var _models: Array = []
var _names: Array = []

func _ready() -> void:
	var from := 0
	var count := 24
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"from": from = int(kv[1])
				"count": count = int(kv[1])
				"at": _at = float(kv[1])
				"out": _out = kv[1]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 1.0)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 20, 0)
	add_child(sun)
	var cam := Camera3D.new()
	add_child(cam)
	var keys: Array = AnimRecipes.R.keys()
	var cols := 8
	var n := mini(count, keys.size() - from)
	for j in n:
		var m := CharacterModel.new()
		add_child(m)
		m.setup("druid", 1.0, "red", "", true)
		m.hide_ring()
		m.position = Vector3((j % cols) * 2.6, -(j / cols) * 2.7, 0)
		m.rotation.y = -0.5
		_models.append(m)
		_names.append(keys[from + j])
		var lab := Label3D.new()
		lab.text = String(keys[from + j])
		lab.pixel_size = 0.006
		lab.position = m.position + Vector3(0, -0.25, 0.3)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(lab)
	var rows := int(ceil(float(n) / cols))
	cam.position = Vector3(cols * 1.3 - 1.3, -(rows - 1) * 1.35 + 0.9, maxf(cols * 1.3 / 0.6, rows * 2.7 / 0.36) + 1.0)
	cam.fov = 38
	await get_tree().process_frame
	await get_tree().process_frame
	for j in _models.size():
		var r: Dictionary = AnimRecipes.R[_names[j]]
		(_models[j] as CharacterModel).play_recipe(r["c"], r["p"], Color(0.4, 0.8, 1.0), int(r.get("g", 0)))

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.6 + _at:
		get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % _out)
		get_tree().quit()
