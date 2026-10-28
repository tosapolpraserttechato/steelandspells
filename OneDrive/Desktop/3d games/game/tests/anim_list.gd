extends SceneTree
func _init() -> void:
	var r = load("res://models/classes/class_druid.glb") if ResourceLoader.exists("res://models/classes/class_druid.glb") else null
	if r == null:
		var da := DirAccess.open("res://models/classes")
		for f in da.get_files():
			print("file ", f)
		quit()
		return
	var n: Node = r.instantiate()
	for p in n.find_children("*", "AnimationPlayer", true, false):
		var ap := p as AnimationPlayer
		var names := ap.get_animation_list()
		var out := PackedStringArray()
		for a in names:
			out.append("%s(%.2f)" % [a, ap.get_animation(a).length])
		print("ANIMS ", ", ".join(out))
	quit()
