class_name DecorMesh
extends RefCounted
## Small procedural decorations for the maps: many kinds of flowers, grass, mushrooms, crystals, corals, shells, cacti, pebbles and gears, each in several shapes.
## Vertex colour: rgb is the part's own shade, alpha is a "tint mask": where alpha is 1 the part takes the colour of the instance (see shaders/decor.gdshader),
## so one mesh can be red, yellow or blue. Everything is a few dozen triangles so thousands can be scattered.
## `make(kind, seed)` returns the mesh; `KINDS` lists what exists.

const KINDS := ["daisy", "tulip", "bell", "star", "poppy", "puff", "spike", "tuft", "reed", "mushroom", "mushroom_tall", "crystals", "coral_fan", "coral_branch", "seaweed",
	"starfish", "shell", "cactus", "pebbles", "gear", "shard", "rock", "boulder", "rock_mossy", "boulder_mossy", "rock_snowy", "boulder_snowy", "bush", "stump", "log", "bones", "mound", "fern", "pod", "grave"]

const STEM := Color(0.2, 0.5, 0.18, 0.0)
const LEAF := Color(0.26, 0.6, 0.2, 0.0)


static func make(kind: String, seed_i: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i * 7919 + kind.hash()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"daisy": _bloom(st, rng, "daisy")
		"tulip": _bloom(st, rng, "tulip")
		"bell": _bloom(st, rng, "bell")
		"star": _bloom(st, rng, "star")
		"poppy": _bloom(st, rng, "poppy")
		"puff": _bloom(st, rng, "puff")
		"spike": _spike(st, rng)
		"tuft": _tuft(st, rng, rng.randi_range(7, 12), rng.randf_range(0.22, 0.42), 0.035)
		"reed": _tuft(st, rng, rng.randi_range(4, 7), rng.randf_range(0.7, 1.2), 0.03)
		"mushroom": _mushroom(st, rng, false)
		"mushroom_tall": _mushroom(st, rng, true)
		"crystals": _crystals(st, rng)
		"coral_fan": _fan(st, rng)
		"coral_branch": _branching(st, rng)
		"seaweed": _seaweed(st, rng)
		"starfish": _starfish(st, rng)
		"shell": _shell(st, rng)
		"cactus": _cactus(st, rng)
		"pebbles": _pebbles(st, rng)
		"gear": _gear(st, rng)
		"shard": _shard(st, rng)
		"rock": _rock(st, rng, false)
		"boulder": _rock(st, rng, true)
		"rock_mossy": _rock(st, rng, false, 1)
		"boulder_mossy": _rock(st, rng, true, 1)
		"rock_snowy": _rock(st, rng, false, 2)
		"boulder_snowy": _rock(st, rng, true, 2)
		"bush": _bush(st, rng)
		"stump": _stump(st, rng)
		"log": _log(st, rng)
		"bones": _bones(st, rng)
		"mound": _mound(st, rng)
		"fern": _fern(st, rng)
		"pod": _pod(st, rng)
		"grave": _grave(st, rng)
		_: _tuft(st, rng, 8, 0.3, 0.035)
	st.generate_normals()
	return st.commit()


# ----------------------------------------------------------------- building blocks

static func _v(st: SurfaceTool, p: Vector3, c: Color) -> void:
	st.set_color(c)
	st.add_vertex(p)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color = Color(-1, 0, 0, 0), cc: Color = Color(-1, 0, 0, 0)) -> void:
	if cb.r < 0.0:
		cb = ca
	if cc.r < 0.0:
		cc = ca
	_v(st, a, ca)
	_v(st, b, cb)
	_v(st, c, cc)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri(st, a, b, c, ca, cb, cc)
	_tri(st, a, c, d, ca, cc, cd)


static func _grey(v: float, mask: float = 1.0) -> Color:
	return Color(v, v, v, mask)


## A tapered, slightly bent stem from the ground up to `h`, three-sided. Returns the top point.
static func _stem(st: SurfaceTool, rng: RandomNumberGenerator, h: float, r0: float, r1: float, bend: Vector2, col: Color = STEM) -> Vector3:
	var prev: Array = []
	var top := Vector3.ZERO
	for i in 4:
		var t := float(i) / 3.0
		var c := Vector3(bend.x * t * t, h * t, bend.y * t * t)
		var r := lerpf(r0, r1, t)
		var ring: Array = []
		for k in 3:
			var a := TAU * k / 3.0
			ring.append(c + Vector3(cos(a) * r, 0, sin(a) * r))
		var shade := col.lightened(0.12 * t)
		if not prev.is_empty():
			for k in 3:
				var k2 := (k + 1) % 3
				_quad(st, prev[k], prev[k2], ring[k2], ring[k], col.lightened(0.12 * (t - 0.33)), col.lightened(0.12 * (t - 0.33)), shade, shade)
		prev = ring
		top = c
	return top


static func _leaf(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, width: float, lift: float, col: Color = LEAF) -> void:
	var side := dir.cross(Vector3.UP).normalized() * width * 0.5
	var mid := base + dir * length * 0.5 + Vector3(0, lift * length * 0.5, 0)
	var tip := base + dir * length + Vector3(0, lift * length * 0.4, 0)
	var dark := col.darkened(0.25)
	_tri(st, base, mid + side, mid - side, dark, col, col)
	_tri(st, mid + side, tip, mid - side, col, col.lightened(0.15), col)


## A petal: a diamond from `base` along `dir` (unit, horizontal part) lifted by `lift`, `length` long and `width` wide at the middle.
static func _petal(st: SurfaceTool, base: Vector3, dir: Vector3, up: float, length: float, width: float, shade_in: float = 0.75, shade_out: float = 1.0) -> void:
	var d := (dir + Vector3(0, up, 0)).normalized()
	var side := Vector3(-dir.z, 0, dir.x).normalized() * width * 0.5
	var mid := base + d * length * 0.5
	var tip := base + d * length + Vector3(0, up * 0.05, 0)
	_tri(st, base, mid + side, mid - side, _grey(shade_in), _grey((shade_in + shade_out) * 0.5), _grey((shade_in + shade_out) * 0.5))
	_tri(st, mid + side, tip, mid - side, _grey((shade_in + shade_out) * 0.5), _grey(shade_out), _grey((shade_in + shade_out) * 0.5))


