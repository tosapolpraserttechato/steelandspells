extends SceneTree
## Lists the non-DEF bone name prefixes of every class model (cloth, hair, cape...): godot --headless --path game --script res://tests/bone_prefixes.gd
func _init() -> void:
	for f in DirAccess.get_files_at("res://models/classes"):
		if not f.ends_with(".glb"):
			continue
		var root: Node3D = (load("res://models/classes/" + f) as PackedScene).instantiate()
		var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
		var pre := {}
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			if not n.begins_with("DEF-") and n != "root":
				var p := n.get_slice("_", 0) + "_" + n.get_slice("_", 1)
				pre[p] = int(pre.get(p, 0)) + 1
		print("BONES ", f, " ", pre)
	quit()
