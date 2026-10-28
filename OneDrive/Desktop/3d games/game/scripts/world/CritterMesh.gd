class_name CritterMesh
extends RefCounted
## The little animals that live in the maps (bunny, frog, crab, penguin, beetle, mouse, lizard, butterfly, dragonfly, bird, bat, fish, jellyfish), as low-poly meshes
## in the same flat-shaded style as DecorMesh. Forward is +Z, up is +Y, sizes are in metres.
## `parts(kind, variant)` returns {body: ArrayMesh, wing: ArrayMesh (one side, mirrored for the other), wing_at: Vector3, tail: ArrayMesh, tail_at: Vector3,
## glow: Color (black = does not glow), scale: float}. Variants are colour schemes.

const KINDS := ["bunny", "frog", "crab", "penguin", "beetle", "mouse", "lizard", "butterfly", "dragonfly", "bird", "bat", "fish", "jellyfish"]
static var _cache: Dictionary = {}


static func parts(kind: String, variant: int) -> Dictionary:
	var key := "%s%d" % [kind, variant]
	if not _cache.has(key):
		_cache[key] = _make(kind, variant)
	return _cache[key]


static func _pick(list: Array, v: int) -> Variant:
	return list[v % list.size()]


static func _make(kind: String, v: int) -> Dictionary:
	var out := {"wing_at": Vector3.ZERO, "tail_at": Vector3.ZERO, "glow": Color(0, 0, 0), "scale": 1.0}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"bunny": _bunny(st, v, out)
		"frog": _frog(st, v, out)
		"crab": _crab(st, v, out)
		"penguin": _penguin(st, v, out)
		"beetle": _beetle(st, v, out)
		"mouse": _mouse(st, v, out)
		"lizard": _lizard(st, v, out)
		"butterfly": _butterfly(st, v, out)
		"dragonfly": _dragonfly(st, v, out)
		"bird": _bird(st, v, out)
		"bat": _bat(st, v, out)
		"fish": _fish(st, v, out)
		"jellyfish": _jelly(st, v, out)
	st.generate_normals()
	out["body"] = st.commit()
	return out


# ----------------------------------------------------------------- building blocks

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var lc := col.srgb_to_linear()
	for p in [a, b, c]:
		st.set_color(lc)
		st.add_vertex(p)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)


## A whole ellipsoid: radii `r`, turned by `basis`, darker underneath.
static func _ell(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, basis: Basis = Basis(), sides: int = 7, rings: int = 4, under: float = 0.7) -> void:
	var grid: Array = []
	for i in rings + 1:
		var lat := -PI * 0.5 + PI * float(i) / float(rings)
		var ring: Array = []
		for k in sides:
			var a := TAU * k / sides
			ring.append(c + basis * Vector3(cos(lat) * cos(a) * r.x, sin(lat) * r.y, cos(lat) * sin(a) * r.z))
		grid.append(ring)
	for i in rings:
		var s0 := lerpf(under, 1.08, float(i) / float(rings))
		var s1 := lerpf(under, 1.08, float(i + 1) / float(rings))
		var c0 := Color(col.r * s0, col.g * s0, col.b * s0)
		var c1 := Color(col.r * s1, col.g * s1, col.b * s1)
		for k in sides:
			var k2 := (k + 1) % sides
			if i == 0:
				_tri(st, grid[0][k], grid[1][k2], grid[1][k], c1)
			elif i == rings - 1:
				_tri(st, grid[i][k], grid[i][k2], grid[rings][k], c0)
			else:
				_quad(st, grid[i][k], grid[i][k2], grid[i + 1][k2], grid[i + 1][k], c0.lerp(c1, 0.5))