static func _disc(st: SurfaceTool, c: Vector3, r: float, sides: int, col: Color, dome: float = 0.0) -> void:
	var top := c + Vector3(0, dome, 0)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		_tri(st, top, c + Vector3(cos(a0) * r, 0, sin(a0) * r), c + Vector3(cos(a1) * r, 0, sin(a1) * r), col.lightened(0.1), col, col)


# ----------------------------------------------------------------- flowers

static func _bloom(st: SurfaceTool, rng: RandomNumberGenerator, style: String) -> void:
	var h := rng.randf_range(0.28, 0.55)
	var lean := Vector2(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.07, 0.07))
	var top := _stem(st, rng, h, 0.012, 0.007, lean)
	for i in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		_leaf(st, Vector3(0, h * rng.randf_range(0.0, 0.25), 0), Vector3(cos(a), 0, sin(a)), rng.randf_range(0.1, 0.18), rng.randf_range(0.03, 0.05), rng.randf_range(0.2, 0.6))
	var yellow := Color(0.95, 0.78, 0.2, 0.0)
	match style:
		"daisy":
			var n := rng.randi_range(10, 16)
			var l := rng.randf_range(0.07, 0.1)
			for k in n:
				var a := TAU * k / n + rng.randf_range(-0.05, 0.05)
				_petal(st, top + Vector3(cos(a), 0, sin(a)) * 0.015, Vector3(cos(a), 0, sin(a)), 0.18, l, 0.032)
			_disc(st, top + Vector3(0, 0.004, 0), 0.028, 8, yellow, 0.014)
		"tulip":
			var n := rng.randi_range(5, 7)
			var ph := rng.randf() * TAU
			for k in n:
				var a := ph + TAU * k / n
				var o := Vector3(cos(a), 0, sin(a))
				var b := top
				var m := top + o * 0.045 + Vector3(0, 0.05, 0)
				var t := top + o * 0.025 + Vector3(0, 0.11, 0)
				var side := Vector3(-o.z, 0, o.x) * 0.026
				_tri(st, b, m + side, m - side, _grey(0.7), _grey(0.88), _grey(0.88))
				_tri(st, m + side, t, m - side, _grey(0.88), _grey(1.0), _grey(0.88))
		"bell":
			var n := rng.randi_range(5, 7)
			var drop := rng.randf_range(0.07, 0.11)
			for k in n:
				var a0 := TAU * k / n
				var a1 := TAU * (k + 1) / n
				var r1 := 0.07
				var p0 := top + Vector3(cos(a0) * r1, -drop, sin(a0) * r1)
				var p1 := top + Vector3(cos(a1) * r1, -drop, sin(a1) * r1)
				var m0 := top + Vector3(cos(a0) * 0.04, -drop * 0.5, sin(a0) * 0.04)
				var m1 := top + Vector3(cos(a1) * 0.04, -drop * 0.5, sin(a1) * 0.04)
				_quad(st, top, m0, m1, top, _grey(0.7), _grey(0.8), _grey(0.8), _grey(0.7))
				_quad(st, m0, p0, p1, m1, _grey(0.8), _grey(1.0), _grey(1.0), _grey(0.8))
		"star":
			var n := rng.randi_range(5, 6)
			var ph := rng.randf() * TAU
			var l := rng.randf_range(0.07, 0.1)
			for k in n:
				var a := ph + TAU * k / n
				_petal(st, top, Vector3(cos(a), 0, sin(a)), 0.12, l, 0.05, 0.8, 1.0)
			_disc(st, top + Vector3(0, 0.005, 0), 0.02, 6, yellow, 0.01)
		"poppy":
			var n := 4
			var ph := rng.randf() * TAU
			for k in n:
				var a := ph + TAU * k / n
				_petal(st, top, Vector3(cos(a), 0, sin(a)), 0.45, 0.09, 0.09, 0.8, 1.0)
			_disc(st, top + Vector3(0, 0.01, 0), 0.02, 7, Color(0.18, 0.1, 0.22, 0.0), 0.012)
		"puff":
			var r := rng.randf_range(0.05, 0.08)
			var pts: Array = []
			for k in 6:
				var a := TAU * k / 6.0
				pts.append(top + Vector3(cos(a) * r, r * 0.35, sin(a) * r))
			var apex := top + Vector3(0, r * 1.2, 0)
			var low := top + Vector3(0, -r * 0.2, 0)
			for k in 6:
				var k2 := (k + 1) % 6
				_tri(st, apex, pts[k], pts[k2], _grey(1.0), _grey(0.82), _grey(0.82))
				_tri(st, low, pts[k2], pts[k], _grey(0.62), _grey(0.78), _grey(0.78))


static func _spike(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(0.45, 0.8)
	var top := _stem(st, rng, h, 0.012, 0.008, Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05)))
	for i in 2:
		var a := rng.randf() * TAU
		_leaf(st, Vector3(0, 0.02, 0), Vector3(cos(a), 0, sin(a)), 0.2, 0.025, 0.5)
	var n := rng.randi_range(9, 14)
	for k in n:
		var t := float(k) / n
		var y := h * (0.45 + 0.55 * t)
		var a := k * 2.4
		var r := 0.035 * (1.0 - t * 0.6)
		var c := Vector3(0, y, 0) + Vector3(cos(a), 0, sin(a)) * 0.012 + Vector3(top.x, 0, top.z) * (y / h) * (y / h)
		var s := r
		var up := c + Vector3(0, s * 1.4, 0)
		var dn := c - Vector3(0, s * 0.6, 0)
		var ring: Array = []
		for q in 4:
			var qa := TAU * q / 4.0 + a
			ring.append(c + Vector3(cos(qa) * s, 0, sin(qa) * s))
		for q in 4:
			var q2 := (q + 1) % 4
			_tri(st, up, ring[q], ring[q2], _grey(1.0), _grey(0.85), _grey(0.85))
			_tri(st, dn, ring[q2], ring[q], _grey(0.65), _grey(0.8), _grey(0.8))


