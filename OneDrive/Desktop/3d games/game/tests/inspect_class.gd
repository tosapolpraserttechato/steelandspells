extends SceneTree

# godot --headless --path game --script res://tests/inspect_class.gd -- class_druid
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if args.size() > 0 else "class_druid"
	var packed: PackedScene = load("res://models/classes/%s.glb" % name)
	var root := packed.instantiate()
	var ap: AnimationPlayer = null
	var skel: Skeleton3D = null
	var meshes := 0
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is AnimationPlayer: ap = n
		if n is Skeleton3D: skel = n
		if n is MeshInstance3D: meshes += 1
		for c in n.get_children(): stack.append(c)
	print("ROOT ", root.name, " children ", root.get_child_count(), " meshes ", meshes)
	if skel: print("SKELETON bones ", skel.get_bone_count())
	if ap:
		print("ANIMS ", ap.get_animation_list())
		for a in ap.get_animation_list():
			print("  ", a, " ", ap.get_animation(a).length)
	var aabb := AABB()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		aabb = aabb.merge((n as MeshInstance3D).get_aabb())
	print("AABB ", aabb)
	quit()