## A thin tapered tube from a to b.
static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, sides: int = 4) -> void:
	var dir := (b - a).normalized()
	var u := dir.cross(Vector3.UP)
	if u.length() < 0.01:
		u = dir.cross(Vector3.RIGHT)
	u = u.normalized()
	var w := dir.cross(u).normalized()
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var s := 0.85 + 0.15 * float(k % 2)
		var cc := Color(col.r * s, col.g * s, col.b * s)
		_quad(st, a + (u * cos(a0) + w * sin(a0)) * r0, a + (u * cos(a1) + w * sin(a1)) * r0, b + (u * cos(a1) + w * sin(a1)) * r1, b + (u * cos(a0) + w * sin(a0)) * r1, cc)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		_tri(st, b, b + (u * cos(a0) + w * sin(a0)) * r1, b + (u * cos(a1) + w * sin(a1)) * r1, col.lightened(0.1))


static func _cone(st: SurfaceTool, base: Vector3, tip: Vector3, r: float, col: Color, sides: int = 5) -> void:
	_tube(st, base, tip, r, r * 0.05, col, sides)


static func _eyes(st: SurfaceTool, at: Vector3, spread: float, r: float, col: Color = Color(0.05, 0.05, 0.07)) -> void:
	for s in [-1.0, 1.0]:
		_ell(st, at + Vector3(spread * s, 0, 0), Vector3(r, r, r), col, Basis(), 5, 3, 1.0)


static func _tilt(x: float, z: float = 0.0) -> Basis:
	return Basis(Vector3(1, 0, 0), x) * Basis(Vector3(0, 0, 1), z)


# ----------------------------------------------------------------- the animals