# ----------------------------------------------------------------- grass, mushrooms, crystals

static func _tuft(st: SurfaceTool, rng: RandomNumberGenerator, blades: int, height: float, width: float) -> void:
	for k in blades:
		var a := rng.randf() * TAU
		var o := Vector3(cos(a), 0, sin(a))
		var r0 := rng.randf_range(0.0, 0.05)
		var base := o * r0
		var hh := height * rng.randf_range(0.6, 1.1)
		var lean := rng.randf_range(0.05, 0.4) * hh
		var side := Vector3(-o.z, 0, o.x) * width * rng.randf_range(0.7, 1.2)
		var m := base + o * lean * 0.35 + Vector3(0, hh * 0.55, 0)
		var tip := base + o * lean + Vector3(0, hh, 0)
		_tri(st, base - side, base + side, m - side * 0.7, _grey(0.55), _grey(0.55), _grey(0.8))
		_tri(st, base + side, m + side * 0.7, m - side * 0.7, _grey(0.55), _grey(0.8), _grey(0.8))
		_tri(st, m - side * 0.7, m + side * 0.7, tip, _grey(0.8), _grey(0.8), _grey(1.0))


static func _mushroom(st: SurfaceTool, rng: RandomNumberGenerator, tall: bool) -> void:
	var n := rng.randi_range(1, 3) if not tall else 1
	for m in n:
		var off := Vector3(rng.randf_range(-0.09, 0.09), 0, rng.randf_range(-0.09, 0.09)) if m > 0 else Vector3.ZERO
		var sh := rng.randf_range(0.08, 0.16) * (2.2 if tall else 1.0) * (1.0 - 0.25 * m)
		var cap_r := rng.randf_range(0.06, 0.11) * (0.8 if tall else 1.0) * (1.0 - 0.2 * m)
		var cap_h := cap_r * rng.randf_range(0.45, 0.8)
		var stem_c := Color(0.92, 0.88, 0.76, 0.0)
		var stem_r := cap_r * 0.28
		var sides := 7
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var b0 := off + Vector3(cos(a0) * stem_r, 0, sin(a0) * stem_r)
			var b1 := off + Vector3(cos(a1) * stem_r, 0, sin(a1) * stem_r)
			var t0 := b0 + Vector3(0, sh, 0)
			var t1 := b1 + Vector3(0, sh, 0)
			_quad(st, b0, b1, t1, t0, stem_c.darkened(0.2), stem_c.darkened(0.2), stem_c, stem_c)
			# the cap: two rings
			var r_mid := cap_r * 0.92
			var m0 := off + Vector3(cos(a0) * r_mid, sh + cap_h * 0.55, sin(a0) * r_mid)
			var m1 := off + Vector3(cos(a1) * r_mid, sh + cap_h * 0.55, sin(a1) * r_mid)
			var e0 := off + Vector3(cos(a0) * cap_r, sh, sin(a0) * cap_r)
			var e1 := off + Vector3(cos(a1) * cap_r, sh, sin(a1) * cap_r)
			var apex := off + Vector3(0, sh + cap_h, 0)
			_quad(st, e0, e1, m1, m0, _grey(0.7), _grey(0.7), _grey(0.92), _grey(0.92))
			_tri(st, m0, m1, apex, _grey(0.92), _grey(0.92), _grey(1.0))
			# the underside
			_tri(st, e1, e0, off + Vector3(0, sh - 0.004, 0), Color(0.55, 0.45, 0.35, 0.0), Color(0.55, 0.45, 0.35, 0.0), Color(0.7, 0.6, 0.5, 0.0))
		if rng.randf() < 0.6:
			for s in rng.randi_range(3, 6):
				var a := rng.randf() * TAU
				var rr := rng.randf_range(0.2, 0.7) * cap_r
				var c := off + Vector3(cos(a) * rr, sh + cap_h * (1.0 - rr / cap_r * 0.7) + 0.003, sin(a) * rr)
				_disc(st, c, cap_r * 0.13, 5, Color(0.97, 0.95, 0.9, 0.0), 0.004)


static func _crystals(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(3, 6)
	for k in n:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.09) if k > 0 else 0.0
		var base := Vector3(cos(a) * d, 0, sin(a) * d)
		var h := rng.randf_range(0.12, 0.34) * (1.0 if k > 0 else 1.4)
		var r := rng.randf_range(0.02, 0.045)
		var tilt := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)) * h
		var ring: Array = []
		for q in 6:
			var qa := TAU * q / 6.0
			ring.append(base + Vector3(cos(qa) * r, 0, sin(qa) * r))
		var shoulder: Array = []
		for q in 6:
			var qa := TAU * q / 6.0
			shoulder.append(base + Vector3(cos(qa) * r * 0.9, h * 0.7, sin(qa) * r * 0.9) + tilt * 0.7)
		var tip := base + Vector3(0, h, 0) + tilt
		for q in 6:
			var q2 := (q + 1) % 6
			_quad(st, ring[q], ring[q2], shoulder[q2], shoulder[q], _grey(0.55), _grey(0.55), _grey(0.85), _grey(0.85))
			_tri(st, shoulder[q], shoulder[q2], tip, _grey(0.85), _grey(0.85), _grey(1.0))


# ----------------------------------------------------------------- the sea

