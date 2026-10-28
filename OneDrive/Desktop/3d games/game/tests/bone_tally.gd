extends SceneTree
func _init() -> void:
	var cls: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "necromancer"
	var root: Node3D = (load("res://models/classes/class_%s.glb" % cls) as PackedScene).instantiate()
	get_root().add_child(root)
	var mi: MeshInstance3D = null
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			mi = m
	var skin: Skin = mi.skin
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var counts := {}
	var ymin := {}
	var ymax := {}
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var bpv := bones.size() / verts.size()
		for v in verts.size():
			var best := -1.0
			var nm := ""
			for k in bpv:
				if weights[v * bpv + k] > best:
					best = weights[v * bpv + k]
					nm = String(skin.get_bind_name(bones[v * bpv + k]))
			var g := nm.substr(0, nm.find("_", 6)) if nm.begins_with("cloth_") else nm
			counts[g] = int(counts.get(g, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b) -> bool: return counts[a] > counts[b])
	var out := []
	for i in mini(24, keys.size()):
		out.append("%s:%d" % [keys[i], counts[keys[i]]])
	print("TALLY ", cls, " ", ", ".join(out))
	quit()
