class_name PerchDress
extends RefCounted
## The look of the sniper perches, the stair slabs and the ladders. Every map has its own style: a treehouse in the forest, a stilt hut in the swamp, an ice shelf on the peaks,
## a forge gallery by the volcano, a crow's nest at the cove, a rook tower on the chess board... Everything of one material is merged into a single mesh, so a perch costs
## about five draw calls however many pieces it is made of.
## The ledge is built around its own middle: local +Z is towards the wall, -Z the open front, +X / -X the sides, the top surface is at y = +size.y / 2.

const FAR := 120.0                                 # the decoration is hidden beyond this distance

# body / trim / accent: colours of the slab, of the frame and details, and of the glowing or living parts. rail: parapet, posts, rope or crenel. support: beams, pillars,
# stilts or none. extras: see _extras. rung: ladder rungs. glow: strength of the glowing parts. metal: the trim is metal.
const STYLE := {
	"flora_forest": {"name": "TREEHOUSE", "body": Color(0.4, 0.28, 0.17), "trim": Color(0.28, 0.19, 0.11), "accent": Color(0.3, 0.62, 0.25), "lamp": Color(1.0, 0.85, 0.5),
		"rail": "rope", "support": "beams", "extras": ["leaves", "vines", "planks"], "rung": Color(0.5, 0.36, 0.2), "glow": 1.0, "metal": false},
	"toxic_swamp": {"name": "STILT HUT", "body": Color(0.27, 0.24, 0.15), "trim": Color(0.19, 0.18, 0.11), "accent": Color(0.5, 0.95, 0.3), "lamp": Color(0.6, 1.0, 0.35),
		"rail": "posts", "support": "stilts", "extras": ["moss", "glowjar", "planks"], "rung": Color(0.35, 0.3, 0.18), "glow": 1.6, "metal": false},
	"underwater_ocean": {"name": "REEF LOOKOUT", "body": Color(0.62, 0.58, 0.52), "trim": Color(0.92, 0.55, 0.5), "accent": Color(0.35, 0.95, 0.85), "lamp": Color(0.4, 0.9, 1.0),
		"rail": "posts", "support": "pillars", "extras": ["coral", "kelp"], "rung": Color(0.85, 0.7, 0.55), "glow": 1.2, "metal": false},
	"frozen_peaks": {"name": "ICE SHELF", "body": Color(0.7, 0.83, 0.95), "trim": Color(0.93, 0.97, 1.0), "accent": Color(0.55, 0.85, 1.0), "lamp": Color(0.7, 0.9, 1.0),
		"rail": "parapet", "support": "none", "extras": ["snowcap", "icicles"], "rung": Color(0.75, 0.85, 0.95), "glow": 0.5, "metal": false},
	"volcano_forge": {"name": "FORGE GALLERY", "body": Color(0.14, 0.11, 0.11), "trim": Color(0.32, 0.32, 0.35), "accent": Color(1.0, 0.4, 0.1), "lamp": Color(1.0, 0.5, 0.2),
		"rail": "posts", "support": "beams", "extras": ["lavacracks", "brazier"], "rung": Color(0.3, 0.3, 0.33), "glow": 2.0, "metal": true},
	"desert_tomb": {"name": "SUN TERRACE", "body": Color(0.75, 0.63, 0.43), "trim": Color(0.92, 0.77, 0.3), "accent": Color(1.0, 0.72, 0.22), "lamp": Color(1.0, 0.75, 0.35),
		"rail": "parapet", "support": "pillars", "extras": ["brazier", "hieroglyph"], "rung": Color(0.65, 0.5, 0.3), "glow": 1.4, "metal": true},
	"shadow_crypt": {"name": "BONE BALCONY", "body": Color(0.2, 0.2, 0.28), "trim": Color(0.72, 0.7, 0.62), "accent": Color(0.65, 0.4, 1.0), "lamp": Color(0.65, 0.45, 1.0),
		"rail": "posts", "support": "pillars", "extras": ["skulls", "purpletorch"], "rung": Color(0.55, 0.53, 0.5), "glow": 1.8, "metal": false},
	"crystal_caves": {"name": "CRYSTAL SHELF", "body": Color(0.2, 0.22, 0.36), "trim": Color(0.38, 0.42, 0.68), "accent": Color(0.5, 0.8, 1.0), "lamp": Color(0.55, 0.75, 1.0),
		"rail": "parapet", "support": "none", "extras": ["crystals"], "rung": Color(0.45, 0.5, 0.75), "glow": 1.8, "metal": false},
	"clockwork_mines": {"name": "GEAR WALK", "body": Color(0.3, 0.28, 0.26), "trim": Color(0.72, 0.46, 0.2), "accent": Color(1.0, 0.8, 0.4), "lamp": Color(1.0, 0.8, 0.4),
		"rail": "posts", "support": "beams", "extras": ["gears", "pipes"], "rung": Color(0.7, 0.45, 0.2), "glow": 1.4, "metal": true},
	"moon_sanctuary": {"name": "MOON TERRACE", "body": Color(0.78, 0.8, 0.92), "trim": Color(0.86, 0.88, 1.0), "accent": Color(0.72, 0.82, 1.0), "lamp": Color(0.75, 0.85, 1.0),
		"rail": "parapet", "support": "pillars", "extras": ["moonorb"], "rung": Color(0.8, 0.83, 0.95), "glow": 1.6, "metal": true},
	"pirate_cove": {"name": "CROW'S NEST", "body": Color(0.46, 0.33, 0.2), "trim": Color(0.25, 0.17, 0.1), "accent": Color(1.0, 0.78, 0.4), "lamp": Color(1.0, 0.75, 0.4),
		"rail": "rope", "support": "beams", "extras": ["planks", "barrel", "lantern"], "rung": Color(0.55, 0.4, 0.22), "glow": 1.4, "metal": false},
	"chess_arena": {"name": "ROOK TOWER", "body": Color(0.9, 0.88, 0.83), "trim": Color(0.13, 0.13, 0.15), "accent": Color(1.0, 0.85, 0.4), "lamp": Color(1.0, 0.95, 0.8),
		"rail": "crenel", "support": "pillars", "extras": ["checker"], "rung": Color(0.2, 0.2, 0.22), "glow": 1.0, "metal": true},
}
const DEFAULT := {"name": "LOOKOUT", "body": Color(0.5, 0.5, 0.5), "trim": Color(0.35, 0.35, 0.35), "accent": Color(0.8, 0.8, 0.6), "lamp": Color(1.0, 0.85, 0.5),
	"rail": "parapet", "support": "beams", "extras": [], "rung": Color(0.6, 0.45, 0.25), "glow": 1.0, "metal": false}