static func _fan(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(6, 9)
	var h := rng.randf_range(0.25, 0.45)
	var spread := rng.randf_range(1.0, 1.5)
	_tri(st, Vector3(-0.02, 0, 0), Vector3(0.02, 0, 0), Vector3(0, 0.05, 0), _grey(0.5), _grey(0.5), _grey(0.7))
	for k in n:
		var a := (float(k) / (n - 1) - 0.5) * spread
		var dir := Vector3(sin(a), cos(a), 0)
		var base := Vector3(0, 0.04, 0)
		var w := 0.022
		var tip := base + dir * h * rng.randf_range(0.8, 1.0)
		var mid := base + dir * h * 0.5
		var side := Vector3(0, 0, w)
		_tri(st, base, mid + side, mid - side, _grey(0.6), _grey(0.85), _grey(0.85))
		_tri(st, mid + side, tip, mid - side, _grey(0.85), _grey(1.0), _grey(0.85))
		# cross-links
		if k > 0:
			var pa := (float(k - 1) / (n - 1) - 0.5) * spread
			var pm := base + Vector3(sin(pa), cos(pa), 0) * h * 0.55
			var cm := base + dir * h * 0.55
			_quad(st, pm, cm, cm + Vector3(0, 0.012, 0), pm + Vector3(0, 0.012, 0), _grey(0.8), _grey(0.8), _grey(0.8), _grey(0.8))


static func _branching(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	_branch(st, rng, Vector3.ZERO, Vector3(rng.randf_range(-0.2, 0.2), 1, rng.randf_range(-0.2, 0.2)).normalized(), rng.randf_range(0.18, 0.28), 0.024, 3)


static func _branch(st: SurfaceTool, rng: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, r: float, depth: int) -> void:
	var to := from + dir * length
	var side := dir.cross(Vector3.RIGHT).normalized() * r
	if side.length() < 0.001:
		side = dir.cross(Vector3.FORWARD).normalized() * r
	var side2 := dir.cross(side).normalized() * r
	var r2 := r * 0.7
	var b: Array = [from + side, from + side2, from - side - side2]
	var t: Array = [to + side * 0.7, to + side2 * 0.7, to - (side + side2) * 0.7]
	for k in 3:
		var k2 := (k + 1) % 3
		_quad(st, b[k], b[k2], t[k2], t[k], _grey(0.6 + 0.1 * (3 - depth)), _grey(0.6 + 0.1 * (3 - depth)), _grey(0.85), _grey(0.85))
	if depth <= 0:
		_tri(st, t[0], t[1], to + dir * r * 2.5, _grey(1.0), _grey(1.0), _grey(1.0))
		return
	for i in rng.randi_range(2, 3):
		var nd := (dir + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.0, 0.5), rng.randf_range(-0.7, 0.7))).normalized()
		_branch(st, rng, to, nd, length * rng.randf_range(0.6, 0.8), r2, depth - 1)


