class_name Chest
extends Node3D
## A treasure chest built from simple shapes, in a look for each of the six rarities: plain wood and iron (common), green wood with silver (uncommon), blue lacquer with
## silver and a sapphire (rare), purple with gold (epic), a golden chest with a glowing gem (legendary) and a black chest with glowing runes and floating crystals (mythic).
## `lid` is the pivot the lid turns on (rotate it about X to open), `inside` the glowing light in the open chest, `extras` things that spin around it.

const STYLE := {
	"common": {"body": Color(0.5, 0.32, 0.16), "metal": Color(0.32, 0.32, 0.36), "gem": Color(0.85, 0.75, 0.5), "glow": 0.0, "metallic": 0.5},
	"uncommon": {"body": Color(0.22, 0.45, 0.24), "metal": Color(0.72, 0.74, 0.78), "gem": Color(0.45, 1.0, 0.5), "glow": 0.5, "metallic": 0.7},
	"rare": {"body": Color(0.16, 0.3, 0.62), "metal": Color(0.78, 0.82, 0.9), "gem": Color(0.4, 0.7, 1.0), "glow": 0.8, "metallic": 0.75},
	"epic": {"body": Color(0.34, 0.16, 0.52), "metal": Color(1.0, 0.8, 0.35), "gem": Color(0.8, 0.45, 1.0), "glow": 1.0, "metallic": 0.85},
	"legendary": {"body": Color(0.95, 0.68, 0.18), "metal": Color(1.0, 0.95, 0.75), "gem": Color(1.0, 0.55, 0.15), "glow": 1.4, "metallic": 0.9},
	"mythic": {"body": Color(0.07, 0.05, 0.11), "metal": Color(0.7, 0.35, 1.0), "gem": Color(0.35, 1.0, 0.9), "glow": 1.8, "metallic": 0.8},
}

var rarity := "common"
var lid: Node3D
var inside: MeshInstance3D
var extras: Array = []
var style: Dictionary = {}


static func make(r: String) -> Chest:
	var c := Chest.new()
	c.rarity = r
	c.style = STYLE.get(r, STYLE["common"])
	c._build()
	return c