static func style(map_id: String) -> Dictionary:
	return STYLE.get(map_id, DEFAULT)


## Collects boxes, cylinders and balls per material and turns each material into one mesh.
class Kit extends RefCounted:
	var mats := {}
	var tools := {}

	func material(key: String, col: Color, rough: float = 0.9, metal: float = 0.0, glow: float = 0.0) -> void:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		m.metallic = metal
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

	func box(key: String, size: Vector3, pos: Vector3, basis: Basis = Basis()) -> void:
		var bm := BoxMesh.new()
		bm.size = size
		_tool(key).append_from(bm, 0, Transform3D(basis, pos))

	func cyl(key: String, r_top: float, r_bot: float, h: float, pos: Vector3, basis: Basis = Basis(), seg: int = 8) -> void:
		var cm := CylinderMesh.new()
		cm.top_radius = r_top
		cm.bottom_radius = r_bot
		cm.height = h
		cm.radial_segments = seg
		cm.rings = 1
		_tool(key).append_from(cm, 0, Transform3D(basis, pos))

	func ball(key: String, r: float, pos: Vector3, scale: Vector3 = Vector3.ONE) -> void:
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 8
		sm.rings = 4
		_tool(key).append_from(sm, 0, Transform3D(Basis.from_scale(scale), pos))

	## A beam from a to b.
	func strut(key: String, a: Vector3, b: Vector3, thick: float) -> void:
		var v := b - a
		var len := v.length()
		if len < 0.01:
			return
		var dir := v / len
		var basis := Basis() if absf(dir.y) > 0.999 else Basis(Quaternion(Vector3.UP, dir))
		box(key, Vector3(thick, len, thick), (a + b) * 0.5, basis)

	func commit(parent: Node3D) -> void:
		for key in tools:
			var mi := MeshInstance3D.new()
			mi.mesh = (tools[key] as SurfaceTool).commit()
			mi.material_override = mats.get(key)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = PerchDress.FAR
			parent.add_child(mi)