static func _seaweed(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for blade in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var o := Vector3(cos(a), 0, sin(a))
		var base := o * rng.randf_range(0.0, 0.08)
		var h := rng.randf_range(0.5, 1.1)
		var side := Vector3(-o.z, 0, o.x) * 0.035
		var prev_l := base - side
		var prev_r := base + side
		for i in range(1, 6):
			var t := float(i) / 5.0
			var c := base + Vector3(0, h * t, 0) + o * sin(t * 4.0 + a) * 0.07 * t
			var w := 1.0 - t * 0.85
			var l := c - side * w
			var r := c + side * w
			var c0 := _grey(0.55 + 0.45 * float(i - 1) / 5.0)
			var c1 := _grey(0.55 + 0.45 * t)
			_quad(st, prev_l, prev_r, r, l, c0, c0, c1, c1)
			prev_l = l
			prev_r = r


static func _starfish(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(0.07, 0.11)
	var ph := rng.randf() * TAU
	var centre := Vector3(0, 0.022, 0)
	for k in 5:
		var a0 := ph + TAU * k / 5.0
		var a1 := ph + TAU * (k + 0.5) / 5.0
		var a2 := ph + TAU * (k + 1) / 5.0
		var tip := Vector3(cos(a0) * r, 0.006, sin(a0) * r)
		var v1 := Vector3(cos(a1) * r * 0.38, 0.016, sin(a1) * r * 0.38)
		var v0 := Vector3(cos(a0 - 0.5) * r * 0.38, 0.016, sin(a0 - 0.5) * r * 0.38)
		_tri(st, centre, v0, tip, _grey(1.0), _grey(0.8), _grey(0.7))
		_tri(st, centre, tip, v1, _grey(1.0), _grey(0.7), _grey(0.8))
		if a2 > 100.0:
			pass


static func _shell(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(0.05, 0.1)
	var ribs := rng.randi_range(7, 11)
	var apex := Vector3(0, 0.006, -r * 0.2)
	var yaw := rng.randf_range(-0.4, 0.4)
	for k in ribs:
		var a0 := lerpf(-1.1, 1.1, float(k) / ribs) + yaw
		var a1 := lerpf(-1.1, 1.1, float(k + 1) / ribs) + yaw
		var p0 := Vector3(sin(a0) * r, r * 0.2 * (0.6 + 0.4 * (k % 2)), cos(a0) * r * 0.9)
		var p1 := Vector3(sin(a1) * r, r * 0.2 * (0.6 + 0.4 * ((k + 1) % 2)), cos(a1) * r * 0.9)
		_tri(st, apex, p0, p1, _grey(0.7), _grey(1.0 - 0.2 * (k % 2)), _grey(1.0 - 0.2 * ((k + 1) % 2)))
		_tri(st, apex, p1, p0, _grey(0.5), _grey(0.7), _grey(0.7))


static func _cactus(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(0.45, 0.9)
	var r := rng.randf_range(0.05, 0.09)
	_column(st, Vector3.ZERO, Vector3(0, h, 0), r, r * 0.75, 8)
	for i in rng.randi_range(0, 2):
		var a := rng.randf() * TAU
		var o := Vector3(cos(a), 0, sin(a))
		var y := h * rng.randf_range(0.35, 0.6)
		var out := o * (r + 0.1)
		_column(st, Vector3(0, y, 0) + o * r * 0.5, Vector3(0, y, 0) + out, r * 0.5, r * 0.45, 6)
		_column(st, Vector3(0, y, 0) + out, Vector3(0, y + rng.randf_range(0.15, 0.3), 0) + out, r * 0.45, r * 0.38, 6)
	# a little flower on top
	var fc := Color(0.95, 0.4, 0.5, 0.0)
	_disc(st, Vector3(0, h, 0), r * 0.5, 6, fc, r * 0.4)


static func _column(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides: int) -> void:
	var dir := (b - a).normalized()
	var u := dir.cross(Vector3.UP)
	if u.length() < 0.01:
		u = dir.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := dir.cross(u).normalized()
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := a + (u * cos(a0) + v * sin(a0)) * r0
		var p1 := a + (u * cos(a1) + v * sin(a1)) * r0
		var q0 := b + (u * cos(a0) + v * sin(a0)) * r1
		var q1 := b + (u * cos(a1) + v * sin(a1)) * r1
		var s := 0.82 + 0.18 * float(k % 2)
		_quad(st, p0, p1, q1, q0, _grey(s * 0.6), _grey(s * 0.6), _grey(s), _grey(s))
	_disc(st, b, r1, sides, _grey(1.0), r1 * 0.3)


static func _pebbles(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for k in rng.randi_range(3, 6):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.14)
		var c := Vector3(cos(a) * d, 0, sin(a) * d)
		var r := rng.randf_range(0.03, 0.08)
		var pts: Array = []
		for q in 6:
			var qa := TAU * q / 6.0 + rng.randf_range(-0.2, 0.2)
			pts.append(c + Vector3(cos(qa) * r * rng.randf_range(0.8, 1.2), r * 0.35, sin(qa) * r * rng.randf_range(0.8, 1.2)))
		var apex := c + Vector3(rng.randf_range(-0.01, 0.01), r * rng.randf_range(0.7, 1.0), rng.randf_range(-0.01, 0.01))
		var shade := rng.randf_range(0.55, 1.0)
		for q in 6:
			var q2 := (q + 1) % 6
			_tri(st, apex, pts[q], pts[q2], _grey(shade), _grey(shade * 0.7), _grey(shade * 0.7))
			_tri(st, c + Vector3(0, -0.005, 0), pts[q2], pts[q], _grey(shade * 0.5))


static func _gear(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var teeth := rng.randi_range(8, 14)
	var r := rng.randf_range(0.12, 0.26)
	var th := rng.randf_range(0.03, 0.05)
	var tilt := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
	var basis := Basis(Vector3(1, 0, 0), tilt.x) * Basis(Vector3(0, 0, 1), tilt.z)
	var lift := Vector3(0, r * 0.35, 0)
	var ring: Array = []
	for k in teeth:
		var a := TAU * k / teeth
		var step := TAU / teeth
		var radii := [r * 0.82, r * 0.82, r, r]
		var offs := [0.0, 0.3, 0.38, 0.62]
		for q in 4:
			var aa: float = a + step * (float(offs[q]) + (0.0 if q < 3 else 0.0))
			ring.append(Vector3(cos(aa) * float(radii[q]), 0, sin(aa) * float(radii[q])))
	var n := ring.size()
	for i in n:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i + 1) % n]
		var t0 := basis * (p0 + Vector3(0, th, 0)) + lift
		var t1 := basis * (p1 + Vector3(0, th, 0)) + lift
		var b0 := basis * p0 + lift
		var b1 := basis * p1 + lift
		var c_top := basis * Vector3(0, th, 0) + lift
		_quad(st, b0, b1, t1, t0, _grey(0.55), _grey(0.55), _grey(0.8), _grey(0.8))
		_tri(st, c_top, t0, t1, _grey(1.0), _grey(0.9), _grey(0.9))


static func _shard(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for k in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.1)
		var base := Vector3(cos(a) * d, 0, sin(a) * d)
		var h := rng.randf_range(0.15, 0.4)
		var w := rng.randf_range(0.03, 0.06)
		var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		var tip := base + Vector3(0, h, 0) + lean
		var p: Array = [base + Vector3(w, 0, 0), base + Vector3(-w * 0.4, 0, w), base + Vector3(-w * 0.6, 0, -w)]
		for q in 3:
			var q2 := (q + 1) % 3
			_tri(st, p[q], p[q2], tip, _grey(0.5), _grey(0.5), _grey(1.0))


# ----------------------------------------------------------------- rocks, bushes, logs and the like

## A rough dome sitting on the ground (rx wide, ry high): the base of a rock, a bush or a mound. Shade goes from `lo` at the foot to `hi` at the top.
static func _blob(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, rx: float, ry: float, sides: int, rings: int, jitter: float, lo: float, hi: float, mask: float = 1.0, rz: float = -1.0) -> void:
	if rz < 0.0:
		rz = rx
	var grid: Array = []
	for i in rings:
		var lat := (PI * 0.5) * float(i) / float(rings)
		var ring: Array = []
		for k in sides:
			var a := TAU * k / sides + rng.randf_range(-0.15, 0.15)
			var j := 1.0 + rng.randf_range(-jitter, jitter)
			ring.append(c + Vector3(cos(a) * cos(lat) * rx * j, sin(lat) * ry * (1.0 + rng.randf_range(-jitter, jitter) * 0.6), sin(a) * cos(lat) * rz * j))
		grid.append(ring)
	var apex := c + Vector3(rng.randf_range(-0.02, 0.02) * rx, ry, rng.randf_range(-0.02, 0.02) * rz)
	for i in rings - 1:
		var t0 := lerpf(lo, hi, float(i) / float(rings))
		var t1 := lerpf(lo, hi, float(i + 1) / float(rings))
		for k in sides:
			var k2 := (k + 1) % sides
			var f := rng.randf_range(0.9, 1.08)
			_quad(st, grid[i][k], grid[i][k2], grid[i + 1][k2], grid[i + 1][k], _grey(t0 * f, mask), _grey(t0 * f, mask), _grey(t1 * f, mask), _grey(t1 * f, mask))
	for k in sides:
		var k2 := (k + 1) % sides
		var f := rng.randf_range(0.92, 1.1)
		var t := lerpf(lo, hi, float(rings - 1) / float(rings))
		_tri(st, grid[rings - 1][k], grid[rings - 1][k2], apex, _grey(t * f, mask), _grey(t * f, mask), _grey(hi * f, mask))


static var _ico: Dictionary = {}


## A sphere made of triangles (an icosahedron split `level` times: 80, 320...): [vertices (unit vectors), faces (three indices each)].
static func _icosphere(level: int) -> Array:
	if _ico.has(level):
		return _ico[level]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in v.size():
		v[i] = (v[i] as Vector3).normalized()
	var f: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6],
		[3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for _l in level:
		var mids := {}
		var faces: Array = []
		for tri in f:
			var m: Array = []
			for e in 3:
				var a: int = tri[e]
				var b: int = tri[(e + 1) % 3]
				var key := mini(a, b) * 100000 + maxi(a, b)
				if not mids.has(key):
					v.append(((v[a] as Vector3) + (v[b] as Vector3)).normalized())
					mids[key] = v.size() - 1
				m.append(mids[key])
			faces.append([tri[0], m[0], m[2]])
			faces.append([tri[1], m[1], m[0]])
			faces.append([tri[2], m[2], m[1]])
			faces.append([m[0], m[1], m[2]])
		f = faces
	_ico[level] = [v, f]
	return _ico[level]


## One chunky, faceted stone sitting on the ground at `c` (size = its three radii). Lit from above, darker at the foot; `cap` 1 puts moss on its top, 2 snow.
static func _stone(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, size: Vector3, cap: int, level: int = 1) -> void:
	var ico := _icosphere(level)
	var verts: Array = ico[0]
	var faces: Array = ico[1]
	var nz := FastNoiseLite.new()
	nz.seed = rng.randi()
	nz.frequency = 1.0
	# a few flat cuts, like the faces a real rock breaks along
	var cuts: Array = []
	for i in rng.randi_range(3, 6):
		var nv := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1.0), rng.randf_range(-1, 1)).normalized()
		cuts.append([nv, rng.randf_range(0.6, 0.88)])
	var pts: Array = []
	for d in verts:
		var dv: Vector3 = d
		var n1 := nz.get_noise_3d(dv.x * 1.5, dv.y * 1.5, dv.z * 1.5)
		var n2 := nz.get_noise_3d(dv.x * 5.0 + 9.0, dv.y * 5.0, dv.z * 5.0)
		var p := dv * (1.0 + 0.3 * n1 + 0.07 * n2)
		for cut in cuts:
			var over := p.dot(cut[0]) - float(cut[1])
			if over > 0.0:
				p -= (cut[0] as Vector3) * over
		p = Vector3(p.x * size.x, maxf(p.y * size.y, -size.y * 0.3), p.z * size.z)
		pts.append(p + c + Vector3(0, size.y * 0.3 - 0.02, 0))
	for fc in faces:
		var a: Vector3 = pts[fc[0]]
		var b: Vector3 = pts[fc[1]]
		var cc: Vector3 = pts[fc[2]]
		var nrm := (b - a).cross(cc - a).normalized()
		var mid := (a + b + cc) / 3.0
		var light := 0.5 + 0.5 * clampf(nrm.y * 0.6 + 0.4, 0.0, 1.0)
		# patchy shade, thin darker strata, darker toward the foot
		light *= (0.86 + 0.28 * (nz.get_noise_3d(mid.x * 9.0, mid.y * 9.0, mid.z * 9.0) * 0.5 + 0.5)) * (0.94 + 0.06 * sin((mid.y - c.y) / size.y * 22.0))
		light *= rng.randf_range(0.95, 1.05) * lerpf(0.66, 1.0, smoothstep(-size.y * 0.3, size.y * 0.5, mid.y - c.y))
		var col := _grey(light, 1.0)
		if cap == 1 and nrm.y > 0.7 and nz.get_noise_3d(mid.x * 3.0 + 4.0, mid.y * 3.0, mid.z * 3.0) > -0.15:
			col = Color(0.34 * light, 0.46 * light, 0.22 * light, 0.0)
		elif cap == 2 and nrm.y > 0.5:
			var s := minf(1.0, light + 0.12)
			col = Color(0.9 * s, 0.94 * s, 1.0 * s, 0.0)
		_tri(st, a, b, cc, col)


static func _rock(st: SurfaceTool, rng: RandomNumberGenerator, big: bool, cap: int = 0) -> void:
	var r := rng.randf_range(0.14, 0.24) if not big else rng.randf_range(0.45, 0.7)
	var shape := rng.randi() % 4
	var size := Vector3(r, r * 0.8, r * 0.9)
	match shape:
		1: size = Vector3(r * 0.7, r * 1.25, r * 0.75)       # a tall one
		2: size = Vector3(r * 1.4, r * 0.5, r * 1.1)         # a flat slab
		3: size = Vector3(r * 1.1, r * 0.9, r * 0.8)
	_stone(st, rng, Vector3.ZERO, size * Vector3(rng.randf_range(0.9, 1.1), 1.0, rng.randf_range(0.9, 1.1)), cap, 2)
	# smaller stones leaning on it
	for k in rng.randi_range(1, 3) if not big else rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.9, 1.6)
		var s := r * rng.randf_range(0.25, 0.5)
		_stone(st, rng, Vector3(cos(a) * d, 0.0, sin(a) * d), Vector3(s * rng.randf_range(0.8, 1.3), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.2)), cap if rng.randf() < 0.6 else 0)


