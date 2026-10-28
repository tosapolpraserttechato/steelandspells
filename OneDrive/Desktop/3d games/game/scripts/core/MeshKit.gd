class_name MeshKit
extends RefCounted
## Collects boxes, cylinders, balls and lofted shells per material and turns each material into ONE mesh (so a whole suit of armor costs a handful of draw calls).
## Everything added is first put through `xf`, so a piece can be described in model space and land in the local space of the bone it is attached to.

var mats := {}
var tools := {}
var xf := Transform3D.IDENTITY


func material(key: String, col: Color, rough: float = 0.9, metal: float = 0.0, glow: float = 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	mats[key] = m


func _tool(key: String) -> SurfaceTool:
	if not tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = st
	return tools[key]


func is_empty() -> bool:
	return tools.is_empty()


func box(key: String, size: Vector3, pos: Vector3, basis: Basis = Basis()) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	_tool(key).append_from(bm, 0, xf * Transform3D(basis, pos))


func cyl(key: String, r_top: float, r_bot: float, h: float, pos: Vector3, basis: Basis = Basis(), seg: int = 8) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	_tool(key).append_from(cm, 0, xf * Transform3D(basis, pos))


func ball(key: String, r: float, pos: Vector3, scale: Vector3 = Vector3.ONE, basis: Basis = Basis()) -> void:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	_tool(key).append_from(sm, 0, xf * Transform3D(basis * Basis.from_scale(scale), pos))


## A cylinder (or cone) from a to b, wider at a (r0) than at b (r1).
func tube(key: String, a: Vector3, b: Vector3, r0: float, r1: float, seg: int = 10) -> void:
	var v := b - a
	var len := v.length()
	if len < 0.005:
		return
	var dir := v / len
	var basis := Basis() if dir.y > 0.999 else (Basis(Vector3.RIGHT, PI) if dir.y < -0.999 else Basis(Quaternion(Vector3.UP, dir)))
	# a CylinderMesh is widest at the bottom with bottom_radius, its +Y is "top": so a (r0) is the bottom, b (r1) the top
	cyl(key, r1, r0, len, (a + b) * 0.5, basis, seg)


## A beam from a to b.
func strut(key: String, a: Vector3, b: Vector3, thick: float) -> void:
	var v := b - a
	var len := v.length()
	if len < 0.005:
		return
	var dir := v / len
	var basis := Basis() if absf(dir.y) > 0.999 else Basis(Quaternion(Vector3.UP, dir))
	box(key, Vector3(thick, len, thick), (a + b) * 0.5, basis)


## A shell through a stack of closed rings (each an Array of Vector3 with the same count), flat-shaded per quad and facing outwards from the ring centres.
## `cap_top` / `cap_bottom` close the ends.
func loft(key: String, rings: Array, cap_top: bool = false, cap_bottom: bool = false) -> void:
	if rings.size() < 2:
		return
	var st := _tool(key)
	var n: int = (rings[0] as Array).size()
	for i in rings.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var c0 := _centre(r0)
		var c1 := _centre(r1)
		for k in n:
			var k2 := (k + 1) % n
			var p00: Vector3 = r0[k]
			var p01: Vector3 = r0[k2]
			var p10: Vector3 = r1[k]
			var p11: Vector3 = r1[k2]
			var mid := (p00 + p01 + p10 + p11) * 0.25
			var out := mid - (c0 + c1) * 0.5
			_tri(st, p00, p10, p11, out)
			_tri(st, p00, p11, p01, out)
	if cap_top:
		_cap(st, rings[rings.size() - 1], Vector3.UP)
	if cap_bottom:
		_cap(st, rings[0], Vector3.DOWN)


static func _centre(ring: Array) -> Vector3:
	var c := Vector3.ZERO
	for p in ring:
		c += p as Vector3
	return c / float(ring.size())


func _cap(st: SurfaceTool, ring: Array, out: Vector3) -> void:
	var c := _centre(ring)
	var n := ring.size()
	for k in n:
		_tri(st, c, ring[k], ring[(k + 1) % n], out)


## One triangle through `xf`, wound so that the side facing `out` is the front (Godot: clockwise from the front), with its normal pointing that way.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	a = xf * a
	b = xf * b
	c = xf * c
	var o := xf.basis * out
	var n := (b - a).cross(c - a)
	if n.length_squared() < 0.0000001:
		return
	if n.dot(o) > 0.0:                         # counter-clockwise seen from outside: swap two corners
		var t := b
		b = c
		c = t
		n = -n
	n = -n.normalized()                        # clockwise from outside: the right-hand normal points inwards, so the outward normal is its opposite
	for p in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)
## An ellipse ring in the XZ plane at height y: centre (cx, cz), radii rx, rz_front (towards +Z) and rz_back (towards -Z).
static func ring(cx: float, y: float, cz: float, rx: float, rz_front: float, rz_back: float, n: int = 14) -> Array:
	var out: Array = []
	for k in n:
		var a := TAU * float(k) / float(n)
		var s := sin(a)
		var c := cos(a)
		out.append(Vector3(cx + c * rx, y, cz + s * (rz_front if s > 0.0 else rz_back)))
	return out


func commit(parent: Node3D, far: float = 0.0) -> void:
	for key in tools:
		var mi := MeshInstance3D.new()
		mi.mesh = (tools[key] as SurfaceTool).commit()
		mi.material_override = mats.get(key)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if far > 0.0:
			mi.visibility_range_end = far
		parent.add_child(mi)