func _mat(col: Color, metal: float, rough: float, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A half barrel lying along X: an arch of radius r and length w (the lid), open underneath.
func _arch(w: float, r: float, mat: Material, parent: Node3D, z_scale: float = 1.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var n := 14
	for i in n:
		var a0 := PI * float(i) / n
		var a1 := PI * float(i + 1) / n
		var p0 := Vector2(cos(a0) * r * z_scale, sin(a0) * r)
		var p1 := Vector2(cos(a1) * r * z_scale, sin(a1) * r)
		var xa := -w * 0.5
		var xb := w * 0.5
		# Godot draws the clockwise side of a triangle: the curved face and the end at -X were wound the other way round, so from outside they were culled and the lid
		# (and one end of it) looked see-through when the camera came close
		for v in [Vector3(xa, p0.y, p0.x), Vector3(xb, p1.y, p1.x), Vector3(xb, p0.y, p0.x), Vector3(xa, p0.y, p0.x), Vector3(xa, p1.y, p1.x), Vector3(xb, p1.y, p1.x)]:
			st.add_vertex(v)
		# the two ends
		for side in [xa, xb]:
			var tri: Array = [Vector3(side, 0, 0), Vector3(side, p0.y, p0.x), Vector3(side, p1.y, p1.x)]
			if side == xa:
				tri = [Vector3(side, 0, 0), Vector3(side, p1.y, p1.x), Vector3(side, p0.y, p0.x)]
			for v in tri:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build() -> void:
	var body_mat := _mat(style["body"], 0.25 if rarity != "legendary" else 0.85, 0.55 if rarity != "legendary" else 0.3, 0.0)
	var metal_mat := _mat(style["metal"], style["metallic"], 0.3)
	var gem_mat := _mat(style["gem"], 0.1, 0.1, 0.6 + float(style["glow"]))
	body_mat.cull_mode = BaseMaterial3D.CULL_DISABLED                 # the lid is a thin shell: with the lid up you look at its inside, which must not vanish
	metal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var w := 1.2
	var d := 0.74
	var h := 0.52
	# the body, a little wider at the foot
	_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), body_mat, self)
	_box(Vector3(w + 0.06, 0.07, d + 0.06), Vector3(0, 0.035, 0), metal_mat, self)
	_box(Vector3(w + 0.06, 0.06, d + 0.06), Vector3(0, h - 0.03, 0), metal_mat, self)
	# iron (or silver, or gold) bands and corner posts
	for x in [-0.42, 0.42]:
		_box(Vector3(0.1, h + 0.02, d + 0.05), Vector3(x, h * 0.5, 0), metal_mat, self)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_box(Vector3(0.09, h + 0.04, 0.09), Vector3(cx * (w * 0.5), h * 0.5, cz * (d * 0.5)), metal_mat, self)
	# the glowing inside, seen when the lid is up
	inside = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w - 0.16, d - 0.16)
	qm.orientation = PlaneMesh.FACE_Y
	inside.mesh = qm
	var inner_col: Color = style["gem"]
	var im := _mat(inner_col, 0.0, 0.5, 0.0)
	im.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	im.albedo_color = Color(inner_col.r, inner_col.g, inner_col.b, 1.0).lightened(0.4)
	inside.material_override = im
	inside.position = Vector3(0, h + 0.002, 0)
	inside.visible = false
	add_child(inside)
	# the lid: a pivot at the back top edge, an arch, two arched bands, the lock and its gem
	lid = Node3D.new()
	lid.position = Vector3(0, h, -d * 0.5)
	add_child(lid)
	var arch_holder := Node3D.new()
	arch_holder.position = Vector3(0, 0, d * 0.5)
	lid.add_child(arch_holder)
	_arch(w, d * 0.5, body_mat, arch_holder)
	for x in [-0.42, 0.42]:
		var band := _arch(0.1, d * 0.5 + 0.03, metal_mat, arch_holder)
		band.position.x = x
	var lock := _box(Vector3(0.2, 0.22, 0.07), Vector3(0, -0.02, d + 0.02), metal_mat, lid)
	lock.name = "Lock"
	var gem := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	gem.mesh = sm
	gem.material_override = gem_mat
	gem.position = Vector3(0, -0.02, d + 0.07)
	lid.add_child(gem)
	# the rarer, the more: studs on the lid, a crown of points, floating crystals
	if Data.rarity_index(rarity) >= 2:
		for x in [-0.56, 0.56]:
			var stud := MeshInstance3D.new()
			var ss := SphereMesh.new()
			ss.radius = 0.045
			ss.height = 0.09
			stud.mesh = ss
			stud.material_override = metal_mat
			stud.position = Vector3(x, 0.02, d * 0.5)
			lid.add_child(stud)
	if Data.rarity_index(rarity) >= 4:
		for k in 3:
			var spike := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.05
			cm.height = 0.2
			spike.mesh = cm
			spike.material_override = metal_mat
			spike.position = Vector3((k - 1) * 0.3, d * 0.5 + 0.12, d * 0.5)
			spike.position.y = d * 0.5 + 0.06
			arch_holder.add_child(spike)
	if rarity == "mythic":
		for k in 5:
			var crystal := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = 0.0
			cc.bottom_radius = 0.07
			cc.height = 0.3
			cc.radial_segments = 5
			crystal.mesh = cc
			crystal.material_override = _mat(Color.from_hsv(float(k) / 5.0, 0.55, 1.0), 0.0, 0.2, 1.6)
			var holder := Node3D.new()
			holder.add_child(crystal)
			crystal.position = Vector3(1.0, 0.9, 0)
			holder.rotation.y = TAU * k / 5.0
			add_child(holder)
			extras.append(holder)
		# glowing runes on the front of the body
		for k in 4:
			_box(Vector3(0.06, 0.18 - 0.03 * (k % 2), 0.01), Vector3(-0.27 + 0.18 * k, 0.26, d * 0.5 + 0.006), _mat(Color(0.35, 1.0, 0.9), 0.0, 0.2, 2.0), self)
	# a soft ring of light on the floor for the glowing ones
	if float(style["glow"]) > 0.0:
		var ring := MeshInstance3D.new()
		var rq := QuadMesh.new()
		rq.size = Vector2(2.4, 2.4)
		rq.orientation = PlaneMesh.FACE_Y
		ring.mesh = rq
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rm.albedo_texture = Fx.TEX["soft"]
		var gc: Color = style["gem"]
		rm.albedo_color = Color(gc.r, gc.g, gc.b, 0.5 * minf(float(style["glow"]), 1.0))
		ring.material_override = rm
		ring.position = Vector3(0, 0.01, 0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)


## Opens the lid by `angle` degrees (0 = closed).
func set_lid(angle: float) -> void:
	lid.rotation_degrees.x = -angle
	inside.visible = angle > 6.0


func spin_extras(t: float) -> void:
	for i in extras.size():
		(extras[i] as Node3D).rotation.y = TAU * i / extras.size() + t * 1.4