static func _kit(st: Dictionary) -> Kit:
	var kit := Kit.new()
	var metal := 0.7 if st["metal"] else 0.05
	kit.material("body", st["body"], 0.9)
	kit.material("trim", st["trim"], 0.5 if st["metal"] else 0.85, metal)
	kit.material("acc", st["accent"], 0.8)
	kit.material("glow", st["accent"], 0.4, 0.0, float(st["glow"]))
	kit.material("rope", (st["trim"] as Color).lightened(0.45), 0.95)
	return kit


## The decoration of a stair slab: a slab with a pale edge and a darker underside band.
static func dress_step(body: Node3D, st: Dictionary, size: Vector3) -> void:
	var kit := _kit(st)
	kit.box("body", size, Vector3.ZERO)
	kit.box("trim", Vector3(size.x + 0.08, 0.1, size.z + 0.08), Vector3(0, -size.y * 0.5 + 0.04, 0))
	kit.box("rope", Vector3(size.x + 0.06, 0.08, 0.14), Vector3(0, size.y * 0.5, -size.z * 0.5 + 0.07))      # a pale edge on the open side, so the step reads from below
	kit.commit(body)


## The whole look of a perch ledge. `open_x` is the sign of the side the stairs arrive on (no rail there), `drop` how far the floor is below the ledge.
static func dress_ledge(body: Node3D, st: Dictionary, size: Vector3, open_x: float, drop: float, seed_value: int) -> void:
	var hy_path := "res://models/perches/%s.glb" % String(body.get_meta("map_id", ""))
	if ResourceLoader.exists(hy_path):
		_use_model(body, hy_path, st, size)                       # a model made on Hunyuan replaces everything below
		return
	var kit := _kit(st)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	kit.box("body", size, Vector3.ZERO)
	kit.box("trim", Vector3(size.x + 0.14, 0.1, size.z + 0.14), Vector3(0, -hy + 0.04, 0))
	kit.box("trim", Vector3(size.x + 0.1, 0.1, 0.16), Vector3(0, hy - 0.02, -hz))                # a frame on the open front
	_support(kit, st, size, drop)
	_rails(kit, st, size, open_x)
	_extras(kit, st, size, open_x, rng)
	kit.commit(body)
	var lamp := OmniLight3D.new()
	lamp.light_color = st["lamp"]
	lamp.light_energy = 1.2
	lamp.omni_range = 9.0
	lamp.position = Vector3(0, 2.0, 0)
	body.add_child(lamp)
	var label := Label3D.new()
	label.text = "%s\nSNIPER PERCH" % st["name"]
	label.font_size = 40
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = (st["lamp"] as Color).lerp(Color.WHITE, 0.35)
	label.outline_size = 10
	label.position = Vector3(0, 2.8, 0)
	body.add_child(label)


static func _support(kit: Kit, st: Dictionary, size: Vector3, drop: float) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var d := clampf(drop, 1.5, 16.0)
	match String(st["support"]):
		"beams":
			for sx in [-1.0, 1.0]:
				kit.strut("trim", Vector3(sx * (hx - 0.5), -hy, -hz + 0.5), Vector3(sx * (hx - 0.5), -hy - 2.6, hz + 0.7), 0.24)
				kit.strut("trim", Vector3(sx * (hx - 0.5), -hy - 1.2, -hz + 0.25), Vector3(sx * (hx - 0.5), -hy, hz - 0.2), 0.14)
		"pillars":
			for sx in [-1.0, 1.0]:
				kit.cyl("trim", 0.3, 0.4, d, Vector3(sx * (hx - 0.45), -hy - d * 0.5, -hz + 0.5))
				kit.box("trim", Vector3(0.9, 0.14, 0.9), Vector3(sx * (hx - 0.45), -hy - 0.07, -hz + 0.5))
		"stilts":
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					kit.cyl("trim", 0.12, 0.15, d, Vector3(sx * (hx - 0.3), -hy - d * 0.5, sz * (hz - 0.3)), Basis(), 6)
				kit.strut("trim", Vector3(sx * (hx - 0.3), -hy - d * 0.3, -hz + 0.3), Vector3(sx * (hx - 0.3), -hy - d * 0.6, hz - 0.3), 0.08)


