extends SceneTree
func _init() -> void:
	var bad := 0
	var dirs := ["res://scripts/autoload", "res://scripts/core", "res://scripts/world", "res://scripts/ui", "res://scripts/loot", "res://scripts"]
	for d in dirs:
		var da := DirAccess.open(d)
		if da == null: continue
		for f in da.get_files():
			if f.ends_with(".gd"):
				var path: String = d + "/" + f
				var res = load(path)
				if res == null:
					print("LOADFAIL ", path)
					bad += 1
	print("COMPILE_DONE bad=", bad)
	quit()
