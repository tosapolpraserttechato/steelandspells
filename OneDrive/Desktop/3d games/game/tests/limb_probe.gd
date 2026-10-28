extends SceneTree
## How many vertices hang mostly from arm, hand, leg and foot bones, in the original mesh and the fixed one.  godot --headless --script res://tests/limb_probe.gd -- necromancer
func _init() -> void:
	var cls: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "necromancer"
	var root: Node3D = (load("res://models/classes/class_%s.glb" % cls) as PackedScene).instantiate()
	get_root().add_child(root)
	var mi: MeshInstance3D = null
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			mi = m
	var skin: Skin = mi.skin
	for label in ["orig", "fixed"]:
		var mesh: ArrayMesh = mi.mesh as ArrayMesh if label == "orig" else load("res://models/classes/fixed/%s_body.res" % cls)
		var counts := {}
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if bones.is_empty():
				continue
			var bpv := bones.size() / verts.size()
			for v in verts.size():
				var best := -1.0
				var nm := ""
				for k in bpv:
					if weights[v * bpv + k] > best:
						best = weights[v * bpv + k]
						nm = String(skin.get_bind_name(bones[v * bpv + k]))
				var group := "other"
				for g in ["upper_arm", "forearm", "hand", "thigh", "shin", "foot", "toe", "cloth_"]:
					if nm.contains(g):
						group = g
						break
				counts[group] = int(counts.get(group, 0)) + 1
		print("LIMBS ", cls, " ", label, " surfaces ", mesh.get_surface_count(), " ", counts)
	quit()
