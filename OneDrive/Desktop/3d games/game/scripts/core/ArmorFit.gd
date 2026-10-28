class_name ArmorFit
extends RefCounted
## Measures the body of a class model so armor can be built to fit it: how wide and deep the chest is at each height, how thick every limb is, how big the skull is.
## Every vertex of the skinned mesh is given to the bone that moves it most; from the vertices of one bone (in the rest pose, model space) come its radius around the bone's
## axis. Robes and capes weigh a lot of cloth on the legs and the spine, so the numbers are taken from a middle percentile and capped at what a body can be.
## Result, all in skeleton (model) space with +Y up and the character facing +Z:
##   "torso": [{"y", "cx", "cz", "rx", "rz"}...] from the hips to the shoulders, "head": {"c", "r", "top"}, "limbs": {name: {"a", "b", "r"}} for upper_arm / forearm / thigh / shin
##   (a = joint, b = next joint), "foot.L" / "foot.R": {"a" ankle, "b" toe, "w" width, "h" height}, "shoulder.L" / "shoulder.R": the shoulder joint, "hips": the hips joint, "height".

const CAP := {"upper_arm": 0.075, "forearm": 0.062, "thigh": 0.15, "shin": 0.1}
const FLOOR := {"upper_arm": 0.04, "forearm": 0.032, "thigh": 0.07, "shin": 0.045}

static var _cache: Dictionary = {}


static func measure(class_id: String, skeleton: Skeleton3D, meshes: Array) -> Dictionary:
	if _cache.has(class_id):
		return _cache[class_id]
	var out := _measure(skeleton, meshes)
	_cache[class_id] = out
	return out


static func _rest(sk: Skeleton3D, bone: String) -> Vector3:
	var i := sk.find_bone(bone)
	return sk.get_bone_global_rest(i).origin if i >= 0 else Vector3.ZERO