static func _bush(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for k in rng.randi_range(3, 5):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.04, 0.2) if k > 0 else 0.0
		var r := rng.randf_range(0.14, 0.24)
		_blob(st, rng, Vector3(cos(a) * d, -0.02, sin(a) * d), r, r * rng.randf_range(0.7, 1.0), 7, 3, 0.14, 0.55, 1.0)
	# a few little berries or buds in the leaves
	for b in rng.randi_range(0, 5):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.05, 0.25)
		_disc(st, Vector3(cos(a) * d, rng.randf_range(0.08, 0.22), sin(a) * d), 0.022, 5, Color(0.95, 0.35, 0.4, 0.0), 0.02)


static func _stump(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(0.14, 0.34)
	var r := rng.randf_range(0.09, 0.17)
	var bark := Color(0.36, 0.25, 0.16, 0.0)
	var sides := 8
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var b0 := Vector3(cos(a0) * r * 1.2, -0.02, sin(a0) * r * 1.2)
		var b1 := Vector3(cos(a1) * r * 1.2, -0.02, sin(a1) * r * 1.2)
		var t0 := Vector3(cos(a0) * r, h, sin(a0) * r)
		var t1 := Vector3(cos(a1) * r, h, sin(a1) * r)
		var s := 0.8 + 0.2 * float(k % 2)
		_quad(st, b0, b1, t1, t0, bark.darkened(0.25), bark.darkened(0.25), bark.lightened(0.05 * s), bark.lightened(0.05 * s))
		_tri(st, Vector3(0, h, 0), t0, t1, Color(0.8, 0.62, 0.4, 0.0), Color(0.7, 0.52, 0.32, 0.0), Color(0.7, 0.52, 0.32, 0.0))
		_tri(st, Vector3(0, h + 0.004, 0), t0 * 0.55 + Vector3(0, 0.004, 0), t1 * 0.55 + Vector3(0, 0.004, 0), Color(0.62, 0.45, 0.28, 0.0))
	# a root and a little shelf fungus or moss
	for q in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x) * r * 0.25
		_tri(st, dir * r * 0.9 + side + Vector3(0, h * 0.35, 0), dir * r * 0.9 - side + Vector3(0, h * 0.35, 0), dir * r * 1.9 + Vector3(0, -0.02, 0), bark, bark, bark.darkened(0.3))
	if rng.randf() < 0.6:
		_blob(st, rng, Vector3(r * 0.4, h - 0.01, r * 0.2), r * 0.45, r * 0.18, 6, 2, 0.15, 0.7, 1.0, 1.0)


