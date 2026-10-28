extends SceneTree
## For a class: how many vertices lie near each limb bone segment, and which bones they hang from now.  godot --headless --script res://tests/limb_geom.gd -- necromancer
func _init() -> void:
	var cls: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "necromancer"
	var root: Node3D = (load("res://models/classes/class_%s.glb" % cls) as PackedScene).instantiate()
	get_root().add_child(root)
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = null
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			mi = m
	var skin: Skin = mi.skin
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var bpv := bones.size() / verts.size()
	var pos := {}
	for i in skin.get_bind_count():
		pos[String(skin.get_bind_name(i))] = skin.get_bind_pose(i).affine_inverse().origin
	var segs := {"upper_arm.L": ["DEF-upper_arm.L", "DEF-forearm.L"], "forearm.L": ["DEF-forearm.L", "DEF-hand.L"], "thigh.R": ["DEF-thigh.R", "DEF-shin.R"], "shin.R": ["DEF-shin.R", "DEF-foot.R"],
		"thigh.L": ["DEF-thigh.L", "DEF-shin.L"], "shin.L": ["DEF-shin.L", "DEF-foot.L"], "upper_arm.R": ["DEF-upper_arm.R", "DEF-forearm.R"], "forearm.R": ["DEF-forearm.R", "DEF-hand.R"]}
	for s in segs:
		var a: Vector3 = pos.get(segs[s][0], Vector3.ZERO)
		var b: Vector3 = pos.get(segs[s][1], Vector3.ZERO)
		var near := 0
		var tally := {}
		for v in verts.size():
			var ab := b - a
			var t := clampf((verts[v] - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if verts[v].distance_to(a + ab * t) < 0.09:
				near += 1
				var best := -1.0
				var nm := ""
				for k in bpv:
					if weights[v * bpv + k] > best:
						best = weights[v * bpv + k]
						nm = String(skin.get_bind_name(bones[v * bpv + k]))
				tally[nm] = int(tally.get(nm, 0)) + 1
		print("GEOM ", cls, " ", s, " bone ", snappedf(a.distance_to(b), 0.01), " m, vertices within 9 cm: ", near, " ", tally)
	quit()
