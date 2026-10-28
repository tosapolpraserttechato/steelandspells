extends SceneTree
## Prints every bone of a class model with its rest position (model space) and which bones carry skin weight. M=<class id>
func _init() -> void:
	var root: Node3D = (load("res://models/classes/class_%s.glb" % OS.get_environment("M")) as PackedScene).instantiate()
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var out := []
	for i in sk.get_bone_count():
		var p := sk.get_bone_parent(i)
		out.append("%s<-%s %s" % [sk.get_bone_name(i), sk.get_bone_name(p) if p >= 0 else "-", sk.get_bone_global_rest(i).origin.snappedf(0.01)])
	print("BONES\n", "\n".join(out))
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	print("MESH aabb ", mi.get_aabb(), " skin binds ", mi.skin.get_bind_count() if mi.skin else -1)
	quit()
