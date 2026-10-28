extends SceneTree
## Removes the triangles of a class body that are pulled into long slivers while running (the stretched spikes at the hem of a cape or skirt). Poses the body in the way the game does
## (ClothDamp on Run / Sprint), measures every triangle edge against its rest length and drops the triangles whose worst edge grows by more than RATIO times AND more than EXTRA metres in any
## probed pose. Works on models/classes/fixed/<class>_body.res (or the glb mesh when there is none) and writes it back; the original is kept as <class>_body.res.pre_cull.
##   godot --headless --path game --script res://tools/cull_stretch.gd -- arcanist frost_mage time_mage sea_king [ratio=2.6] [extra=0.09]
const CLIPS := {"Run": 10, "Sprint": 10, "SlideLoop": 3, "JumpLoop": 3, "CastIdle": 2}
var ratio := 2.6
var extra := 0.09


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var classes: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ratio="):
			ratio = float(a.substr(6))
		elif a.begins_with("extra="):
			extra = float(a.substr(6))
		else:
			classes.append(a)
	for cls in classes:
		await _cull(cls)
	quit()


func _cull(cls: String) -> void:
	var root: Node3D = (load("res://models/classes/class_%s.glb" % cls) as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	var mi: MeshInstance3D = null
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			mi = m
	var skin: Skin = mi.skin
	var cfg := {}                                                           # the poses the game shows: the class's run_calm setting
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json")):
		if c["id"] == cls:
			cfg = c.get("run_calm", {})
	ClothDamp.apply(skel, ap, cfg)
	var fixed_path := "res://models/classes/fixed/%s_body.res" % cls
	var mesh: ArrayMesh = (load(fixed_path) if ResourceLoader.exists(fixed_path) else mi.mesh) as ArrayMesh
	var poses: Array = []
	for clip in CLIPS:
		if not ap.has_animation(clip):
			continue
		ap.play(clip)
		ap.pause()
		var length := ap.get_animation(clip).length
		for i in int(CLIPS[clip]):
			ap.seek(length * (float(i) + 0.5) / float(CLIPS[clip]), true)
			await process_frame
			var mats: Array = []
			for b in skin.get_bind_count():
				var bi := skel.find_bone(skin.get_bind_name(b))
				mats.append(skel.get_bone_global_pose(bi) * skin.get_bind_pose(b))
			poses.append(mats)
	var out := ArrayMesh.new()
	var removed := 0
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var fmt := mesh.surface_get_format(s)
		if bones.is_empty() or idx.is_empty():
			out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, [], {}, fmt)
			out.surface_set_material(s, mesh.surface_get_material(s))
			continue
		var n := verts.size()
		var bpv := bones.size() / n
		var posed: Array = []
		for mats in poses:
			var arr := PackedVector3Array()
			arr.resize(n)
			for v in n:
				var r := Vector3.ZERO
				for k in bpv:
					var w := weights[v * bpv + k]
					if w > 0.0:
						r += (mats[bones[v * bpv + k]] as Transform3D) * verts[v] * w
				arr[v] = r
			posed.append(arr)
		var kept := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			total += 1
			var bad := false
			for e in 3:
				var a := idx[t + e]
				var b := idx[t + (e + 1) % 3]
				var rest := verts[a].distance_to(verts[b])
				if rest < 0.004:
					continue
				for pa in posed:
					var d := (pa[a] as Vector3).distance_to(pa[b])
					if d / rest > ratio and d - rest > extra:
						bad = true
						break
				if bad:
					break
			if bad:
				removed += 1
			else:
				kept.append(idx[t])
				kept.append(idx[t + 1])
				kept.append(idx[t + 2])
		arrays[Mesh.ARRAY_INDEX] = kept
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, [], {}, fmt)
		out.surface_set_material(s, mesh.surface_get_material(s))
	if ResourceLoader.exists(fixed_path) and not FileAccess.file_exists(ProjectSettings.globalize_path(fixed_path) + ".pre_cull"):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(fixed_path), ProjectSettings.globalize_path(fixed_path) + ".pre_cull")
	var err := ResourceSaver.save(out, fixed_path)
	print("CULLED ", cls, " removed ", removed, " of ", total, " triangles (ratio ", ratio, ", extra ", extra, ") save ", err)
	root.queue_free()
