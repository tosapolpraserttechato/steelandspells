extends Node3D
## Contact sheet of armor sets on a class model, to check the fit and the look. Run as a normal scene (the autoloads are needed):
##   godot --path game res://tests/armor_sheet.tscn --resolution 1800x900 -- class=druid sets=set_01_squire_s_plate,set_02_knight_s_bastion view=front out=armor_sheet
## args: class (one class id, or several separated by commas: one row each), sets (set ids, one column each), view=front|side|back|3q, only=helmet,chestplate (wear only these slots), pose=Idle|Run|MeleeA|CastEnter...,
##       frac (how far into the pose, 0..1), out (file name in shots/), weapon=<weapon id> (hold it too), skin=<armor skin id>.
var _t := 0.0
var _args := {}
var _models: Array = []
var _pose := "Idle"
var _frac := 0.4


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_pose = String(_args.get("pose", "Idle"))
	_frac = float(_args.get("frac", "0.4"))
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
	sun.light_energy = 1.3
	add_child(sun)
	var classes: PackedStringArray = String(_args.get("class", "druid")).split(",")
	var sets: PackedStringArray = String(_args.get("sets", Data.armor_order[0])).split(",")
	var only: PackedStringArray = String(_args.get("only", "helmet,chestplate,shield,leggings,boots")).split(",")
	var spacing := 1.9
	var transpose := sets.size() == 1 and classes.size() > 1                 # one set on many classes: the classes go across
	var cols := classes.size() if transpose else sets.size()
	var rows := 1 if transpose else classes.size()
	for r in classes.size():
		for c in sets.size():
			var m := CharacterModel.new()
			add_child(m)
			var cd: Dictionary = Data.classes[classes[r]]
			m.setup(classes[r], float(cd["stats"]["size"]), "red", "", true)
			m.position = Vector3(float(r if transpose else c) * spacing, -float(0 if transpose else r) * 2.4, 0)
			var pieces := {}
			if sets[c] != "none":
				for slot in only:
					pieces[slot] = sets[c]
			m.dress(pieces)
			if _args.has("weapon"):
				m.hold_weapon(Weapons.visual_for(Data.weapons[String(_args["weapon"])]))
			_models.append(m)
			var lab := Label3D.new()
			lab.text = String(Data.armor_sets[sets[c]]["name"]) if Data.armor_sets.has(sets[c]) else sets[c]
			lab.pixel_size = 0.0045
			lab.position = m.position + Vector3(0, -0.12, 0)
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.no_depth_test = true
			add_child(lab)
	var cam := Camera3D.new()
	add_child(cam)
	var cx := float(cols - 1) * spacing * 0.5
	var cy := 0.95 - float(rows - 1) * 1.2
	var dist := maxf(4.2, float(cols) * 1.35 + float(rows) * 0.9)
	cam.fov = 34
	match String(_args.get("view", "front")):
		"front": cam.position = Vector3(cx, cy, -dist)
		"back": cam.position = Vector3(cx, cy, dist)
		"side": cam.position = Vector3(cx + dist, cy, 0)
		_: cam.position = Vector3(cx - dist * 0.55, cy + 0.4, -dist * 0.85)
	cam.look_at(Vector3(cx, cy, 0))


func _process(delta: float) -> void:
	_t += delta
	for m in _models:
		var cm := m as CharacterModel
		if cm.anim != null and cm.anim.has_animation(_pose):
			cm.set_process(false)                              # the model's own state machine would put it back to Idle
			cm.set_physics_process(false)
			cm.anim.play(_pose, 0.0)                           # no blend from Idle: a paused player would stay mostly in Idle
			cm.anim.seek(cm.anim.get_animation(_pose).length * _frac, true)
			cm.anim.pause()
	if _t > 2.5:
		var out := "res://shots/%s.png" % String(_args.get("out", "armor_sheet"))
		get_viewport().get_texture().get_image().save_png(out)
		print("SHEET saved ", out)
		get_tree().quit()
