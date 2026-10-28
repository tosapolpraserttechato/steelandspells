extends SceneTree
# Makes the class bodies behave: (1) rigid boots (the toe weight moves to the foot, as before), (2) no stretched cloth.
# The cloth fix poses every class in many frames of the hard clips (slide, hook, jump, knockback, swings...), measures how much each edge of the mesh
# stretches compared with the rest pose and, where an edge stretches more than LIMIT times, smooths the bone weights of the vertices around it
# (they take on the weights of their neighbours) until nothing stretches that far. Writes models/classes/fixed/<class>_body.res.
#   godot --headless --path game --script res://tools/fix_body.gd [-- druid frost_mage ...]
const CLASSES := ["druid", "sea_king", "flame_lord", "frost_mage", "thunder_god", "desert_assassin", "necromancer", "arcanist", "poison_brewer", "pirate_captain", "time_mage", "celestial_mage", "gm_ravn"]
const CLIPS := ["Hook", "SlideStart", "JumpStart", "JumpLand", "MeleeA", "MeleeB", "MeleeC", "MeleeCombo", "Attack", "Knockback", "Throw", "CastShoot", "Block", "Revive", "ChestOpen"]
const FRACS := [0.3, 0.6, 0.95]
const RESKIN := ["cape"]       # cloth grids that get the smooth four-bone skinning first (tools/cloth_skin.gd); skirts: add "skirt"
const LOCO := {"Run": 10, "Sprint": 10, "SlideLoop": 3, "JumpLoop": 3, "CastIdle": 2}      # clip -> how many poses of it to probe (they loop, so spread over the cycle)
const BLEND := 0.14          # metres above the ankle over which the rigid foot weight fades out
const LIMIT := 1.45          # an edge may stretch to this many times its rest length (and by more than 4 cm)
const ROUNDS := 24

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var only: Array = OS.get_cmdline_user_args()
	for cls in CLASSES:
		if only.is_empty() or cls in only:
			await _fix(cls)
	quit()


func _fix(cls: String) -> void:
	var t0 := Time.get_ticks_msec()
	var packed: PackedScene = load("res://models/classes/class_%s.glb" % cls)
	var root: Node3D = packed.instantiate()
	get_root().add_child(root)
	await process_frame                      # the animation only reaches the skeleton once the tree has run a frame
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	var mi: MeshInstance3D = null
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			mi = m
	if mi == null:
		print("NO SKINNED MESH ", cls)
		return
	var skin: Skin = mi.skin
	var calm_cfg := {}                                              # the running clips as the game plays them (the class's run_calm)
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json")):
		if c["id"] == cls:
			calm_cfg = c.get("run_calm", {})
	ClothDamp.apply(skel, ap, calm_cfg)
	var bind_of := {}
	for i in skin.get_bind_count():
		bind_of[skin.get_bind_name(i)] = i
	# the poses: for every probe frame, the skinning matrix of every bind
	var poses: Array = []
	for clip in CLIPS + LOCO.keys():
		if not ap.has_animation(clip):
			continue
		ap.play(clip)
		ap.pause()
		var len := ap.get_animation(clip).length
		var fracs: Array = FRACS
		if LOCO.has(clip):                     # walking and running: a pose every few frames of the stride
			fracs = []
			for i in int(LOCO[clip]):
				fracs.append((float(i) + 0.5) / float(LOCO[clip]))
		for f in fracs:
			ap.seek(len * float(f), true)
			await process_frame
			var mats: Array = []
			for i in skin.get_bind_count():
				var b := skel.find_bone(skin.get_bind_name(i))
				mats.append(skel.get_bone_global_pose(b) * skin.get_bind_pose(i))
			poses.append(mats)
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var out := ArrayMesh.new()
	var changed_feet := 0
	var fixed_cloth := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var fmt := mesh.surface_get_format(s)
		if not bones.is_empty():
			var bpv := bones.size() / verts.size()
			changed_feet += _rigid_feet(skel, bind_of, skin, verts, bones, weights, bpv)
			_decouple_cloth(skin, bones, weights, bpv, verts.size())
			var index_arr: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			changed_feet += _unbridge_feet(skin, verts, index_arr, bones, weights, bpv)
			ClothSkin.reskin(skin, verts, bones, weights, bpv, RESKIN)
			var keep_b := bones.duplicate()
			var keep_w := weights.duplicate()
			var res := _fix_stretch(arrays, verts, bones, weights, bpv, poses)
			if res < 0:
				# the smoothing made it worse (suits, armour): keep the weights as they were
				for i in bones.size():
					bones[i] = keep_b[i]
					weights[i] = keep_w[i]
				print("   (smoothing undone)")
			else:
				fixed_cloth += res
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, [], {}, fmt)
		out.surface_set_material(s, mesh.surface_get_material(s))
	var err := ResourceSaver.save(out, "res://models/classes/fixed/%s_body.res" % cls)
	print("FIXED ", cls, " feet ", changed_feet, " cloth vertices re-weighted ", fixed_cloth, " poses ", poses.size(), " save ", err, " in ", (Time.get_ticks_msec() - t0) / 1000, " s")
	root.queue_free()


