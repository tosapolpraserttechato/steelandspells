class_name FlagNode
extends Node3D
## A team's flag for capture the flag. It stands at its team's base ("home"). A fighter of the other team who touches it picks it up ("carried") and has to bring it
## to their own flag base while their own flag is at home. A carrier who dies drops it ("dropped"); a teammate of the flag touching it sends it home at once,
## otherwise it goes home by itself after RETURN_AFTER seconds. Match.gd calls tick() every physics frame.

const PICKUP_R := 2.2
const RETURN_AFTER := 20.0
const CAPTURE_R := 3.4
const TEAM_COLOR := {"red": Color(1.0, 0.32, 0.26), "blue": Color(0.32, 0.55, 1.0)}

var team := "red"
var home := Vector3.ZERO
var state := "home"                       # home, carried or dropped
var carrier: Combatant = null
var match_ref: Match = null
var _return_t := 0.0
var _t := 0.0
var _flag: Node3D
var _ring: MeshInstance3D
var _label: Label3D


func setup(m: Match, t: String, pos: Vector3) -> void:
	match_ref = m
	team = t
	home = pos
	global_position = pos
	var col: Color = TEAM_COLOR[team]
	# the pole
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.045
	pm.bottom_radius = 0.06
	pm.height = 3.6
	pole.mesh = pm
	pole.position = Vector3(0, 1.8, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.82, 0.78, 0.65)
	pmat.metallic = 0.6
	pmat.roughness = 0.4
	pole.material_override = pmat
	add_child(pole)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	knob.mesh = sm
	knob.position = Vector3(0, 3.65, 0)
	knob.material_override = pmat
	add_child(knob)
	# the banner: a wavy pennant that sways
	_flag = Node3D.new()
	_flag.position = Vector3(0.04, 3.2, 0)
	add_child(_flag)
	var banner := MeshInstance3D.new()
	banner.mesh = _banner_mesh()
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = col
	bmat.emission_enabled = true
	bmat.emission = col
	bmat.emission_energy_multiplier = 0.55
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.vertex_color_use_as_albedo = true
	banner.material_override = bmat
	banner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flag.add_child(banner)
	# a glowing ring on the ground and a tall soft column of light, so the flag can be seen from far away
	_ring = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(5.0, 5.0)
	qm.orientation = PlaneMesh.FACE_Y
	_ring.mesh = qm
	_ring.position = Vector3(0, 0.08, 0)
	_ring.material_override = _glow_material(Fx.TEX["ring"], col, 0.9)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var column := MeshInstance3D.new()
	var cm := QuadMesh.new()
	cm.size = Vector2(3.0, 26.0)
	column.mesh = cm
	column.position = Vector3(0, 13.0, 0)
	var cmat := _glow_material(Fx.TEX["soft"], col, 0.28)
	cmat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	column.material_override = cmat
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(column)
	_label = Label3D.new()
	_label.text = "%s FLAG" % team.to_upper()
	_label.font_size = 64
	_label.pixel_size = 0.012
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = col.lerp(Color.WHITE, 0.35)
	_label.outline_size = 14
	_label.position = Vector3(0, 4.6, 0)
	add_child(_label)


func _glow_material(tex: Texture2D, col: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A pennant: 6 columns of 2 triangles, a little crest of gold along the pole edge, ending in a point.
func _banner_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 7
	var length := 1.7
	var h0 := 0.95
	for i in cols:
		var u0 := float(i) / cols
		var u1 := float(i + 1) / cols
		var top0 := Vector3(u0 * length, -0.0, 0)
		var top1 := Vector3(u1 * length, -0.0, 0)
		var bot0 := Vector3(u0 * length, -h0 * (1.0 - u0 * 0.55), 0)
		var bot1 := Vector3(u1 * length, -h0 * (1.0 - u1 * 0.55), 0)
		var shade0 := 1.0 - 0.18 * u0
		var shade1 := 1.0 - 0.18 * u1
		for v in [[top0, shade0], [bot0, shade0], [top1, shade1], [top1, shade1], [bot0, shade0], [bot1, shade1]]:
			st.set_color(Color(v[1], v[1], v[1]))
			st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


func tick(delta: float, combatants: Array) -> void:
	_t += delta
	_flag.rotation.y = sin(_t * 2.3) * 0.2
	_flag.scale = Vector3(1.0 + 0.05 * sin(_t * 5.0), 1.0, 1.0)
	_ring.visible = state != "carried"
	(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.6 + 0.3 * sin(_t * 2.0)
	match state:
		"carried":
			if carrier == null or not is_instance_valid(carrier) or carrier.dead:
				_drop(carrier.global_position if carrier != null and is_instance_valid(carrier) else global_position)
				return
			global_position = carrier.global_position
			var own: FlagNode = match_ref.flags.get(carrier.team)
			if own != null and own.state == "home" and carrier.global_position.distance_to(own.home) < CAPTURE_R:
				match_ref.flag_captured(self, carrier)
		_:
			for c in combatants:
				if c.dead or (c is Bot and (c as Bot).life_left >= 0.0) or c.global_position.distance_to(global_position) > PICKUP_R:
					continue
				if c.team == team:
					if state == "dropped":
						return_home(c)
						return
				elif c.carrying_flag == null:
					_pick_up(c)
					return
			if state == "dropped":
				_return_t -= delta
				if _return_t <= 0.0:
					return_home(null)


func _pick_up(c: Combatant) -> void:
	state = "carried"
	carrier = c
	c.carrying_flag = self
	scale = Vector3.ONE * 0.8
	match_ref.hud_toast("%s took the %s flag!" % [c.display_name, team.to_upper()], TEAM_COLOR[c.team])
	Sfx.play("chime")


func _drop(at: Vector3) -> void:
	if carrier != null and is_instance_valid(carrier):
		carrier.carrying_flag = null
	var who := carrier.display_name if carrier != null and is_instance_valid(carrier) else "The carrier"
	carrier = null
	state = "dropped"
	scale = Vector3.ONE
	_return_t = RETURN_AFTER
	global_position = _ground_below(at)
	match_ref.hud_toast("%s dropped the %s flag" % [who, team.to_upper()], Color(1.0, 0.85, 0.4))


func return_home(by: Combatant) -> void:
	if carrier != null and is_instance_valid(carrier):
		carrier.carrying_flag = null
	carrier = null
	state = "home"
	scale = Vector3.ONE
	global_position = home
	if by != null:
		match_ref.hud_toast("%s returned the %s flag" % [by.display_name, team.to_upper()], TEAM_COLOR[team])
	else:
		match_ref.hud_toast("The %s flag went home" % team.to_upper(), TEAM_COLOR[team])


func _ground_below(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3.0, 0), p - Vector3(0, 30.0, 0), 1)
	var r := space.intersect_ray(q)
	return r["position"] if not r.is_empty() else p