## The three railed sides (the side the stairs arrive on stays open): back (+Z) and the two ends.
static func _rails(kit: Kit, st: Dictionary, size: Vector3, open_x: float) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var lines := [
		{"a": Vector3(-hx + 0.1, 0, hz - 0.1), "b": Vector3(hx - 0.1, 0, hz - 0.1), "side": 0.0},
		{"a": Vector3(hx - 0.1, 0, -hz + 0.1), "b": Vector3(hx - 0.1, 0, hz - 0.1), "side": 1.0},
		{"a": Vector3(-hx + 0.1, 0, -hz + 0.1), "b": Vector3(-hx + 0.1, 0, hz - 0.1), "side": -1.0},
	]
	var kind := String(st["rail"])
	for ln in lines:
		var side: float = ln["side"]
		if side != 0.0 and side == open_x:
			continue
		var a: Vector3 = ln["a"]
		var b: Vector3 = ln["b"]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var yaw := Basis(Vector3.UP, atan2(-dir.z, dir.x))                      # a box's long side (X) along the rail
		match kind:
			"parapet":
				kit.box("trim", Vector3(length, 0.5, 0.2), a.lerp(b, 0.5) + Vector3(0, hy + 0.25, 0), yaw)
			"crenel":
				kit.box("trim", Vector3(length, 0.3, 0.26), a.lerp(b, 0.5) + Vector3(0, hy + 0.15, 0), yaw)
				var n := int(length / 0.9)
				for i in n + 1:
					kit.box("trim", Vector3(0.5, 0.55, 0.26), a.lerp(b, float(i) / maxf(n, 1)) + Vector3(0, hy + 0.55, 0), yaw)
			_:                                                                      # posts and rope
				var n2 := int(length / 1.4)
				for i in n2 + 1:
					kit.box("trim", Vector3(0.11, 0.95, 0.11), a.lerp(b, float(i) / maxf(n2, 1)) + Vector3(0, hy + 0.475, 0))
				kit.box("trim" if kind == "posts" else "rope", Vector3(length, 0.07, 0.07), a.lerp(b, 0.5) + Vector3(0, hy + 0.9, 0), yaw)
				if kind == "rope":
					kit.box("rope", Vector3(length, 0.05, 0.05), a.lerp(b, 0.5) + Vector3(0, hy + 0.5, 0), yaw)