static func _measure(sk: Skeleton3D, meshes: Array) -> Dictionary:
	# per bone: the rest-pose positions of the vertices it moves most
	var verts: Dictionary = {}
	for mi in meshes:
		var m := mi as MeshInstance3D
		if m == null or m.mesh == null or m.skin == null:
			continue
		var bind_to_bone: Array = []
		for i in m.skin.get_bind_count():
			var b := m.skin.get_bind_bone(i)
			if b < 0:
				b = sk.find_bone(m.skin.get_bind_name(i))
			bind_to_bone.append(b)
		var to_skel: Transform3D = sk.global_transform.affine_inverse() * m.global_transform
		for s in m.mesh.get_surface_count():
			var arrays := m.mesh.surface_get_arrays(s)
			var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var pb: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var pw: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if pv.is_empty() or pb.is_empty():
				continue
			var per := pb.size() / pv.size()
			for v in pv.size():
				var best := 0
				var bw := -1.0
				for j in per:
					if pw[v * per + j] > bw:
						bw = pw[v * per + j]
						best = pb[v * per + j]
				if best < 0 or best >= bind_to_bone.size():
					continue
				var bone: int = bind_to_bone[best]
				if bone < 0:
					continue
				if not verts.has(bone):
					verts[bone] = []                                  # a plain Array: a Packed array stored in a Dictionary is copied on every append
				(verts[bone] as Array).append(to_skel * pv[v])
	if OS.get_environment("ARMOR_DEBUG") != "":
		var parts := []
		for b in verts:
			parts.append("%s:%d" % [sk.get_bone_name(b), (verts[b] as Array).size()])
		print("ARMORFIT meshes ", meshes.size(), " bones with vertices ", ", ".join(parts))
	var out := {}
	var hips := _rest(sk, "DEF-hips")
	out["hips"] = hips
	out["shoulder.L"] = _rest(sk, "DEF-upper_arm.L")
	out["shoulder.R"] = _rest(sk, "DEF-upper_arm.R")
	out["height"] = _rest(sk, "DEF-head").y + 0.26
	# the torso: the vertices of hips, spine and neck bones, in bands of 8 cm
	var torso := PackedVector3Array()
	for bn in ["DEF-hips", "DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-neck"]:
		var bi := sk.find_bone(bn)
		if verts.has(bi):
			for tp in verts[bi]:
				torso.append(tp)
	var bands: Array = []
	var y_top := _rest(sk, "DEF-spine.003").y + 0.14
	var y := hips.y - 0.04
	while y <= y_top:
		var xs: Array = []
		var zs: Array = []
		for p in torso:
			if absf(p.y - y) < 0.045:
				xs.append(p.x)
				zs.append(p.z)
		if xs.size() >= 12:
			xs.sort()
			zs.sort()
			var xl: float = xs[int(xs.size() * 0.04)]
			var xh: float = xs[int(xs.size() * 0.96)]
			var zf: float = zs[int(zs.size() * 0.96)]
			var spine_z: float = hips.z
			var rz := maxf(zf - spine_z, 0.08)
			bands.append({"y": y, "cx": (xl + xh) * 0.5, "cz": spine_z + rz * 0.05, "rx": maxf((xh - xl) * 0.5, 0.1), "rz": rz})
		y += 0.08
	out["torso"] = bands
	# the head: the top 24 cm above the head bone (hair included, down to where it hangs)
	var head_bone := sk.find_bone("DEF-head")
	var hp := _rest(sk, "DEF-head")
	var hx: Array = []
	var hz: Array = []
	var top := hp.y + 0.2
	if verts.has(head_bone):
		for p in verts[head_bone]:
			if p.y > hp.y + 0.02 and p.y < hp.y + 0.3:
				hx.append(absf(p.x))
				hz.append(p.z)
				top = maxf(top, p.y)
	var rx := 0.1
	var rzf := 0.11
	var rzb := 0.11
	var cz := hp.z
	if hx.size() > 20:
		hx.sort()
		hz.sort()
		rx = clampf(float(hx[int(hx.size() * 0.88)]), 0.085, 0.16)
		var zlo: float = hz[int(hz.size() * 0.1)]
		var zhi: float = hz[int(hz.size() * 0.97)]
		cz = (zlo + zhi) * 0.5
		rzf = clampf((zhi - zlo) * 0.5, 0.09, 0.16)
		rzb = rzf
	out["head"] = {"c": Vector3(0.0, hp.y + 0.11, cz), "r": Vector3(rx, 0.13, rzf), "top": minf(top, hp.y + 0.3), "base": hp.y}
	# limbs
	var limbs := {}
	for side in ["L", "R"]:
		for pair in [["upper_arm", "forearm"], ["forearm", "hand"], ["thigh", "shin"], ["shin", "foot"]]:
			var name: String = pair[0]
			var a := _rest(sk, "DEF-%s.%s" % [name, side])
			var b := _rest(sk, "DEF-%s.%s" % [pair[1], side])
			var axis := b - a
			var len := axis.length()
			if len < 0.01:
				continue
			axis /= len
			var bi := sk.find_bone("DEF-%s.%s" % [name, side])
			var rs: Array = []
			if verts.has(bi):
				for p in verts[bi]:
					var t: float = (p - a).dot(axis)
					if t > len * 0.1 and t < len * 0.9:
						rs.append((p - a - axis * t).length())
			var r: float = float(FLOOR[name])
			if rs.size() > 10:
				rs.sort()
				r = clampf(float(rs[int(rs.size() * 0.6)]), float(FLOOR[name]), float(CAP[name]))
			limbs["%s.%s" % [name, side]] = {"a": a, "b": b, "r": r}
	out["limbs"] = limbs
	# feet
	for side in ["L", "R"]:
		var ankle := _rest(sk, "DEF-foot.%s" % side)
		var toe := _rest(sk, "DEF-toe.%s" % side)
		var bi := sk.find_bone("DEF-foot.%s" % side)
		var wmax := 0.05
		var hmax := 0.06
		if verts.has(bi):
			var ws: Array = []
			for p in verts[bi]:
				if p.y < ankle.y + 0.1:
					ws.append(absf(p.x - ankle.x))
			if ws.size() > 10:
				ws.sort()
				wmax = clampf(float(ws[int(ws.size() * 0.85)]), 0.04, 0.08)
		out["foot.%s" % side] = {"a": ankle, "b": toe + Vector3(0, 0, 0.07), "w": wmax, "h": hmax}
	if OS.get_environment("ARMOR_DEBUG") != "":
		print("ARMORFIT result ", out)
	return out
