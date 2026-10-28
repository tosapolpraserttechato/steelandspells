class_name AirDropNode
extends Node3D
## A supply drop. A crate hangs from a parachute and floats down onto a spot of the map; a tall column of golden light and a smoke flare show where from far away
## (and the spot is on the minimap). When it lands it is a gold loot crate that anyone can open (G); the bots come for it too. Match.gd sends one now and then.

const FALL_SPEED := 7.0
const START_HEIGHT := 95.0

var match_ref: Match = null
var target := Vector3.ZERO
var crate: LootCrateNode = null
var landed := false
var open_done := false
var _fall: Node3D
var _chute: Node3D
var _t := 0.0
var _gone_in := -1.0
var _chest: Chest


func setup(m: Match, spot: Vector3) -> void:
	match_ref = m
	target = spot
	global_position = spot
	# the marker: a column of light from the spot into the sky, and a puff of coloured smoke rising from it
	var beam := Fx.crate_beam("legendary", 60.0)
	add_child(beam)
	var smoke := Fx.particles({"tex": "soft", "amount": 24, "life": 4.0, "shape": "sphere", "radius": 0.5, "dir": Vector3.UP, "spread": 6, "vel": [1.5, 3.5], "size": [0.8, 1.8],
		"colors": [Color(1.0, 0.75, 0.2, 0.0), Color(1.0, 0.8, 0.3, 0.55), Color(0.9, 0.55, 0.2, 0.0)]})
	smoke.position = Vector3(0, 0.3, 0)
	add_child(smoke)
	var label := Label3D.new()
	label.text = "AIR DROP"
	label.font_size = 64
	label.pixel_size = 0.014
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.88, 0.45)
	label.outline_size = 14
	label.position = Vector3(0, 6.0, 0)
	add_child(label)
	_fall = Node3D.new()
	_fall.position = Vector3(0, START_HEIGHT, 0)
	add_child(_fall)
	_fall.add_child(_crate_visual())
	_chute = _chute_visual()
	_fall.add_child(_chute)


func _crate_visual() -> Node3D:
	_chest = Chest.make("legendary")
	_chest.scale = Vector3.ONE * 1.15
	return _chest


func _chute_visual() -> Node3D:
	var root := Node3D.new()
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.2
	sm.height = 2.2
	sm.is_hemisphere = true
	dome.mesh = sm
	dome.position = Vector3(0, 5.2, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.35, 0.25)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	dome.material_override = m
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dome)
	var stripe := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.5
	tm.outer_radius = 2.0
	stripe.mesh = tm
	stripe.position = Vector3(0, 5.5, 0)
	stripe.scale = Vector3(1.0, 0.25, 1.0)
	var sm2 := StandardMaterial3D.new()
	sm2.albedo_color = Color(1.0, 0.95, 0.8)
	stripe.material_override = sm2
	stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stripe)
	# four ropes from the corners of the crate to the rim of the dome
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.85, 0.8, 0.65)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var from := Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6)
		var to := Vector3(cos(a) * 2.1, 5.2, sin(a) * 2.1)
		var rope := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.02
		cm.height = from.distance_to(to)
		rope.mesh = cm
		rope.position = (from + to) * 0.5
		rope.look_at_from_position(rope.position, to, Vector3.UP)
		rope.rotate_object_local(Vector3(1, 0, 0), PI * 0.5)
		rope.material_override = rope_mat
		rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(rope)
	return root


func _process(delta: float) -> void:
	_t += delta
	if _gone_in >= 0.0:
		_gone_in -= delta
		if _gone_in <= 0.0:
			queue_free()
		return
	if not landed:
		_fall.position.y -= FALL_SPEED * delta
		_fall.rotation.z = sin(_t * 1.3) * 0.07
		_fall.rotation.x = cos(_t * 1.1) * 0.05
		if _fall.position.y <= 0.0:
			_land()
	elif crate != null and crate.is_open and not open_done:
		open_done = true
		create_tween().tween_method(func(a: float) -> void: _chest.set_lid(a), 0.0, 115.0, 0.8)
		_gone_in = 8.0                                    # the empty crate and the light stay a few seconds


func _land() -> void:
	landed = true
	_fall.position.y = 0.0
	_fall.rotation = Vector3.ZERO
	Fx.ring(global_position, 6.0, Color(1.0, 0.85, 0.4), 0.8)
	Fx.impact(global_position + Vector3(0, 0.4, 0), Color(1.0, 0.85, 0.5), true)
	var tw := create_tween()
	tw.tween_property(_chute, "scale", Vector3(1, 0.05, 1), 0.7)
	tw.tween_callback(func() -> void: _chute.visible = false)
	# from now on it is a gold crate anyone can open
	crate = LootCrateNode.new()
	add_child(crate)
	crate.match_ref = match_ref
	crate.setup(true, 99999.0)
	crate.opened.connect(match_ref._on_crate_opened)
	match_ref.interactables.append(crate)
	match_ref.crates.append(crate)
	match_ref.hud_toast("The air drop has landed!", Color(1.0, 0.85, 0.4))
	Sfx.play("chest")


func _exit_tree() -> void:
	if match_ref != null and is_instance_valid(match_ref):
		match_ref.airdrops.erase(self)
		if crate != null:
			match_ref.interactables.erase(crate)
			match_ref.crates.erase(crate)
