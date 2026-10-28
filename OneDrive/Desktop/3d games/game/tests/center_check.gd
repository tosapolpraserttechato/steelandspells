extends SceneTree
func _init() -> void:
	for cls in ["druid", "flame_lord", "pirate_captain", "gm_ravn", "desert_assassin", "sea_king"]:
		var path := "res://models/classes/class_%s.glb" % cls
		var n: Node3D = (load(path) as PackedScene).instantiate()
		root.add_child(n)
		var sk: Skeleton3D
		for s in n.find_children("*", "Skeleton3D", true, false):
			sk = s
		var hips := -1
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i).to_lower()
			if hips < 0 and (bn.contains("hips") or bn.contains("pelvis")):
				hips = i
		var box := AABB()
		var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			var b := n.global_transform.affine_inverse() * g.global_transform * g.get_aabb() if false else g.get_aabb()
			var t := g.global_transform
			var bb := t * b
			box = bb if first else box.merge(bb)
			first = false
		var hp := sk.global_transform * sk.get_bone_global_rest(hips).origin if hips >= 0 else Vector3.ZERO
		print("CENTER ", cls, " hips=", sk.get_bone_name(hips) if hips >= 0 else "none", " hips_pos=", hp, " aabb_center=", box.get_center(), " size=", box.size)
		n.queue_free()
	quit()
