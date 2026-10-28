class_name ModelPreview
extends SubViewportContainer
## A small 3D viewer for a class character with its weapon (armory, title screen). The character stands in the middle of a glowing magic circle in the class colour,
## with a soft light behind and drifting sparks. Drag with the mouse to turn it.

var vp: SubViewport
var model: CharacterModel
var _pivot: Node3D
var _cam: Camera3D
var _auto := true
var _drag := false
var _class := ""
var _circle: Node3D
var _ring_a: MeshInstance3D
var _ring_b: MeshInstance3D
var _glow: MeshInstance3D
var _back: MeshInstance3D
var _motes: Node3D
var _t := 0.0
var _color := Color(1, 0.8, 0.4)
var show_hint := true
var show_off := false              # title screen: the hero faces the front and only plays its idle animation
var _act_timer := 1.5
var _acts := 0
var _weapon: Dictionary = {}
var _flare := 0.0


func _ready() -> void:
	stretch = true
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(int(maxf(size.x, 300)), int(maxf(size.y, 400)))
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.9)
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.4
	key.light_color = Color(1.0, 0.95, 0.85)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, -150, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.6, 0.7, 1.0)
	vp.add_child(rim)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.05, 4.5)
	_cam.rotation_degrees = Vector3(-3, 0, 0)
	_cam.fov = 32
	vp.add_child(_cam)
	_back = _glow_quad(3.4, 0.0)
	_back.position = Vector3(0, 1.0, -1.2)
	vp.add_child(_back)
	_circle = Node3D.new()
	vp.add_child(_circle)
	_glow = _flat_quad(Fx.TEX["soft"], 3.0, 0.5)
	_circle.add_child(_glow)
	_ring_a = _flat_quad(Fx.TEX["ring"], 2.5, 0.9)
	_circle.add_child(_ring_a)
	_ring_b = _flat_quad(Fx.TEX["hex"], 1.7, 0.7)
	_circle.add_child(_ring_b)
	_motes = Fx.particles({"tex": "star", "amount": 16, "life": 3.0, "shape": "ring", "radius": 1.1, "inner": 0.4, "dir": Vector3.UP, "spread": 8, "vel": [0.2, 0.5],
		"size": [0.04, 0.09], "colors": [Color(1, 0.9, 0.6, 0.9), Color(1, 0.8, 0.4, 0.0)]})
	vp.add_child(_motes)
	_pivot = Node3D.new()
	vp.add_child(_pivot)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if show_hint:
		var hint := UiKit.label("drag to turn", 12, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
		hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		hint.offset_top = -22
		add_child(hint)


func _flat_quad(tex: Texture2D, size_m: float, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size_m, size_m)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.albedo_color = Color(1, 1, 1, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(0, 0.03, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _glow_quad(size_m: float, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size_m, size_m)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = Fx.TEX["soft"]
	m.albedo_color = Color(1, 1, 1, alpha)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _tint(mi: MeshInstance3D, c: Color, a: float) -> void:
	(mi.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, a)


func show_class(class_id: String, weapon_id: String = "") -> void:
	if model != null:
		model.queue_free()
		model = null
	_class = class_id
	_color = Data.color_of(Data.classes[class_id]["color"])
	model = CharacterModel.new()
	_pivot.add_child(model)
	model.setup(class_id, 1.0, "red", "", true)
	model.hide_ring()
	model.rotation.y = 0.0
	var wid := weapon_id if weapon_id != "" else String(Data.classes[class_id]["weapon"])
	_weapon = Data.weapons.get(wid, {})
	if Data.weapons.has(wid):
		var wi := Game.equipped_item("weapon", class_id)
		var wnew: bool = not wi.is_empty() and bool(wi.get("new", false))
		model.hold_weapon(Weapons.visual_for(Data.weapons[wid], String(wi.get("skin", "")) if wnew else "", not wi.is_empty() and not wnew))
	var worn_set := Game.worn_armor()
	model.dress(worn_set[0], worn_set[1], worn_set[2])
	_act_timer = 1.4
	_acts = 0
	_tint(_glow, _color, 0.45)
	_tint(_ring_a, _color.lerp(Color(1, 1, 1), 0.25), 0.9)
	_tint(_ring_b, _color.lerp(Color(1, 0.9, 0.6), 0.4), 0.7)
	_tint(_back, _color, 0.22)


func _process(delta: float) -> void:
	_t += delta
	if _pivot != null and _auto and not _drag:
		if show_off:
			_pivot.rotation.y = lerp_angle(_pivot.rotation.y, 0.35 * sin(_t * 0.4), minf(1.0, delta * 2.0))     # mostly facing us, swaying a little
		else:
			_pivot.rotation.y += delta * 0.5
	if show_off and model != null:
		model.play_state("idle")                  # the title hero only idles (breathes and sways); it never attacks or casts
	_flare = maxf(0.0, _flare - delta * 1.4)
	if _ring_a != null:
		_ring_a.rotation.y = _t * 0.25
		_ring_b.rotation.y = -_t * 0.4
		var pulse := 0.85 + 0.15 * sin(_t * 1.8)
		_tint(_glow, _color, 0.38 * pulse + 0.1 + 0.4 * _flare)




func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
		_auto = false
	elif event is InputEventMouseMotion and _drag:
		_pivot.rotation.y += event.relative.x * 0.012