static func _cap(st: SurfaceTool, c: Vector3, u: Vector3, v: Vector3, r: float, sides: int, col: Color) -> void:
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		_tri(st, c, c + (u * cos(a0) + v * sin(a0)) * r, c + (u * cos(a1) + v * sin(a1)) * r, col.lightened(0.12), col, col)


static func _log(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var length := rng.randf_range(0.5, 0.9)
	var r := rng.randf_range(0.05, 0.09)
	var y := r * 0.8
	var a := Vector3(-length * 0.5, y, 0)
	var b := Vector3(length * 0.5, y + rng.randf_range(-0.02, 0.05), rng.randf_range(-0.04, 0.04))
	var bark := Color(0.34, 0.24, 0.15, 0.0)
	var sides := 7
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := a + Vector3(0, cos(a0), sin(a0)) * r
		var p1 := a + Vector3(0, cos(a1), sin(a1)) * r
		var q0 := b + Vector3(0, cos(a0), sin(a0)) * r * 0.9
		var q1 := b + Vector3(0, cos(a1), sin(a1)) * r * 0.9
		var s := 0.8 + 0.2 * float(k % 2) + 0.2 * (cos(a0) * 0.5 + 0.5)
		_quad(st, p0, p1, q1, q0, bark.lightened(0.04 * s), bark.lightened(0.04 * s), bark.lightened(0.06 * s), bark.lightened(0.06 * s))
	_cap(st, b, Vector3(0, 1, 0), Vector3(0, 0, 1), r * 0.9, sides, Color(0.75, 0.58, 0.38, 0.0))
	_cap(st, a, Vector3(0, 1, 0), Vector3(0, 0, 1), r, sides, Color(0.7, 0.53, 0.34, 0.0))
	# a stub of a branch and some moss on top
	var m := Vector3(rng.randf_range(-0.1, 0.1), y + r * 0.9, 0)
	_column(st, m, m + Vector3(rng.randf_range(-0.04, 0.04), 0.1, rng.randf_range(-0.1, 0.1)), r * 0.35, r * 0.25, 5)
	if rng.randf() < 0.7:
		_blob(st, rng, Vector3(rng.randf_range(-0.2, 0.2), y + r * 0.55, 0), r * 1.2, r * 0.5, 6, 2, 0.15, 0.6, 1.0, 1.0, r * 0.9)


static func _bones(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var bone := Color(0.9, 0.86, 0.74, 0.0)
	for k in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var o := Vector3(rng.randf_range(-0.12, 0.12), 0.012, rng.randf_range(-0.12, 0.12))
		var d := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.08, 0.16)
		_bone_col(st, o - d, o + d, 0.012, bone)
		_blob(st, rng, o + d, 0.022, 0.018, 5, 2, 0.1, 0.8, 1.0, 0.0)
		_blob(st, rng, o - d, 0.022, 0.018, 5, 2, 0.1, 0.8, 1.0, 0.0)
	if rng.randf() < 0.6:
		# a few ribs: little arches
		var o := Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
		var a := rng.randf() * TAU
		var along := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-along.z, 0, along.x)
		for i in rng.randi_range(3, 5):
			var base := o + along * (0.045 * i)
			var prev := base
			for s in 4:
				var t := float(s + 1) / 4.0
				var p := base + side * (sin(t * PI * 0.6) * 0.08) + Vector3(0, sin(t * PI * 0.8) * 0.07, 0)
				_bone_col(st, prev, p, 0.008, bone)
				prev = p
	if rng.randf() < 0.55:
		var c := Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
		_blob(st, rng, c, 0.06, 0.07, 6, 3, 0.08, 0.75, 1.0, 0.0, 0.055)
		var look := rng.randf() * TAU
		for e in [-1.0, 1.0]:
			var ep := c + Vector3(cos(look) * 0.04 - sin(look) * 0.022 * e, 0.042, sin(look) * 0.04 + cos(look) * 0.022 * e)
			_disc(st, ep, 0.014, 5, Color(0.08, 0.07, 0.06, 0.0), 0.004)


