extends Node3D
## Every class at the moment of widest stride in several clips, to look for cloth that stretches:
## godot --path game --resolution 1800x1000 res://tests/stretch_sheet.tscn -- from=0 count=4 view=front out=stretch_a
var _t := 0.0
var _out := "stretch_a"
var _ready_done := false
var _ready_at := 0.0
var CLIPS: Array = ["Hook", "SlideStart", "JumpStart", "JumpLand", "MeleeA", "MeleeB", "MeleeC", "MeleeCombo", "Attack", "Knockback", "Throw", "Run"]

func _ready() -> void:
	var from := 0
	var count := 4
	var view := "front"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("clips="):
			CLIPS = a.substr(6).split(",")
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"from": from = int(kv[1])
				"count": count = int(kv[1])
				"view": view = kv[1]
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
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	add_child(cam)
	var classes: Array = Data.class_order.slice(from, from + count)
	for r in classes.size():
		for c in CLIPS.size():
			var m := CharacterModel.new()
			add_child(m)
			m.setup(classes[r], 1.0, "red", "", true)
			m.hide_ring()
			m.position = Vector3(c * 2.4, -r * 2.6, 0)
			if view == "side":
				m.rotation.y = -PI * 0.5
			var ap: AnimationPlayer = m.anim
			var clip: String = CLIPS[c]
			if ap.has_animation(clip):
				var sk := m.skeleton
				var fl := sk.find_bone("DEF-foot.L")
				var fr := sk.find_bone("DEF-foot.R")
				var best_t := 0.0
				var best_d := -1.0
				var len := ap.get_animation(clip).length
				ap.play(clip)
				ap.pause()
				for i in 16:
					var tt := len * float(i) / 15.0
					ap.seek(tt, true)
					await get_tree().process_frame
					var d := (sk.get_bone_global_pose(fl).origin - sk.get_bone_global_pose(fr).origin).length()
					if d > best_d:
						best_d = d
						best_t = tt
				ap.seek(best_t, true)
				await get_tree().process_frame
				ap.pause()
			if r == 0:
				var lab := Label3D.new()
				lab.text = clip
				lab.pixel_size = 0.006
				lab.position = m.position + Vector3(0, 2.3, 0)
				lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				add_child(lab)
	var cx := (CLIPS.size() - 1) * 1.2
	var cy := -(classes.size() - 1) * 1.3 + 0.9
	var dist := maxf(CLIPS.size() * 1.2 / 0.62, classes.size() * 2.6 / 0.36) + 1.5
	if view == "front":
		cam.position = Vector3(cx, cy, -dist)
		cam.rotation_degrees = Vector3(0, 180, 0)
	else:
		cam.position = Vector3(cx, cy, dist)
	cam.fov = 38
	for a in OS.get_cmdline_user_args():
		if a.begins_with("fov="):
			cam.fov = float(a.substr(4))
	_ready_at = _t
	_ready_done = true


func _process(delta: float) -> void:
	_t += delta
	if _ready_done and _t > _ready_at + 1.0:
		get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % _out)
		get_tree().quit()