## Every vertex near or below the ankle follows only its foot bone (blending up the shin).
func _rigid_feet(skel: Skeleton3D, bind_of: Dictionary, skin: Skin, verts: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array, bpv: int) -> int:
	var foot_ids := {}
	var toe_ids := {}
	var foot_y := {}
	var foot_xz := {}
	for side in ["L", "R"]:
		var fb := skel.find_bone("DEF-foot." + side)
		var rest := skel.get_bone_global_rest(fb)
		foot_ids[side] = bind_of.get("DEF-foot." + side, -1)
		toe_ids[side] = bind_of.get("DEF-toe." + side, -1)
		foot_y[side] = rest.origin.y
		foot_xz[side] = Vector2(rest.origin.x, rest.origin.z)
	var cloth_ids := {}
	for i in skin.get_bind_count():
		var nm := String(skin.get_bind_name(i))
		if nm.begins_with("cloth_") or nm.begins_with("hair_"):
			cloth_ids[i] = true
	var changed := 0
	for v in verts.size():
		var p := verts[v]
		var cloth_w := 0.0
		for k in bpv:
			if cloth_ids.has(bones[v * bpv + k]):
				cloth_w += weights[v * bpv + k]
		if cloth_w >= 0.3:
			continue                                # a robe hem is cloth, not a boot: it must not be nailed to a foot
		var side := "L" if Vector2(p.x, p.z).distance_to(foot_xz["L"]) < Vector2(p.x, p.z).distance_to(foot_xz["R"]) else "R"
		if Vector2(p.x, p.z).distance_to(foot_xz[side]) > 0.32:
			continue
		var above: float = p.y - float(foot_y[side])
		if p.y > float(foot_y[side]) + BLEND:
			continue
		var w_foot := clampf(1.0 - above / BLEND, 0.0, 1.0) if above > 0.0 else 1.0
		var acc := {}
		for k in bpv:
			var b := bones[v * bpv + k]
			var w := weights[v * bpv + k]
			if w <= 0.0:
				continue
			if b == int(toe_ids[side]):
				b = int(foot_ids[side])
			acc[b] = float(acc.get(b, 0.0)) + w * (1.0 - w_foot)
		acc[int(foot_ids[side])] = float(acc.get(int(foot_ids[side]), 0.0)) + w_foot
		_store(v, acc, bones, weights, bpv)
		changed += 1
	return changed


## Cloth that has its own cloth bones (skirts, capes, hair strands) must follow those and the body core, not the legs and arms: a skirt that is
## half tied to a thigh is torn apart as soon as the leg swings forward. Limb weights on such vertices are cut to a small remainder.
func _decouple_cloth(skin: Skin, bones: PackedInt32Array, weights: PackedFloat32Array, bpv: int, n: int) -> void:
	var cloth := {}
	var limb := {}
	for i in skin.get_bind_count():
		var nm := String(skin.get_bind_name(i))
		if nm.begins_with("cloth_") or nm.begins_with("hair_"):
			cloth[i] = true
		elif nm.contains("thigh") or nm.contains("shin") or nm.contains("foot") or nm.contains("toe") or nm.contains("upper_arm") or nm.contains("forearm") or nm.contains("hand") or nm.contains("shoulder"):
			limb[i] = true
	if cloth.is_empty():
		return
	for v in n:
		var cs := 0.0
		for k in bpv:
			if cloth.has(bones[v * bpv + k]):
				cs += weights[v * bpv + k]
		if cs < 0.3:
			continue
		var total := 0.0
		for k in bpv:
			var w := weights[v * bpv + k]
			if limb.has(bones[v * bpv + k]):
				w *= 0.03
				weights[v * bpv + k] = w
			total += w
		if total > 0.0001:
			for k in bpv:
				weights[v * bpv + k] = weights[v * bpv + k] / total


