extends SceneTree
## Prints the bounding box (x y z size, in the model's own units) of every Hunyuan weapon model: godot --headless --path game --script res://tests/hy_weapon_boxes.gd
func _init() -> void:
	for f in DirAccess.get_files_at("res://models/weapons/hy"):
		if not f.ends_with(".glb"):
			continue
		var node: Node3D = (load("res://models/weapons/hy/" + f) as PackedScene).instantiate()
		var box := AABB()
		var first := true
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var t := Transform3D.IDENTITY
			var cur: Node = m
			while cur != null and cur != node.get_parent():
				if cur is Node3D:
					t = (cur as Node3D).transform * t
				cur = cur.get_parent()
			var b := t * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
		print("BOX ", f, " ", box.size.snapped(Vector3(0.01, 0.01, 0.01)))
	quit()
