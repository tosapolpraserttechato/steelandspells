class_name LadderNode
extends Node3D
## A climbable ladder. The node stands at the foot of the ladder and its local +Z points away from the wall it hangs on; it is only a volume (nothing to collide with).
## Every physics tick it tells the fighters inside it so (Combatant.on_ladder, ladder_in, ladder_snap, ladder_top) and Combatant.physics_move does the climbing:
## walk into the wall to go up, away from it to go down, Space kicks off, and at the top you hop onto the ledge.

const HALF_WIDTH := 0.95
const REACH := 1.4                                # how far in front of the wall the volume reaches
const AXIS := 0.5                                 # the climber is pulled onto this distance from the wall

var host: Match = null
var height := 9.0
var _label: Label3D


static func make(m: Match, foot: Vector3, out_dir: Vector2, h: float, rail_col: Color, rung_col: Color = Color(0.62, 0.45, 0.25)) -> LadderNode:
	var l := LadderNode.new()
	l.host = m
	l.height = h
	m.add_child(l)
	l.global_position = foot
	l.rotation.y = atan2(out_dir.x, out_dir.y)           # local +Z -> out_dir
	l._build(rail_col, rung_col)
	return l


func _build(rail_col: Color, rung_col: Color) -> void:
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = rail_col
	rail_mat.roughness = 0.8
	var rung_mat := StandardMaterial3D.new()
	rung_mat.albedo_color = rung_col
	rung_mat.roughness = 0.75
	for x in [-0.36, 0.36]:
		var rail := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.09, height, 0.09)
		rail.mesh = bm
		rail.material_override = rail_mat
		rail.position = Vector3(x, height * 0.5, 0.12)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rail)
	var count := int(height / 0.42)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var rm := BoxMesh.new()
	rm.size = Vector3(0.78, 0.07, 0.07)
	mm.mesh = rm
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, 0.3 + i * 0.42, 0.12)))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = rung_mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	# a little sign at the foot so the way up can be found
	_label = Label3D.new()
	_label.text = "LADDER  (walk into it)"
	_label.font_size = 36
	_label.pixel_size = 0.008
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(1.0, 0.9, 0.6)
	_label.outline_size = 8
	_label.position = Vector3(0, 1.9, 0.3)
	add_child(_label)


func _physics_process(_delta: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	var inv := global_transform.affine_inverse()
	var out_dir := global_transform.basis.z
	var top_y := global_position.y + height
	for c in host.combatants:
		if c == null or not is_instance_valid(c) or c.dead:
			continue
		var l := inv * c.global_position
		if absf(l.x) > HALF_WIDTH or l.z < -0.3 or l.z > REACH or l.y < -0.2 or l.y > height + 0.15:
			continue
		c.on_ladder = true
		c.ladder_in = -out_dir
		c.ladder_top = top_y
		c.ladder_snap = global_transform * Vector3(clampf(l.x, -0.3, 0.3), 0, AXIS)
	if _label != null:
		_label.visible = host.player != null and global_position.distance_to(host.player.global_position) < 14.0