## Writes the strongest `bpv` influences of `acc` (bone -> weight) into the arrays, normalised.
func _store(v: int, acc: Dictionary, bones: PackedInt32Array, weights: PackedFloat32Array, bpv: int) -> void:
	var keys := acc.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return acc[a] > acc[b])
	var total := 0.0
	for k in mini(bpv, keys.size()):
		total += float(acc[keys[k]])
	total = maxf(total, 0.0001)
	for k in bpv:
		if k < keys.size():
			bones[v * bpv + k] = int(keys[k])
			weights[v * bpv + k] = float(acc[keys[k]]) / total
		else:
			bones[v * bpv + k] = 0
			weights[v * bpv + k] = 0.0


func _pose_pos(mats: Array, bones: PackedInt32Array, weights: PackedFloat32Array, bpv: int, v: int, p: Vector3) -> Vector3:
	var r := Vector3.ZERO
	for k in bpv:
		var w := weights[v * bpv + k]
		if w > 0.0:
			r += (mats[bones[v * bpv + k]] as Transform3D) * p * w
	return r


func _fix_stretch(arrays: Array, verts: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array, bpv: int, poses: Array) -> int:
	var n := verts.size()
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		return 0
	# edges (unique) with their rest lengths; neighbours (also across seams, through welded positions)
	var edge_a := PackedInt32Array()
	var edge_b := PackedInt32Array()
	var edge_rest := PackedFloat32Array()
	var seen := {}
	for t in range(0, idx.size(), 3):
		for e in 3:
			var a := idx[t + e]
			var b := idx[t + (e + 1) % 3]
			var key := (mini(a, b) as int) * n + maxi(a, b)
			if seen.has(key):
				continue
			seen[key] = true
			var l := verts[a].distance_to(verts[b])
			if l < 0.0008:
				continue
			edge_a.append(a)
			edge_b.append(b)
			edge_rest.append(l)
	var group := {}
	var group_of := PackedInt32Array()
	group_of.resize(n)
	for v in n:
		var k := Vector3i(roundi(verts[v].x * 400.0), roundi(verts[v].y * 400.0), roundi(verts[v].z * 400.0))
		if not group.has(k):
			group[k] = []
		group[k].append(v)
		group_of[v] = 0
	var nbr: Array = []
	nbr.resize(n)
	for v in n:
		nbr[v] = []
	for e in edge_a.size():
		nbr[edge_a[e]].append(edge_b[e])
		nbr[edge_b[e]].append(edge_a[e])
	for k in group:
		var g: Array = group[k]
		if g.size() > 1:
			for v in g:
				for u in g:
					if u != v:
						nbr[v].append(u)
	# posed positions of every vertex in every pose
	var posed: Array = []
	for mats in poses:
		var arr := PackedVector3Array()
		arr.resize(n)
		for v in n:
			arr[v] = _pose_pos(mats, bones, weights, bpv, v, verts[v])
		posed.append(arr)
	var touched := {}
	var before := _stats(posed, edge_a, edge_b, edge_rest)
	for round in ROUNDS:
		var bad := {}
		for e in edge_a.size():
			if edge_rest[e] < 0.004:
				continue
			var worst := 0.0
			var worst_extra := 0.0
			for pa in posed:
				var d := (pa[edge_a[e]] as Vector3).distance_to(pa[edge_b[e]])
				worst = maxf(worst, d / edge_rest[e])
				worst_extra = maxf(worst_extra, d - edge_rest[e])
			if worst > LIMIT and worst_extra > 0.04:
				bad[edge_a[e]] = true
				bad[edge_b[e]] = true
		if bad.is_empty():
			break
		# widen by two rings, then smooth the weights of those vertices towards their neighbours
		var region := bad.duplicate()
		for ring in 3:
			var add := {}
			for v in region:
				for u in nbr[v]:
					add[u] = true
			region.merge(add)
		var cur: Dictionary = {}
		for v in region:
			cur[v] = _weights_of(v, bones, weights, bpv)
		for it in 6:
			var nxt: Dictionary = {}
			for v in region:
				var acc := {}
				for b in cur[v]:
					acc[b] = float(cur[v][b]) * 0.4
				var nn: Array = nbr[v]
				if nn.is_empty():
					nxt[v] = cur[v]
					continue
				var share := 0.6 / float(nn.size())
				for u in nn:
					var wu: Dictionary = cur[u] if cur.has(u) else _weights_of(u, bones, weights, bpv)
					for b in wu:
						acc[b] = float(acc.get(b, 0.0)) + float(wu[b]) * share
				nxt[v] = acc
			cur = nxt
		for v in region:
			_store(v, cur[v], bones, weights, bpv)
			touched[v] = true
		for pi in poses.size():
			var arr: PackedVector3Array = posed[pi]
			for v in region:
				arr[v] = _pose_pos(poses[pi], bones, weights, bpv, v, verts[v])
			posed[pi] = arr
	var after := _stats(posed, edge_a, edge_b, edge_rest)
	if after[0] >= before[0] and before[0] > 0:
		touched.clear()
		touched[-1] = true
	print("   stretch: edges over the limit ", before[0], " -> ", after[0], "   worst edge grows by (m) ", snappedf(before[1], 0.01), " -> ", snappedf(after[1], 0.01), "   (", edge_a.size(), " edges)")
	if touched.has(-1):
		return -1
	return touched.size()