static func _bunny(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var look: Array = _pick([
		[Color(0.93, 0.92, 0.9), Color(1.0, 0.8, 0.85)],       # white
		[Color(0.55, 0.38, 0.25), Color(0.85, 0.68, 0.55)],    # brown
		[Color(0.62, 0.62, 0.66), Color(0.9, 0.85, 0.85)],     # grey
		[Color(0.82, 0.62, 0.38), Color(0.98, 0.9, 0.75)],     # tan
	], v)
	var body: Color = look[0]
	var inner: Color = look[1]
	_ell(st, Vector3(0, 0.11, -0.01), Vector3(0.095, 0.085, 0.15), body)
	for s in [-1.0, 1.0]:
		_ell(st, Vector3(0.07 * s, 0.085, -0.075), Vector3(0.045, 0.065, 0.075), body.darkened(0.05))
		_ell(st, Vector3(0.05 * s, 0.015, 0.06), Vector3(0.02, 0.016, 0.04), body.darkened(0.1), Basis(), 5, 3)
		_ell(st, Vector3(0.05 * s, 0.015, -0.1), Vector3(0.025, 0.016, 0.055), body.darkened(0.1), Basis(), 5, 3)
		_ell(st, Vector3(0.035 * s, 0.3, 0.09), Vector3(0.018, 0.08, 0.012), body, _tilt(-0.3, -0.12 * s), 5, 3)
		_ell(st, Vector3(0.035 * s, 0.295, 0.098), Vector3(0.011, 0.062, 0.006), inner, _tilt(-0.3, -0.12 * s), 5, 3)
	_ell(st, Vector3(0, 0.185, 0.125), Vector3(0.062, 0.058, 0.07), body)
	_ell(st, Vector3(0, 0.12, -0.165), Vector3(0.036, 0.036, 0.036), Color(1, 1, 1), Basis(), 6, 3, 0.9)
	_eyes(st, Vector3(0, 0.2, 0.17), 0.04, 0.011)
	_ell(st, Vector3(0, 0.178, 0.195), Vector3(0.012, 0.009, 0.01), Color(1.0, 0.55, 0.62), Basis(), 5, 3, 1.0)


static func _frog(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var look: Array = _pick([
		[Color(0.3, 0.7, 0.22), Color(0.85, 0.9, 0.55), Color(0.95, 0.85, 0.2)],      # green
		[Color(0.2, 0.75, 0.62), Color(0.7, 0.95, 0.75), Color(0.85, 0.2, 0.55)],     # toxic teal
		[Color(0.72, 0.4, 0.15), Color(0.95, 0.8, 0.5), Color(0.95, 0.85, 0.3)],      # brown
		[Color(0.35, 0.55, 0.9), Color(0.85, 0.92, 1.0), Color(1.0, 0.9, 0.3)],       # blue
	], v)
	var body: Color = look[0]
	_ell(st, Vector3(0, 0.055, 0), Vector3(0.075, 0.05, 0.095), body)
	_ell(st, Vector3(0, 0.04, 0.012), Vector3(0.062, 0.03, 0.08), look[1], Basis(), 6, 3, 1.0)
	_ell(st, Vector3(0, 0.07, 0.07), Vector3(0.065, 0.04, 0.05), body)
	for s in [-1.0, 1.0]:
		_ell(st, Vector3(0.04 * s, 0.115, 0.075), Vector3(0.026, 0.026, 0.026), look[2], Basis(), 6, 3, 0.9)
		_ell(st, Vector3(0.042 * s, 0.118, 0.095), Vector3(0.013, 0.013, 0.008), Color(0.04, 0.04, 0.05), Basis(), 5, 3, 1.0)
		_ell(st, Vector3(0.085 * s, 0.035, -0.04), Vector3(0.028, 0.022, 0.06), body.darkened(0.1), _tilt(0, 0.0), 6, 3)
		_ell(st, Vector3(0.06 * s, 0.018, 0.075), Vector3(0.018, 0.018, 0.03), body.darkened(0.1), Basis(), 5, 3)
		_ell(st, Vector3(0.05 * s, 0.1, -0.03), Vector3(0.013, 0.012, 0.013), look[2], Basis(), 5, 3)
	if v == 1:
		out["glow"] = Color(0.3, 1.0, 0.8)


static func _crab(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var body: Color = _pick([Color(0.95, 0.42, 0.25), Color(0.85, 0.25, 0.2), Color(0.95, 0.6, 0.3), Color(0.55, 0.45, 0.8)], v)
	var tip: Color = body.lightened(0.25)
	_ell(st, Vector3(0, 0.045, 0), Vector3(0.095, 0.04, 0.07), body, Basis(), 8, 3)
	for s in [-1.0, 1.0]:
		_tube(st, Vector3(0.03 * s, 0.07, 0.05), Vector3(0.035 * s, 0.105, 0.06), 0.006, 0.005, body.darkened(0.2))
		_ell(st, Vector3(0.035 * s, 0.11, 0.063), Vector3(0.013, 0.013, 0.013), Color(0.05, 0.05, 0.06), Basis(), 5, 3, 1.0)
		_tube(st, Vector3(0.075 * s, 0.05, 0.04), Vector3(0.125 * s, 0.065, 0.1), 0.013, 0.011, body)
		_ell(st, Vector3(0.135 * s, 0.07, 0.125), Vector3(0.036, 0.022, 0.044), tip, _tilt(0.0, -0.25 * s), 6, 3)
		_cone(st, Vector3(0.12 * s, 0.07, 0.155), Vector3(0.105 * s, 0.075, 0.2), 0.016, tip.darkened(0.1))
		_cone(st, Vector3(0.15 * s, 0.07, 0.155), Vector3(0.165 * s, 0.075, 0.2), 0.016, tip.darkened(0.1))
		for q in 3:
			var z := -0.035 + 0.03 * q
			_tube(st, Vector3(0.085 * s, 0.04, z), Vector3(0.14 * s, 0.05, z - 0.005), 0.008, 0.007, body.darkened(0.15))
			_tube(st, Vector3(0.14 * s, 0.05, z - 0.005), Vector3(0.17 * s, 0.0, z - 0.02), 0.007, 0.004, body.darkened(0.25))


static func _penguin(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var look: Array = _pick([
		[Color(0.12, 0.13, 0.18), Color(0.97, 0.97, 0.95), Color(1.0, 0.65, 0.15)],
		[Color(0.2, 0.25, 0.4), Color(0.95, 0.95, 0.98), Color(1.0, 0.8, 0.2)],
		[Color(0.35, 0.3, 0.28), Color(0.95, 0.92, 0.88), Color(1.0, 0.5, 0.2)],
	], v)
	_ell(st, Vector3(0, 0.17, 0), Vector3(0.1, 0.17, 0.09), look[0], Basis(), 8, 4)
	_ell(st, Vector3(0, 0.16, 0.025), Vector3(0.07, 0.14, 0.07), look[1], Basis(), 8, 4, 1.0)
	_ell(st, Vector3(0, 0.355, 0.012), Vector3(0.065, 0.065, 0.065), look[0], Basis(), 7, 4)
	_cone(st, Vector3(0, 0.35, 0.06), Vector3(0, 0.34, 0.125), 0.02, look[2])
	_eyes(st, Vector3(0, 0.375, 0.05), 0.033, 0.009, Color(0.02, 0.02, 0.03))
	for s in [-1.0, 1.0]:
		_ell(st, Vector3(0.108 * s, 0.2, 0), Vector3(0.016, 0.085, 0.04), look[0].darkened(0.1), _tilt(0.0, -0.35 * s), 5, 3)
		_ell(st, Vector3(0.04 * s, 0.008, 0.045), Vector3(0.03, 0.01, 0.048), look[2], Basis(), 5, 3, 1.0)


static func _beetle(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var look: Array = _pick([
		[Color(0.1, 0.55, 0.5), Color(0.05, 0.06, 0.08)],      # teal scarab
		[Color(0.85, 0.65, 0.15), Color(0.1, 0.08, 0.06)],     # gold
		[Color(0.8, 0.25, 0.12), Color(0.1, 0.06, 0.05)],      # ember red
		[Color(0.35, 0.3, 0.75), Color(0.05, 0.05, 0.1)],      # violet
		[Color(0.7, 0.4, 0.2), Color(0.12, 0.08, 0.06)],       # copper
	], v)
	_ell(st, Vector3(0, 0.038, -0.005), Vector3(0.05, 0.038, 0.07), look[0], Basis(), 8, 4)
	_tube(st, Vector3(0, 0.074, -0.06), Vector3(0, 0.072, 0.055), 0.003, 0.003, look[1])
	_ell(st, Vector3(0, 0.03, 0.075), Vector3(0.028, 0.022, 0.025), look[1], Basis(), 6, 3)
	for s in [-1.0, 1.0]:
		_tube(st, Vector3(0.012 * s, 0.04, 0.095), Vector3(0.03 * s, 0.065, 0.13), 0.004, 0.002, look[1])
		for q in 3:
			var z := -0.03 + 0.035 * q
			_tube(st, Vector3(0.04 * s, 0.02, z), Vector3(0.08 * s, 0.005, z + 0.01), 0.005, 0.003, look[1])
	if v == 2:
		out["glow"] = Color(1.0, 0.4, 0.1)
	elif v == 3:
		out["glow"] = Color(0.5, 0.6, 1.0)


static func _mouse(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var look: Array = _pick([
		[Color(0.6, 0.58, 0.6), Color(1.0, 0.7, 0.75)],
		[Color(0.5, 0.36, 0.26), Color(0.95, 0.72, 0.7)],
		[Color(0.9, 0.88, 0.85), Color(1.0, 0.65, 0.7)],
		[Color(0.28, 0.27, 0.3), Color(0.9, 0.6, 0.65)],
	], v)
	_ell(st, Vector3(0, 0.048, 0), Vector3(0.042, 0.042, 0.075), look[0])
	_ell(st, Vector3(0, 0.055, 0.08), Vector3(0.03, 0.03, 0.04), look[0])
	for s in [-1.0, 1.0]:
		_ell(st, Vector3(0.03 * s, 0.09, 0.062), Vector3(0.02, 0.022, 0.004), look[1], Basis(Vector3(0, 1, 0), 0.5 * s), 6, 3, 1.0)
	_ell(st, Vector3(0, 0.052, 0.12), Vector3(0.009, 0.007, 0.007), look[1], Basis(), 5, 3, 1.0)
	_eyes(st, Vector3(0, 0.07, 0.1), 0.02, 0.007)
	_tube(st, Vector3(0, 0.04, -0.07), Vector3(0, 0.025, -0.14), 0.005, 0.003, look[1])
	_tube(st, Vector3(0, 0.025, -0.14), Vector3(0.02, 0.02, -0.21), 0.003, 0.002, look[1])
	for s in [-1.0, 1.0]:
		_ell(st, Vector3(0.03 * s, 0.01, 0.03), Vector3(0.013, 0.011, 0.025), look[1], Basis(), 5, 3, 1.0)
		_ell(st, Vector3(0.035 * s, 0.01, -0.04), Vector3(0.015, 0.011, 0.03), look[1], Basis(), 5, 3, 1.0)


static func _lizard(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var look: Array = _pick([
		[Color(0.78, 0.62, 0.35), Color(0.95, 0.85, 0.55)],    # sand
		[Color(0.35, 0.65, 0.3), Color(0.8, 0.9, 0.4)],        # green
		[Color(0.2, 0.15, 0.17), Color(1.0, 0.45, 0.1)],       # ember salamander
		[Color(0.3, 0.55, 0.75), Color(0.85, 0.95, 1.0)],      # blue
	], v)
	_ell(st, Vector3(0, 0.03, 0), Vector3(0.036, 0.024, 0.075), look[0], Basis(), 6, 3)
	_ell(st, Vector3(0, 0.032, 0.09), Vector3(0.026, 0.02, 0.04), look[0], Basis(), 6, 3)
	_ell(st, Vector3(0, 0.048, 0.0), Vector3(0.011, 0.01, 0.065), look[1], Basis(), 5, 3, 1.0)
	_eyes(st, Vector3(0, 0.046, 0.105), 0.016, 0.006)
	var prev := Vector3(0, 0.028, -0.07)
	var r := 0.022
	for i in 5:
		var nxt := prev + Vector3(sin(float(i) * 0.9) * 0.025, -0.002, -0.06)
		_tube(st, prev, nxt, r, r * 0.65, look[0], 5)
		prev = nxt
		r *= 0.65
	for s in [-1.0, 1.0]:
		_tube(st, Vector3(0.03 * s, 0.025, 0.045), Vector3(0.07 * s, 0.008, 0.06), 0.008, 0.005, look[0].darkened(0.1))
		_tube(st, Vector3(0.03 * s, 0.025, -0.045), Vector3(0.07 * s, 0.008, -0.06), 0.008, 0.005, look[0].darkened(0.1))
	if v == 2:
		out["glow"] = Color(1.0, 0.35, 0.05)


static func _wing_tris(st: SurfaceTool, pts: Array, col: Color) -> void:
	for i in range(1, pts.size() - 1):
		_tri(st, pts[0], pts[i], pts[i + 1], col)


static func _butterfly(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var look: Array = _pick([
		[Color(1.0, 0.55, 0.12), Color(0.1, 0.07, 0.05), Color(1.0, 0.9, 0.7)],     # monarch
		[Color(0.3, 0.55, 1.0), Color(0.08, 0.1, 0.25), Color(0.8, 0.95, 1.0)],     # blue
		[Color(1.0, 0.5, 0.75), Color(0.35, 0.1, 0.25), Color(1.0, 0.9, 0.95)],     # pink
		[Color(1.0, 0.95, 0.55), Color(0.35, 0.3, 0.1), Color(1.0, 1.0, 0.9)],      # yellow
		[Color(0.7, 0.45, 0.95), Color(0.2, 0.1, 0.35), Color(0.95, 0.85, 1.0)],    # violet
		[Color(0.95, 0.95, 0.98), Color(0.4, 0.4, 0.5), Color(1.0, 1.0, 1.0)],      # white
	], v)
	_tube(st, Vector3(0, 0, -0.03), Vector3(0, 0, 0.03), 0.006, 0.004, look[1], 4)
	_ell(st, Vector3(0, 0, 0.038), Vector3(0.009, 0.009, 0.009), look[1], Basis(), 5, 3, 1.0)
	for s in [-1.0, 1.0]:
		_tube(st, Vector3(0.003 * s, 0.003, 0.045), Vector3(0.016 * s, 0.03, 0.07), 0.0015, 0.001, look[1], 3)
	var wing := SurfaceTool.new()
	wing.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wing_tris(wing, [Vector3(0, 0, 0.005), Vector3(0.03, 0, 0.06), Vector3(0.09, 0, 0.06), Vector3(0.1, 0, 0.0), Vector3(0.045, 0, -0.005)], look[0])
	_wing_tris(wing, [Vector3(0, 0, -0.005), Vector3(0.05, 0, -0.01), Vector3(0.08, 0, -0.045), Vector3(0.05, 0, -0.07), Vector3(0.015, 0, -0.04)], look[0].darkened(0.08))
	_wing_tris(wing, [Vector3(0.006, 0.001, 0.01), Vector3(0.035, 0.001, 0.045), Vector3(0.07, 0.001, 0.045), Vector3(0.075, 0.001, 0.015), Vector3(0.04, 0.001, 0.005)], look[2])
	_wing_tris(wing, [Vector3(0.07, 0.001, 0.058), Vector3(0.09, 0.001, 0.06), Vector3(0.1, 0.001, 0.0), Vector3(0.088, 0.001, 0.01)], look[1])
	wing.generate_normals()
	out["wing"] = wing.commit()
	out["wing_at"] = Vector3(0.004, 0.003, 0)
	out["scale"] = 1.5
	if v >= 4:
		out["glow"] = look[0]


static func _dragonfly(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var look: Array = _pick([
		[Color(0.15, 0.7, 0.85), Color(0.7, 0.95, 1.0)],
		[Color(0.9, 0.2, 0.2), Color(1.0, 0.8, 0.7)],
		[Color(0.5, 0.9, 0.2), Color(0.9, 1.0, 0.7)],
		[Color(0.6, 0.3, 0.9), Color(0.9, 0.8, 1.0)],
	], v)
	_tube(st, Vector3(0, 0, -0.14), Vector3(0, 0, 0.03), 0.004, 0.008, look[0], 5)
	_ell(st, Vector3(0, 0, 0.04), Vector3(0.016, 0.014, 0.016), look[0].darkened(0.1), Basis(), 6, 3)
	for s in [-1.0, 1.0]:
		_ell(st, Vector3(0.012 * s, 0.004, 0.05), Vector3(0.009, 0.009, 0.009), Color(0.1, 0.1, 0.15), Basis(), 5, 3, 1.0)
	var wing := SurfaceTool.new()
	wing.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wing_tris(wing, [Vector3(0, 0, 0.012), Vector3(0.1, 0.002, 0.025), Vector3(0.12, 0.003, 0.0), Vector3(0, 0, -0.005)], look[1])
	_wing_tris(wing, [Vector3(0, 0, -0.012), Vector3(0.1, 0.0, -0.005), Vector3(0.11, 0.0, -0.03), Vector3(0, 0, -0.03)], look[1].darkened(0.08))
	wing.generate_normals()
	out["wing"] = wing.commit()
	out["wing_at"] = Vector3(0.006, 0.006, 0.0)
	out["scale"] = 1.4
	if v == 2 or v == 3:
		out["glow"] = look[0]


static func _bird(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var look: Array = _pick([
		[Color(0.55, 0.38, 0.28), Color(0.95, 0.5, 0.25), Color(1.0, 0.75, 0.2)],     # robin
		[Color(0.2, 0.45, 0.9), Color(0.95, 0.95, 1.0), Color(1.0, 0.7, 0.2)],        # bluebird
		[Color(0.95, 0.95, 0.97), Color(0.55, 0.6, 0.68), Color(1.0, 0.75, 0.15)],    # gull
		[Color(0.95, 0.8, 0.2), Color(1.0, 0.95, 0.6), Color(1.0, 0.5, 0.2)],         # canary
		[Color(0.85, 0.25, 0.3), Color(0.95, 0.55, 0.5), Color(1.0, 0.8, 0.3)],       # cardinal
	], v)
	_ell(st, Vector3(0, 0, 0), Vector3(0.05, 0.045, 0.085), look[0])
	_ell(st, Vector3(0, -0.01, 0.015), Vector3(0.04, 0.03, 0.06), look[1], Basis(), 6, 3, 1.0)
	_ell(st, Vector3(0, 0.03, 0.08), Vector3(0.034, 0.034, 0.034), look[0])
	_cone(st, Vector3(0, 0.026, 0.108), Vector3(0, 0.02, 0.145), 0.014, look[2])
	_eyes(st, Vector3(0, 0.04, 0.1), 0.024, 0.007)
	_tri(st, Vector3(-0.015, 0.0, -0.07), Vector3(0.015, 0.0, -0.07), Vector3(0.0, 0.005, -0.17), look[0].darkened(0.15))
	_tri(st, Vector3(-0.015, 0.0, -0.07), Vector3(0.0, 0.005, -0.17), Vector3(-0.05, 0.0, -0.15), look[0].darkened(0.1))
	_tri(st, Vector3(0.015, 0.0, -0.07), Vector3(0.05, 0.0, -0.15), Vector3(0.0, 0.005, -0.17), look[0].darkened(0.1))
	var wing := SurfaceTool.new()
	wing.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wing_tris(wing, [Vector3(0, 0, 0.04), Vector3(0.15, 0.01, 0.03), Vector3(0.2, 0.015, -0.03), Vector3(0.12, 0.0, -0.08), Vector3(0, 0, -0.06)], look[0].lightened(0.05))
	_wing_tris(wing, [Vector3(0.12, 0.011, 0.025), Vector3(0.2, 0.016, -0.03), Vector3(0.17, 0.005, -0.075), Vector3(0.1, 0.002, -0.05)], look[0].darkened(0.3))
	wing.generate_normals()
	out["wing"] = wing.commit()
	out["wing_at"] = Vector3(0.03, 0.02, 0.0)
	out["scale"] = 1.6


static func _bat(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var look: Array = _pick([
		[Color(0.25, 0.2, 0.3), Color(0.45, 0.3, 0.45)],
		[Color(0.35, 0.28, 0.25), Color(0.6, 0.45, 0.4)],
		[Color(0.2, 0.25, 0.4), Color(0.4, 0.5, 0.8)],
		[Color(0.3, 0.2, 0.4), Color(0.7, 0.4, 0.9)],
	], v)
	_ell(st, Vector3(0, 0, 0), Vector3(0.032, 0.03, 0.05), look[0])
	_ell(st, Vector3(0, 0.012, 0.055), Vector3(0.024, 0.022, 0.024), look[0])
	for s in [-1.0, 1.0]:
		_cone(st, Vector3(0.012 * s, 0.03, 0.058), Vector3(0.02 * s, 0.07, 0.054), 0.008, look[0])
		_ell(st, Vector3(0.011 * s, 0.022, 0.075), Vector3(0.005, 0.005, 0.005), Color(1.0, 0.3, 0.3), Basis(), 4, 2, 1.0)
	var wing := SurfaceTool.new()
	wing.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wing_tris(wing, [Vector3(0, 0, 0.03), Vector3(0.08, 0.02, 0.05), Vector3(0.18, 0.04, 0.01), Vector3(0.14, 0.01, -0.025), Vector3(0.09, 0.0, -0.01), Vector3(0.05, 0.0, -0.045), Vector3(0, 0, -0.04)], look[0].darkened(0.1))
	wing.generate_normals()
	out["wing"] = wing.commit()
	out["wing_at"] = Vector3(0.02, 0.01, 0.0)
	out["scale"] = 1.5
	if v == 3:
		out["glow"] = look[1]


static func _fish(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var look: Array = _pick([
		[Color(1.0, 0.55, 0.15), Color(1.0, 0.95, 0.9)],
		[Color(0.25, 0.6, 1.0), Color(0.9, 0.98, 1.0)],
		[Color(1.0, 0.85, 0.2), Color(1.0, 1.0, 0.85)],
		[Color(1.0, 0.45, 0.65), Color(1.0, 0.9, 0.95)],
		[Color(0.3, 0.9, 0.7), Color(0.9, 1.0, 0.95)],
	], v)
	_ell(st, Vector3(0, 0, 0), Vector3(0.026, 0.042, 0.09), look[0], Basis(), 7, 4)
	_ell(st, Vector3(0, -0.012, 0.01), Vector3(0.02, 0.028, 0.075), look[1], Basis(), 6, 3, 1.0)
	_tri(st, Vector3(0, 0.035, 0.03), Vector3(0, 0.085, -0.035), Vector3(0, 0.03, -0.05), look[0].darkened(0.12))
	for s in [-1.0, 1.0]:
		_tri(st, Vector3(0.02 * s, -0.01, 0.03), Vector3(0.05 * s, -0.035, 0.0), Vector3(0.02 * s, -0.02, -0.01), look[0].darkened(0.1))
		_ell(st, Vector3(0.02 * s, 0.01, 0.06), Vector3(0.008, 0.012, 0.012), Color(1, 1, 1), Basis(), 5, 3, 1.0)
		_ell(st, Vector3(0.025 * s, 0.01, 0.063), Vector3(0.005, 0.007, 0.007), Color(0.03, 0.03, 0.05), Basis(), 4, 2, 1.0)
	var tail := SurfaceTool.new()
	tail.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tri(tail, Vector3(0, 0, 0), Vector3(0, 0.06, -0.07), Vector3(0, 0.0, -0.05), look[0].darkened(0.05))
	_tri(tail, Vector3(0, 0, 0), Vector3(0, 0.0, -0.05), Vector3(0, -0.06, -0.07), look[0].darkened(0.1))
	tail.generate_normals()
	out["tail"] = tail.commit()
	out["tail_at"] = Vector3(0, 0, -0.085)
	out["scale"] = 1.5


static func _jelly(st: SurfaceTool, v: int, out: Dictionary) -> void:
	var col: Color = _pick([Color(0.6, 0.8, 1.0), Color(1.0, 0.6, 0.9), Color(0.7, 1.0, 0.85), Color(0.85, 0.7, 1.0)], v)
	_ell(st, Vector3(0, 0.12, 0), Vector3(0.1, 0.08, 0.1), col, Basis(), 9, 4, 0.55)
	_ell(st, Vector3(0, 0.1, 0), Vector3(0.05, 0.04, 0.05), col.lightened(0.4), Basis(), 6, 3, 1.0)
	for k in 7:
		var a := TAU * k / 7.0
		var o := Vector3(cos(a), 0, sin(a))
		_tube(st, o * 0.075 + Vector3(0, 0.08, 0), o * 0.065 + Vector3(0, -0.16 - 0.03 * (k % 3), 0), 0.006, 0.002, col.lightened(0.2), 3)
	out["glow"] = col
	out["scale"] = 2.0
