extends SceneTree
## Lists the cloth bones (cape, skirt, hair...) of a class: chain, segment, rest position.  godot --headless --script res://tests/cape_probe.gd -- arcanist cape
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var cls: String = args[0] if args.size() > 0 else "arcanist"
	var prefix: String = "cloth_" + (args[1] if args.size() > 1 else "cape")
	var root: Node3D = (load("res://models/classes/class_%s.glb" % cls) as PackedScene).instantiate()
	get_root().add_child(root)
	var mi: MeshInstance3D = null
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			mi = m
	var skin: Skin = mi.skin
	var names := []
	for i in skin.get_bind_count():
		var nm := String(skin.get_bind_name(i))
		if nm.begins_with(prefix):
			var p := skin.get_bind_pose(i).affine_inverse().origin
			names.append("%s (%.2f %.2f %.2f)" % [nm, p.x, p.y, p.z])
	print("BONES ", cls, " ", names.size())
	for n in names:
		print("  ", n)
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	for i in skel.get_bone_count():
		var nm := skel.get_bone_name(i)
		if nm.begins_with(prefix) and nm.ends_with("_0"):
			print("  PARENT of ", nm, " = ", skel.get_bone_name(skel.get_bone_parent(i)) if skel.get_bone_parent(i) >= 0 else "-")
	quit()
