extends SceneTree
func _init() -> void:
	var root: Node3D = (load("res://models/classes/class_frost_mage.glb") as PackedScene).instantiate()
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var out := []
	for i in sk.get_bone_count():
		var p := sk.get_bone_parent(i)
		out.append("%s<-%s %s" % [sk.get_bone_name(i), sk.get_bone_name(p) if p >= 0 else "-", sk.get_bone_global_rest(i).origin.snappedf(0.01)])
	print("BONES\n", "\n".join(out))
	quit()
