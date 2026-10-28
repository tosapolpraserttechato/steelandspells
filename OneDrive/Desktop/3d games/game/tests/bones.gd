extends SceneTree
func _init() -> void:
	var packed: PackedScene = load("res://models/classes/class_druid.glb")
	var root := packed.instantiate()
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Skeleton3D:
			var names := []
			for i in range(n.get_bone_count()):
				names.append(n.get_bone_name(i))
			print("BONES ", names)
		print("NODE ", n.get_path(), " ", n.get_class())
		for c in n.get_children(): stack.append(c)
	quit()