## [edges stretched past LIMIT, the worst stretch ratio] over all probe poses.
func _stats(posed: Array, edge_a: PackedInt32Array, edge_b: PackedInt32Array, edge_rest: PackedFloat32Array) -> Array:
	var bad := 0
	var worst_all := 0.0
	for e in edge_a.size():
		if edge_rest[e] < 0.004:
			continue
		var worst := 0.0
		var worst_extra := 0.0
		for pa in posed:
			var d := (pa[edge_a[e]] as Vector3).distance_to(pa[edge_b[e]])
			worst = maxf(worst, d / edge_rest[e])
			worst_extra = maxf(worst_extra, d - edge_rest[e])
		if worst > LIMIT and worst_extra > 0.04:
			bad += 1
		if worst_extra > worst_all:
			worst_all = worst_extra
	return [bad, worst_all]


func _weights_of(v: int, bones: PackedInt32Array, weights: PackedFloat32Array, bpv: int) -> Dictionary:
	var d := {}
	for k in bpv:
		var w := weights[v * bpv + k]
		if w > 0.0:
			d[bones[v * bpv + k]] = float(d.get(bones[v * bpv + k], 0.0)) + w
	return d


## Faces that join the left foot to the right one (a robe hem or coat tail near the ground) stretch whenever the feet part: the vertices of such an edge are mostly
## hung from the hips instead, with only a little of their own foot.
func _unbridge_feet(skin: Skin, verts: PackedVector3Array, idx: PackedInt32Array, bones: PackedInt32Array, weights: PackedFloat32Array, bpv: int) -> int:
	var ids := {}
	for i in skin.get_bind_count():
		ids[String(skin.get_bind_name(i))] = i
	if not (ids.has("DEF-foot.L") and ids.has("DEF-foot.R") and ids.has("DEF-hips")):
		return 0
	var fl: int = ids["DEF-foot.L"]
	var fr: int = ids["DEF-foot.R"]
	var marked := {}
	for t in range(0, idx.size(), 3):
		for e in 3:
			var a := idx[t + e]
			var b := idx[t + (e + 1) % 3]
			if verts[a].y > 0.4 or verts[b].y > 0.4:
				continue
			var da := _dominant(a, bones, weights, bpv)
			var db := _dominant(b, bones, weights, bpv)
			if (da == fl and db == fr) or (da == fr and db == fl):
				marked[a] = da
				marked[b] = db
	for v in marked:
		_store(v, {int(ids["DEF-hips"]): 0.7, int(marked[v]): 0.3}, bones, weights, bpv)
	return marked.size()


func _dominant(v: int, bones: PackedInt32Array, weights: PackedFloat32Array, bpv: int) -> int:
	var best := -1.0
	var b := -1
	for k in bpv:
		if weights[v * bpv + k] > best:
			best = weights[v * bpv + k]
			b = bones[v * bpv + k]
	return b