static func _extras(kit: Kit, st: Dictionary, size: Vector3, open_x: float, rng: RandomNumberGenerator) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var corners: Array = []                                   # the corners that have a rail, back first
	for sx in [-1.0, 1.0]:
		if sx != open_x:
			corners.append(Vector3(sx * (hx - 0.25), hy, hz - 0.25))
			corners.append(Vector3(sx * (hx - 0.25), hy, -hz + 0.25))
	for tag in st["extras"]:
		match String(tag):
			"leaves":
				for i in 7:
					var r := rng.randf_range(0.5, 0.85)
					kit.ball("acc", r, Vector3(rng.randf_range(-hx + 0.3, hx - 0.3), hy + 0.15, rng.randf_range(0.7, hz - 0.2)), Vector3(1, 0.55, 1))
				for p in [Vector3(-1.8, 2.7, 1.0), Vector3(1.8, 2.8, 1.2), Vector3(0, 3.0, 1.6)]:
					kit.ball("acc", 1.35, p, Vector3(1, 0.45, 1))
				for sx in [-1.0, 1.0]:
					kit.cyl("trim", 0.07, 0.07, 2.6, Vector3(sx * (hx - 0.3), hy + 1.3, hz - 0.3), Basis(), 6)         # the posts that hold the leaf roof
			"vines":
				for i in 6:
					var l := rng.randf_range(1.2, 2.8)
					kit.cyl("acc", 0.05, 0.03, l, Vector3(rng.randf_range(-hx + 0.3, hx - 0.3), -hy - l * 0.5, -hz + 0.1), Basis(), 5)
			"moss":
				for c in corners:
					kit.ball("acc", 0.5, c + Vector3(0, 0.05, 0), Vector3(1.2, 0.4, 1.2))
				for i in 6:
					kit.ball("acc", rng.randf_range(0.2, 0.4), Vector3(rng.randf_range(-hx, hx), -hy - 0.1, rng.randf_range(-hz, hz)), Vector3(1, 1.6, 1))
			"glowjar":
				for c in corners:
					if c.z < 0.0:
						kit.ball("glow", 0.17, c + Vector3(0, 1.1, 0))
			"coral":
				for i in 8:
					var h := rng.randf_range(0.5, 1.2)
					kit.cyl("trim" if i % 2 == 0 else "acc", 0.02, rng.randf_range(0.1, 0.2), h, Vector3(-hx + 0.4 + i * (size.x - 0.8) / 7.0, hy + h * 0.5, -hz + rng.randf_range(0.1, 0.5)), Basis(Vector3.FORWARD, rng.randf_range(-0.3, 0.3)), 6)
				for i in 3:
					kit.ball("trim", rng.randf_range(0.25, 0.4), Vector3(rng.randf_range(-hx + 0.5, hx - 0.5), hy + 0.1, hz - 0.5), Vector3(1, 0.7, 1))
			"kelp":
				for i in 5:
					kit.box("acc", Vector3(0.07, rng.randf_range(1.6, 2.6), 0.02), Vector3(-hx + 0.5 + i * (size.x - 1.0) / 4.0, hy + 1.1, hz - 0.15), Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12)))
			"icicles":
				for i in 10:
					var l := rng.randf_range(0.5, 1.6)
					var on_front := i < 6
					var pos := Vector3(rng.randf_range(-hx + 0.2, hx - 0.2), -hy - l * 0.5, -hz + 0.1) if on_front else Vector3((hx - 0.1) * (1.0 if i % 2 == 0 else -1.0), -hy - l * 0.5, rng.randf_range(-hz, hz))
					kit.cyl("glow", rng.randf_range(0.1, 0.2), 0.0, l, pos, Basis(), 5)          # wide at the top, the point hangs down
			"snowcap":
				kit.box("rope", Vector3(size.x - 0.5, 0.08, size.z - 0.5), Vector3(0, hy + 0.04, 0))
				for c in corners:
					kit.ball("rope", 0.45, c + Vector3(0, 0.1, 0), Vector3(1.3, 0.5, 1.3))
			"lavacracks":
				for i in 7:
					var ang := rng.randf_range(0.0, PI)
					kit.box("glow", Vector3(0.07, 0.02, rng.randf_range(0.8, 1.7)), Vector3(rng.randf_range(-hx + 0.4, hx - 0.4), hy + 0.012, rng.randf_range(-hz + 0.4, hz - 0.4)), Basis(Vector3.UP, ang))
				kit.box("glow", Vector3(size.x - 0.6, 0.05, size.z - 0.6), Vector3(0, -hy - 0.03, 0))
			"brazier":
				for c in corners:
					if c.z > 0.0:
						kit.cyl("trim", 0.07, 0.1, 0.45, c + Vector3(0, 0.22, 0), Basis(), 6)
						kit.cyl("trim", 0.38, 0.2, 0.3, c + Vector3(0, 0.6, 0), Basis(), 8)
						kit.cyl("glow", 0.0, 0.26, 0.6, c + Vector3(0, 1.0, 0), Basis(), 6)
			"hieroglyph":
				for i in 11:
					kit.box("glow", Vector3(0.12, rng.randf_range(0.1, 0.24), 0.03), Vector3(-2.5 + i * 0.5, rng.randf_range(-0.08, 0.08), -hz - 0.012))
			"skulls":
				for c in corners:
					kit.ball("trim", 0.19, c + Vector3(0, 1.1, 0))
					kit.ball("glow", 0.045, c + Vector3(0.07, 1.14, -0.15))
					kit.ball("glow", 0.045, c + Vector3(-0.07, 1.14, -0.15))
			"purpletorch":
				for c in corners:
					if c.z > 0.0:
						kit.cyl("trim", 0.05, 0.05, 1.3, c + Vector3(0, 0.65, 0), Basis(), 6)
						kit.cyl("glow", 0.0, 0.17, 0.45, c + Vector3(0, 1.5, 0), Basis(), 6)
			"crystals":
				for i in 9:
					var h := rng.randf_range(0.5, 1.7)
					var back := i < 6
					var pos := Vector3(rng.randf_range(-hx + 0.3, hx - 0.3), hy + h * 0.5, hz - rng.randf_range(0.2, 0.9)) if back else Vector3((hx - 0.3) * (1.0 if i % 2 == 0 else -1.0), hy + h * 0.5, rng.randf_range(-hz + 0.5, 0.5))
					kit.cyl("glow" if i % 3 != 0 else "acc", 0.0, rng.randf_range(0.1, 0.25), h, pos, Basis(Vector3.FORWARD, rng.randf_range(-0.3, 0.3)) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), 5)
			"gears":
				for sx in [-1.0, 1.0]:
					var gx: float = sx * (hx + 0.08)
					var rot := Basis(Vector3.FORWARD, PI * 0.5)
					kit.cyl("trim", 0.9, 0.9, 0.14, Vector3(gx, 0.0, 0.2), rot, 12)
					kit.cyl("body", 0.28, 0.28, 0.22, Vector3(gx, 0.0, 0.2), rot, 8)
					for t in 8:
						var a := TAU * t / 8.0
						kit.box("trim", Vector3(0.14, 0.3, 0.3), Vector3(gx, cos(a) * 1.0, 0.2 + sin(a) * 1.0), Basis(Vector3.RIGHT, -a))
			"pipes":
				kit.cyl("trim", 0.12, 0.12, size.x - 0.6, Vector3(0, hy + 0.35, hz - 0.3), Basis(Vector3.FORWARD, PI * 0.5), 8)
				kit.cyl("trim", 0.1, 0.1, 1.2, Vector3(-hx + 0.4, hy + 0.7, hz - 0.3), Basis(), 8)
				kit.ball("glow", 0.14, Vector3(0.6, hy + 0.35, hz - 0.46))
			"moonorb":
				kit.ball("glow", 0.38, Vector3(0, 2.5, 0.4))
				for i in 3:
					var a := TAU * i / 3.0
					kit.ball("acc", 0.1, Vector3(cos(a) * 0.85, 2.5 + sin(a * 2.0) * 0.1, 0.4 + sin(a) * 0.85))
				for sx in [-1.0, 1.0]:
					kit.cyl("trim", 0.07, 0.07, 2.2, Vector3(sx * 0.9, hy + 1.1, 0.4), Basis(), 6)
			"barrel":
				for c in corners:
					if c.z > 0.0:
						kit.cyl("trim", 0.34, 0.34, 0.75, c + Vector3(0, 0.38, -0.2), Basis(), 8)
						kit.cyl("rope", 0.36, 0.36, 0.05, c + Vector3(0, 0.2, -0.2), Basis(), 8)
						kit.cyl("rope", 0.36, 0.36, 0.05, c + Vector3(0, 0.56, -0.2), Basis(), 8)
						kit.box("body", Vector3(0.6, 0.6, 0.6), c + Vector3(-0.1 * signf(c.x), 0.3, -1.0))
						break
			"lantern":
				for c in corners:
					if c.z < 0.0:
						kit.cyl("trim", 0.05, 0.05, 1.7, c + Vector3(0, 0.85, 0), Basis(), 6)
						kit.box("trim", Vector3(0.05, 0.05, 0.4), c + Vector3(0, 1.65, 0.2))
						kit.box("glow", Vector3(0.2, 0.3, 0.2), c + Vector3(0, 1.45, 0.38))
						break
			"planks":
				var z := -hz + 0.4
				while z < hz:
					kit.box("trim", Vector3(size.x - 0.1, 0.012, 0.035), Vector3(0, hy + 0.006, z))
					z += 0.55
			"checker":
				for i in 6:
					for j in 4:
						if (i + j) % 2 == 0:
							kit.box("trim", Vector3(0.98, 0.03, 0.98), Vector3(-2.5 + i, hy + 0.015, -1.5 + j))