static func _bone_col(st: SurfaceTool, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var dir := (b - a).normalized()
	var u := dir.cross(Vector3.UP)
	if u.length() < 0.01:
		u = dir.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := dir.cross(u).normalized()
	for k in 4:
		var a0 := TAU * k / 4.0
		var a1 := TAU * (k + 1) / 4.0
		_quad(st, a + (u * cos(a0) + v * sin(a0)) * r, a + (u * cos(a1) + v * sin(a1)) * r, b + (u * cos(a1) + v * sin(a1)) * r, b + (u * cos(a0) + v * sin(a0)) * r, col.darkened(0.2), col.darkened(0.2), col, col)


static func _mound(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for k in rng.randi_range(1, 3):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.25) if k > 0 else 0.0
		var r := rng.randf_range(0.3, 0.55) * (1.0 if k == 0 else 0.7)
		_blob(st, rng, Vector3(cos(a) * d, -0.02, sin(a) * d), r, r * rng.randf_range(0.18, 0.32), 9, 3, 0.1, 0.78, 1.0, 1.0, r * rng.randf_range(0.6, 1.0))


static func _fern(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var fronds := rng.randi_range(6, 9)
	for f in fronds:
		var a := TAU * f / fronds + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var length := rng.randf_range(0.28, 0.46)
		var arch := rng.randf_range(0.5, 1.1)
		var prev_c := Vector3(0, 0.01, 0)
		var prev_w := 0.012
		for s in 5:
			var t := float(s + 1) / 5.0
			var c := dir * length * t + Vector3(0, length * (sin(t * PI * 0.5 * arch) * 0.6 - t * t * 0.28 * arch) + 0.01, 0)
			var w := 0.045 * sin(t * PI * 0.9 + 0.2) * (1.0 - t * 0.35) + 0.004
			var lo := 0.55 + 0.45 * float(s) / 5.0
			var hi := 0.55 + 0.45 * t
			_quad(st, prev_c + side * prev_w, c + side * w, c - side * w, prev_c - side * prev_w, _grey(lo, 1.0), _grey(hi, 1.0), _grey(hi, 1.0), _grey(lo, 1.0))
			prev_c = c
			prev_w = w


static func _pod(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(0.2, 0.4)
	var top := _stem(st, rng, h, 0.015, 0.01, Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05)))
	var r := rng.randf_range(0.05, 0.08)
	# a plump bulb on top, drawn as a stack of rings
	var rings := [[0.0, 0.25], [0.35, 0.85], [0.75, 1.0], [1.15, 0.8], [1.5, 0.35], [1.8, 0.0]]
	var prev: Array = []
	for rr in rings:
		var ring: Array = []
		for k in 6:
			var a := TAU * k / 6.0
			ring.append(top + Vector3(cos(a) * r * float(rr[1]), r * float(rr[0]), sin(a) * r * float(rr[1])))
		if not prev.is_empty():
			var shade0 := 0.55 + 0.25 * float(rr[0]) / 1.8
			var shade1 := 0.55 + 0.45 * float(rr[0]) / 1.8
			for k in 6:
				var k2 := (k + 1) % 6
				_quad(st, prev[k], prev[k2], ring[k2], ring[k], _grey(shade0), _grey(shade0), _grey(shade1), _grey(shade1))
		prev = ring


static func _grave(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(0.09, 0.14)
	var h := rng.randf_range(0.2, 0.34)
	var t := 0.035
	var lean := Basis(Vector3(0, 0, 1), rng.randf_range(-0.2, 0.2)) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.12, 0.12))
	var stone := rng.randf_range(0.7, 1.0)
	var cross := rng.randf() < 0.4
	var pts: Array = []
	if cross:
		_slab(st, lean, Vector3(-t, 0, -t), Vector3(t, h, t), stone)
		_slab(st, lean, Vector3(-w, h * 0.62, -t), Vector3(w, h * 0.62 + t * 2.0, t), stone)
	else:
		_slab(st, lean, Vector3(-w, 0, -t), Vector3(w, h * 0.8, t), stone)
		# a rounded top: two stepped boxes
		_slab(st, lean, Vector3(-w * 0.8, h * 0.8, -t), Vector3(w * 0.8, h * 0.92, t), stone * 0.95)
		_slab(st, lean, Vector3(-w * 0.5, h * 0.92, -t), Vector3(w * 0.5, h, t), stone * 0.9)
	_blob(st, rng, Vector3(0, -0.01, 0.12), 0.09, 0.04, 6, 2, 0.15, 0.6, 1.0, 1.0, 0.14)


static func _slab(st: SurfaceTool, basis: Basis, lo: Vector3, hi: Vector3, shade: float) -> void:
	var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	for i in 8:
		c[i] = basis * (c[i] as Vector3)
	var faces := [[0, 1, 5, 4, 0.75], [1, 2, 6, 5, 0.9], [2, 3, 7, 6, 0.7], [3, 0, 4, 7, 0.85], [4, 5, 6, 7, 1.0]]
	for f in faces:
		var s: float = shade * float(f[4])
		_quad(st, c[f[0]], c[f[1]], c[f[2]], c[f[3]], _grey(s * 0.8, 0.6), _grey(s * 0.8, 0.6), _grey(s, 0.6), _grey(s, 0.6))
