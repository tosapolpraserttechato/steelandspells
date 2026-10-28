class_name ClothSkin
extends RefCounted
## Re-skins capes (and optionally skirts) so that they bend smoothly. A cape is a grid of cloth bones (cloth_cape_<column>_<row>), a skirt a ring of them
## (cloth_skirt_<around>_<row>). Every vertex of the cloth gets its weight shared between the four cloth bones around its rest position (two columns x two rows,
## interpolated), so that neighbouring vertices do not hang from bones that are far apart in the grid. Called by fix_body.gd before its stretch smoothing,
## which then blends the border between cloth and body.

const MIN_CLOTH := 0.5            # a vertex counts as cloth when at least this much of its weight is on that kind of bone


## `kinds` is a list of "cape" and / or "skirt". Changes `bones` and `weights` in place; returns how many vertices were re-skinned.
static func reskin(skin: Skin, verts: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array, bpv: int, kinds: Array) -> int:
	var grids := {}
	var ids := {}
	var re := RegEx.new()
	re.compile("^cloth_(cape|skirt)_(\\d+)_(\\d+)$")
	for i in skin.get_bind_count():
		var m := re.search(String(skin.get_bind_name(i)))
		if m == null or not (m.get_string(1) in kinds):
			continue
		var kind := m.get_string(1)
		var col := int(m.get_string(2))
		var row := int(m.get_string(3))
		if not grids.has(kind):
			grids[kind] = {}
			ids[kind] = {}
		if not grids[kind].has(col):
			grids[kind][col] = {}
		grids[kind][col][row] = [i, skin.get_bind_pose(i).affine_inverse().origin]
		ids[kind][i] = true
	var total := 0
	for kind in grids:
		var lat := _lattice(grids[kind], kind == "skirt")
		for v in verts.size():
			var cs := 0.0
			for k in bpv:
				if ids[kind].has(bones[v * bpv + k]):
					cs += weights[v * bpv + k]
			if cs < MIN_CLOTH:
				continue
			var acc := {}
			for k in bpv:
				var b := bones[v * bpv + k]
				if weights[v * bpv + k] > 0.0 and not ids[kind].has(b):
					acc[b] = float(acc.get(b, 0.0)) + weights[v * bpv + k]
			var inter := _interpolate(lat, verts[v])
			for b in inter:
				acc[b] = float(acc.get(b, 0.0)) + float(inter[b]) * cs
			_store(v, acc, bones, weights, bpv)
			total += 1
	return total


## {"ring", "centre", "rows" (sorted), "at": {row: [[key, bind]...] sorted by key}, "row_y"}. The key of a bone along its row is its x (a cape) or its angle (a skirt).
static func _lattice(grid: Dictionary, ring: bool) -> Dictionary:
	var cols: Array = grid.keys()
	cols.sort()
	var rows := {}
	for c in cols:
		for r in grid[c]:
			rows[r] = true
	var row_list: Array = rows.keys()
	row_list.sort()
	var centre := Vector3.ZERO
	var cnt := 0
	for c in cols:
		for r in grid[c]:
			centre += grid[c][r][1]
			cnt += 1
	centre /= float(maxi(cnt, 1))
	var at := {}
	var row_y := {}
	for r in row_list:
		var list: Array = []
		var y := 0.0
		var m := 0
		for c in cols:
			if grid[c].has(r):
				var p: Vector3 = grid[c][r][1]
				var key := atan2(p.z - centre.z, p.x - centre.x) if ring else p.x
				list.append([key, int(grid[c][r][0])])
				y += p.y
				m += 1
		list.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		at[r] = list
		row_y[r] = y / float(maxi(m, 1))
	return {"ring": ring, "centre": centre, "rows": row_list, "at": at, "row_y": row_y}


## The four bones around `p` (rest position), weights adding up to 1: two rows (by height) x two columns (by x or angle).
static func _interpolate(lat: Dictionary, p: Vector3) -> Dictionary:
	var rows: Array = lat["rows"]
	var row_y: Dictionary = lat["row_y"]
	var r0: int = rows[0]
	var r1: int = rows[0]
	var fr := 0.0
	if p.y >= float(row_y[rows[0]]):
		pass
	elif p.y <= float(row_y[rows[rows.size() - 1]]):
		r0 = rows[rows.size() - 1]
		r1 = r0
	else:
		for i in rows.size() - 1:
			var ya := float(row_y[rows[i]])
			var yb := float(row_y[rows[i + 1]])
			if p.y <= ya and p.y >= yb:
				r0 = rows[i]
				r1 = rows[i + 1]
				fr = (ya - p.y) / maxf(ya - yb, 0.0001)
				break
	var out := {}
	for pair in [[r0, 1.0 - fr], [r1, fr]]:
		var wr: float = pair[1]
		if wr <= 0.0001:
			continue
		for e in _along(lat, lat["at"][pair[0]], p):
			out[e[0]] = float(out.get(e[0], 0.0)) + wr * float(e[1])
	return out


static func _along(lat: Dictionary, list: Array, p: Vector3) -> Array:
	var ring: bool = lat["ring"]
	var centre: Vector3 = lat["centre"]
	var key := atan2(p.z - centre.z, p.x - centre.x) if ring else p.x
	var n := list.size()
	if n == 1:
		return [[list[0][1], 1.0]]
	if not ring:
		if key <= float(list[0][0]):
			return [[list[0][1], 1.0]]
		if key >= float(list[n - 1][0]):
			return [[list[n - 1][1], 1.0]]
		for i in n - 1:
			var ka := float(list[i][0])
			var kb := float(list[i + 1][0])
			if key >= ka and key <= kb:
				var f := (key - ka) / maxf(kb - ka, 0.0001)
				return [[list[i][1], 1.0 - f], [list[i + 1][1], f]]
		return [[list[n - 1][1], 1.0]]
	for i in n:
		var a := float(list[i][0])
		var b := float(list[(i + 1) % n][0])
		var span := fposmod(b - a, TAU)
		var off := fposmod(key - a, TAU)
		if off <= span or span < 0.0001:
			var f := off / maxf(span, 0.0001)
			return [[list[i][1], 1.0 - f], [list[(i + 1) % n][1], f]]
	return [[list[0][1], 1.0]]


static func _store(v: int, acc: Dictionary, bones: PackedInt32Array, weights: PackedFloat32Array, bpv: int) -> void:
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