## A perch made on Hunyuan (models/perches/<map id>.glb): the model is scaled so its widest side is the ledge's width (a little more), its top surface is put at the ledge's
## top and it is centred on the ledge. The collision stays the ledge box. The lamp and the label are kept.
static func _use_model(body: Node3D, path: String, st: Dictionary, size: Vector3) -> void:
	var res: Resource = load(path)
	if res is PackedScene:
		var node: Node3D = (res as PackedScene).instantiate()
		body.add_child(node)
		var box := AABB()
		var first := true
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var b := m.global_transform * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var k := (size.x * 1.15) / maxf(maxf(box.size.x, box.size.z), 0.01)
		node.scale = Vector3.ONE * k
		node.position = Vector3(-box.get_center().x * k, size.y * 0.5 - (box.position.y + box.size.y) * k, -box.get_center().z * k)
	var lamp := OmniLight3D.new()
	lamp.light_color = st["lamp"]
	lamp.light_energy = 1.0
	lamp.omni_range = 9.0
	lamp.position = Vector3(0, 2.0, 0)
	body.add_child(lamp)
	var label := Label3D.new()
	label.text = "%s\nSNIPER PERCH" % st["name"]
	label.font_size = 40
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = (st["lamp"] as Color).lerp(Color.WHITE, 0.35)
	label.outline_size = 10
	label.position = Vector3(0, 2.8, 0)
	body.add_child(label)
