extends Control
## Contact sheet of skill buttons: godot --path game --resolution 1700x1000 res://tests/skill_sheet.tscn [-- from=0 count=156 size=80 out=skill_sheet]
var _t := 0.0
var _out := "skill_sheet"

func _ready() -> void:
	var from := 0
	var count := 156
	var sz := 80.0
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"from": from = int(kv[1])
				"count": count = int(kv[1])
				"size": sz = float(kv[1])
				"out": _out = kv[1]
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.18)
	bg.size = Vector2(1700, 1000)
	add_child(bg)
	var skills: Array = Data.skills.values()
	var gap := sz * 0.16
	var cols := int(1700.0 / (sz + gap))
	for j in mini(count, skills.size() - from):
		var i := from + j
		var sk: Dictionary = skills[i]
		var w := UiKit.SkillSlot.new()
		w.skill = sk
		w.size = Vector2(sz, sz)
		w.position = Vector2(8 + (j % cols) * (sz + gap), 8 + (j / cols) * (sz + gap + 12))
		w.letter = "Q"
		w.ready_glow = (i % 5 == 0)
		w.special = (i % 12 == 5)
		if i % 17 == 3 and sz < 120:
			w.cooldown = 4.0
			w.cooldown_total = 10.0
		add_child(w)
	print("SHEET skills=", skills.size())

func _process(delta: float) -> void:
	_t += delta
	if _t > 1.5:
		get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % _out)
		get_tree().quit()
