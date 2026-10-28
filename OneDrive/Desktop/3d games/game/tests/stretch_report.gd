extends SceneTree
## Numbers instead of pictures: for every class and some clips (default Run, Sprint, Idle) the worst a mesh edge stretches, with the bones of the stretched spot.
##   godot --headless --path game --script res://tests/stretch_report.gd -- [clips=Run,Sprint] [classes=druid,time_mage] [orig=1]
const CLASSES := ["druid", "sea_king", "flame_lord", "frost_mage", "thunder_god", "desert_assassin", "necromancer", "arcanist", "poison_brewer", "pirate_captain", "time_mage", "celestial_mage", "gm_ravn"]
const SAMPLES := 10


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var clips := ["Run", "Sprint", "Idle", "CastIdle"]
	var classes: Array = CLASSES
	var use_orig := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("clips="):
			clips = a.substr(6).split(",")
		elif a.begins_with("classes="):
			classes = a.substr(8).split(",")
		elif a == "orig=1":
			use_orig = true
	for cls in classes:
		await _report(cls, clips, use_orig)
	quit()


func _report(cls: String, clips: Array, use_orig: bool) -> void:
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
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var cfg := {}                                                           # what the game does (RUN_CALM="legs=0.2,cloth=0" tries other values)
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json")):
		if c["id"] == cls:
			cfg = c.get("run_calm", {})
	ClothDamp.apply(skel, ap, cfg)
	var fixed_path := "res://models/classes/fixed/%s_body.res" % cls
	if not use_orig and ResourceLoader.exists(fixed_path):
		mesh = load(fixed_path)
	for clip in clips:
		if not ap.has_animation(clip):
			continue
		ap.play(clip)
		ap.pause()
		var length := ap.get_animation(clip).length
		var poses: Array = []
		for i in SAMPLES:
			ap.seek(length * float(i) / SAMPLES, true)
			await process_frame
			var mats: Array = []
			for b in skin.get_bind_count():
				var bi := skel.find_bone(skin.get_bind_name(b))
				mats.append(skel.get_bone_global_pose(bi) * skin.get_bind_pose(b))
			poses.append(mats)
		var worst_extra := 0.0
		var worst_ratio := 0.0
		var worst_desc := ""
		var bad := 0
		var bad_ratio := float(OS.get_environment("BAD_RATIO")) if OS.get_environment("BAD_RATIO") != "" else 1.6       # an edge counts as bad when it grows by more than this factor...
		var bad_extra := float(OS.get_environment("BAD_EXTRA")) if OS.get_environment("BAD_EXTRA") != "" else 0.04      # ...and by more than this many metres
		var groups := {}
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if bones.is_empty() or idx.is_empty():
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
			var seen := {}
			for t in range(0, idx.size(), 3):
				for e in 3:
					var a := idx[t + e]
					var b := idx[t + (e + 1) % 3]
					var key := mini(a, b) * n + maxi(a, b)
					if seen.has(key):
						continue
					seen[key] = true
					var rest := verts[a].distance_to(verts[b])
					if rest < 0.004:
						continue
					var wr := 0.0
					for pa in posed:
						wr = maxf(wr, (pa[a] as Vector3).distance_to(pa[b]))
					var extra := wr - rest
					if wr / rest > bad_ratio and extra > bad_extra:
						bad += 1
						var gk := "%s|%s y%.1f" % [_top_bone(skin, bones, weights, bpv, a).trim_prefix("cloth_").trim_prefix("DEF-"), _top_bone(skin, bones, weights, bpv, b).trim_prefix("cloth_").trim_prefix("DEF-"), snappedf(verts[a].y, 0.2)]
						groups[gk] = int(groups.get(gk, 0)) + 1
					if extra > worst_extra:
						worst_extra = extra
						worst_ratio = wr / rest
						worst_desc = "%s %s at y=%.2f" % [_top_bone(skin, bones, weights, bpv, a), _top_bone(skin, bones, weights, bpv, b), verts[a].y]
		if OS.get_environment("WHERE") != "":
			var ks: Array = groups.keys()
			ks.sort_custom(func(x, y): return groups[x] > groups[y])
			var top: PackedStringArray = []
			for i in mini(14, ks.size()):
				top.append("%s=%d" % [ks[i], groups[ks[i]]])
			print("GROUPS ", cls, " ", clip, " ", ", ".join(top))
		print("REPORT ", cls, " ", clip, " bad ", bad, " worst +", snappedf(worst_extra, 0.01), " m (x", snappedf(worst_ratio, 0.1), ") ", worst_desc)
	root.queue_free()


func _top_bone(skin: Skin, bones: PackedInt32Array, weights: PackedFloat32Array, bpv: int, v: int) -> String:
	var best := -1.0
	var name := ""
	for k in bpv:
		if weights[v * bpv + k] > best:
			best = weights[v * bpv + k]
			name = String(skin.get_bind_name(bones[v * bpv + k]))
	return name
