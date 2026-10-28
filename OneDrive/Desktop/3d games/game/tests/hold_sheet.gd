extends Node3D
## Characters holding weapons, seen from the side and the front, to check size and that nothing sticks into the body:
## godot --path game --resolution 1800x1000 res://tests/hold_sheet.tscn -- class=druid from=0 count=16 view=side out=hold_a
var _t := 0.0
var _out := "hold_a"

func _ready() -> void:
	var cls := "druid"
	var from := 0
	var count := 16
	var view := "side"
	var pose := "idle"
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"class": cls = kv[1]
				"from": from = int(kv[1])
				"count": count = int(kv[1])
				"view": view = kv[1]
				"out": _out = kv[1]
				"pose": pose = kv[1]
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
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	add_child(cam)
	# one weapon of every family, in order
	var seen := {}
	var picks: Array = []
	var all: Array = Data.weapons.values()
	for w in all:
		var fam: String = w["family"]
		if not seen.has(fam):
			seen[fam] = true
			picks.append(w)
	if from > 0 or count < picks.size():
		picks = picks.slice(from, from + count)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ids="):
			picks = []
			for id in a.substr(4).split(","):
				picks.append(Data.weapons[id])
	var cols := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cols="):
			cols = int(a.substr(5))
	for j in picks.size():
		var m := CharacterModel.new()
		add_child(m)
		m.setup(cls, 1.0, "red", "", true)
		m.hide_ring()
		m.position = Vector3((j % cols) * 2.8, -(j / cols) * 2.7, 0)
		m.hold_weapon(Weapons.visual_for(picks[j]))
		if pose == "run":
			m.play_state("run", true)
		var lab := Label3D.new()
		lab.text = "%s (%s)" % [picks[j]["id"], picks[j]["family"]]
		lab.pixel_size = 0.0055
		lab.position = m.position + Vector3(0, -0.25, 0.4)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(lab)
	var rows := int(ceil(float(picks.size()) / cols))
	var cx := (mini(cols, picks.size()) - 1) * 1.4
	var cy := -(rows - 1) * 1.35 + 0.9
	var dist := maxf(mini(cols, picks.size()) * 1.4 / 0.6, rows * 2.7 / 0.36) + 1.0
	match view:
		"side":
			cam.position = Vector3(cx + dist * 0.0, cy, dist)
			cam.rotation_degrees = Vector3(0, 0, 0)
			for ch in get_children():
				if ch is CharacterModel:
					ch.rotation.y = -PI * 0.5      # turn so the right side faces the camera
		"front":
			cam.position = Vector3(cx, cy, -dist)
			cam.rotation_degrees = Vector3(0, 180, 0)
		"back":
			cam.position = Vector3(cx, cy, dist)
		"top":
			cam.position = Vector3(cx, cy + dist * 0.8, dist * 0.3)
			cam.look_at(Vector3(cx, cy, 0))
	cam.fov = 38

func _process(delta: float) -> void:
	_t += delta
	if _t > 1.4:
		get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % _out)
		get_tree().quit()
