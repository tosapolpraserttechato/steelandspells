class_name CharacterModel
extends Node3D
## The visible character: a rigged class model with ~30 animation clips, a held weapon, hit flash, a team ring and a nameplate.
## The model file faces +Z (glTF), so it is turned half a turn to face Godot's forward (-Z).

## Classes whose models came out too shiny: their materials are made rougher and less metallic (the number is how matte, 0..1).
const MATTE := {"thunder_god": 1.0}
const LOOPING := ["Idle", "Run", "Sprint", "JumpLoop", "CastIdle", "SlideLoop"]
const HAND_BONE := "DEF-hand.R"

var anim: AnimationPlayer
var skeleton: Skeleton3D
var meshes: Array = []
var class_id := ""
var height := 1.85
var _state := ""
var _busy_until := 0.0                  # a one-shot (attack, hit...) owns the animation until this time
var _hand: BoneAttachment3D
var _hand_l: BoneAttachment3D
var _pose: Node3D
var _recipe_tween: Tween
var _pose_tween: Tween
var _weapon_node: Node3D
var _ring: MeshInstance3D
var _plate: Node3D
var _plate_fill: MeshInstance3D
var _plate_label: Label3D
var _flash_mat: StandardMaterial3D
var _ghost := false
var _ghost_mats: Dictionary = {}
var _clock := 0.0


func setup(cls: String, scale_factor: float, team: String, display_name: String, is_local: bool) -> void:
	class_id = cls
	var path: String = Data.classes[cls]["model"]
	var packed: PackedScene = load(path)
	var inst: Node3D = packed.instantiate()
	inst.rotation.y = PI
	_pose = Node3D.new()                   # the body pose layer (lean, crouch, rise...) sits between the model root and the rigged model
	add_child(_pose)
	_pose.add_child(inst)
	scale = Vector3.ONE * scale_factor
	height = 1.85 * scale_factor
	var stack: Array = [inst]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			anim = n
		elif n is Skeleton3D:
			skeleton = n
		elif n is MeshInstance3D:
			meshes.append(n)
			var fixed := "res://models/classes/fixed/%s_body.res" % path.get_file().get_basename().trim_prefix("class_")
			if (n as MeshInstance3D).skin != null and ResourceLoader.exists(fixed):
				(n as MeshInstance3D).mesh = load(fixed)           # rigid boots (tools/fix_feet.gd): the shoes no longer stretch
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if (n as MeshInstance3D).mesh != null and cls in MATTE:
				_make_matte(n as MeshInstance3D, float(MATTE[cls]))
		for c in n.get_children():
			stack.append(c)
	if anim != null:
		for a in anim.get_animation_list():
			var animation: Animation = anim.get_animation(a)
			animation.loop_mode = Animation.LOOP_LINEAR if a in LOOPING else Animation.LOOP_NONE
		anim.playback_default_blend_time = 0.12
		if skeleton != null:
			ClothDamp.apply(skeleton, anim, Data.classes[cls].get("run_calm", {}))
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1, 1, 1, 0.0)
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_center_on_hips(inst)
	if Data.classes[cls].has("outfit"):
		dress({})
	var armor_test := OS.get_environment("ARMOR_TEST")                    # test hook: ARMOR_TEST=<set id> dresses everybody in that whole set
	if armor_test != "":
		dress({"helmet": armor_test, "chestplate": armor_test, "shield": armor_test, "leggings": armor_test, "boots": armor_test})
	_make_ring(team)
	if not is_local:
		_make_plate(team, display_name)
	play_state("idle", true)


func _make_ring(team: String) -> void:
	_ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	q.orientation = PlaneMesh.FACE_Y
	_ring.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = Fx.TEX["ring"]
	m.albedo_color = Color(1.0, 0.25, 0.2, 0.8) if team == "red" else Color(0.25, 0.5, 1.0, 0.8)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = m
	_ring.position = Vector3(0, 0.06, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _make_plate(team: String, display_name: String) -> void:
	_plate = Node3D.new()
	_plate.position = Vector3(0, 2.25, 0)
	add_child(_plate)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 0.12)
	bg.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0, 0, 0, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 3
	bg.material_override = m
	_plate.add_child(bg)
	_plate_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.04, 0.07)
	_plate_fill.mesh = q2
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m2.albedo_color = Color(1.0, 0.3, 0.25) if team == "red" else Color(0.3, 0.55, 1.0)
	m2.no_depth_test = true
	m2.render_priority = 4
	_plate_fill.material_override = m2
	_plate.add_child(_plate_fill)
	_plate_label = Label3D.new()
	_plate_label.text = display_name
	_plate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate_label.fixed_size = false
	_plate_label.pixel_size = 0.004
	_plate_label.position = Vector3(0, 0.17, 0)
	_plate_label.outline_size = 8
	_plate_label.no_depth_test = true
	_plate_label.modulate = Color(1, 0.8, 0.8) if team == "red" else Color(0.8, 0.9, 1)
	_plate.add_child(_plate_label)


func set_health_fraction(f: float) -> void:
	if _plate_fill == null:
		return
	f = clampf(f, 0.0, 1.0)
	# the fill quad is billboarded, so scale its width and keep it left-aligned by shifting in local x (billboard faces the camera)
	_plate_fill.scale = Vector3(maxf(f, 0.001), 1, 1)


func set_plate_visible(v: bool) -> void:
	if _plate != null:
		_plate.visible = v


# ----------------------------------------------------------------- armor

## The armor a fighter wears is NOT drawn on the body (the user asked to drop it: only weapons are shown). Armor still gives its passives and set bonuses. Set to true to draw it again
## (ArmorKit builds the pieces, Hunyuan models in models/armor/ are used when present).
const ARMOR_VISIBLE := false

var _armor_nodes: Array = []
var _orig_meshes: Dictionary = {}            # MeshInstance3D -> the mesh it came with, while parts of it are cut away
static var _cut_cache: Dictionary = {}


## Puts on armor. `pieces` maps each worn slot (helmet, chestplate, shield, leggings, boots) to the id of its set, `skins` each slot to the skin name of a brand-new piece.
## Wearing all five of one set makes it "complete" (see ArmorKit). The original clothes under the armor are cut out of the body mesh, so nothing pokes through.
func dress(pieces: Dictionary, skins: Dictionary = {}, worn: Dictionary = {}) -> void:
	if not ARMOR_VISIBLE:
		pieces = {}
		skins = {}
		worn = {}
	var outfit := String(Data.classes.get(class_id, {}).get("outfit", "")) if ARMOR_VISIBLE else ""      # clothes a class always wears (the necromancer's block robe) are drawn with the armor only
	if outfit != "":
		pieces = pieces.duplicate()
		for slot in ["helmet", "chestplate", "leggings", "boots"]:
			if not pieces.has(slot):
				pieces[slot] = outfit
	for n in _armor_nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_armor_nodes.clear()
	var counts: Dictionary = {}
	for slot in pieces:
		counts[pieces[slot]] = int(counts.get(pieces[slot], 0)) + 1
	var complete_set := ""
	for sid in counts:
		if int(counts[sid]) >= 5:
			complete_set = String(sid)
	var hidden: Array = []
	var modelled := func(slot: String) -> bool: return pieces.has(slot) and ArmorKit.model_path(String(pieces[slot]), slot) != ""
	if pieces.has("chestplate"):
		hidden.append_array(["DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-shoulder.L", "DEF-shoulder.R"])
		if not modelled.call("chestplate"):             # a Hunyuan chestplate has short sleeves only: the arms below stay
			hidden.append_array(["DEF-upper_arm.L", "DEF-upper_arm.R", "DEF-forearm.L", "DEF-forearm.R"])
	if pieces.has("leggings"):
		hidden.append_array(["DEF-thigh.L", "DEF-thigh.R", "DEF-shin.L", "DEF-shin.R"])
		if not modelled.call("leggings"):               # a Hunyuan greave covers one leg only: the hips stay
			hidden.append("DEF-hips")
	if pieces.has("boots"):
		hidden.append_array(["DEF-foot.L", "DEF-foot.R", "DEF-toe.L", "DEF-toe.R"])
	if (pieces.has("chestplate") or pieces.has("leggings")) and skeleton != null:
		for i in skeleton.get_bone_count():                                  # the original skirt and cape
			if skeleton.get_bone_name(i).begins_with("cloth_"):
				hidden.append(skeleton.get_bone_name(i))
	_hide_parts(hidden)
	_armor_nodes = ArmorKit.dress(self, pieces, complete_set, skins, worn)


## Cuts every triangle out of the body mesh whose corners all belong to the given bones (the clothes the armor replaces). An empty list brings the original mesh back.
func _hide_parts(bone_names: Array) -> void:
	for mi in meshes:
		var m := mi as MeshInstance3D
		if m == null:
			continue
		if not _orig_meshes.has(m):
			_orig_meshes[m] = m.mesh
		var orig: Mesh = _orig_meshes[m]
		if bone_names.is_empty() or m.skin == null or orig == null:
			m.mesh = orig
			continue
		var key := "%s|%d|%s" % [class_id, orig.get_instance_id(), ",".join(PackedStringArray(bone_names))]
		if not _cut_cache.has(key):
			_cut_cache[key] = _cut_mesh(m, orig, bone_names)
		m.mesh = _cut_cache[key]


func _cut_mesh(m: MeshInstance3D, orig: Mesh, bone_names: Array) -> Mesh:
	var hide: Dictionary = {}
	for n in bone_names:
		hide[skeleton.find_bone(n)] = true
	var bind_hidden: Array = []
	for i in m.skin.get_bind_count():
		var b := m.skin.get_bind_bone(i)
		if b < 0:
			b = skeleton.find_bone(m.skin.get_bind_name(i))
		bind_hidden.append(hide.has(b))
	var out := ArrayMesh.new()
	for s in orig.get_surface_count():
		var arrays := orig.surface_get_arrays(s)
		var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var pb: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var pw: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := 4
		if not pb.is_empty() and not pv.is_empty():
			per = pb.size() / pv.size()
		if idx.is_empty() or pb.is_empty():
			out.add_surface_from_arrays(orig.surface_get_primitive_type(s), arrays)
			out.surface_set_material(s, orig.surface_get_material(s))
			continue
		var gone := PackedByteArray()
		gone.resize(pv.size())
		for v in pv.size():
			var best := 0
			var bw := -1.0
			for j in per:
				if pw[v * per + j] > bw:
					bw = pw[v * per + j]
					best = pb[v * per + j]
			gone[v] = 1 if (best >= 0 and best < bind_hidden.size() and bind_hidden[best]) else 0
		var kept := PackedInt32Array()
		for t in range(0, idx.size() - 2, 3):
			if gone[idx[t]] == 1 and gone[idx[t + 1]] == 1 and gone[idx[t + 2]] == 1:
				continue
			kept.append(idx[t])
			kept.append(idx[t + 1])
			kept.append(idx[t + 2])
		arrays[Mesh.ARRAY_INDEX] = kept
		out.add_surface_from_arrays(orig.surface_get_primitive_type(s), arrays, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
		out.surface_set_material(s, orig.surface_get_material(s))
	return out


# ----------------------------------------------------------------- weapon in hand

## `info` comes from Weapons.visual_for: path, length, grip, pitch, axis, roll, offset. The model is scaled to `length`, its grip point is put in the right hand
## and the weapon is tilted forward by `pitch` degrees (the hand bone points down the arm, so straight up is a half turn about its X axis).
func hold_weapon(info: Dictionary) -> void:
	if _weapon_node != null:
		_weapon_node.queue_free()
		_weapon_node = null
	var model_path: String = info.get("path", "")
	var proc: Node3D = ProcWeapon.make(String(info.get("weapon", {}).get("id", "")))
	if skeleton == null or (proc == null and (model_path == "" or not ResourceLoader.exists(model_path))):
		return
	if _hand == null:
		_hand = BoneAttachment3D.new()
		_hand.bone_name = HAND_BONE
		skeleton.add_child(_hand)
	var node: Node3D = proc
	if node == null:
		var res: Resource = load(model_path)
		if not (res is PackedScene):
			return
		node = (res as PackedScene).instantiate()
		if info.has("weapon"):
			if not bool(info.get("hunyuan", false)):                   # a Hunyuan model keeps its own paint
				WeaponStyle.apply(node, info["weapon"], Data.skin_def(String(info.get("skin", "")), "weapon"), bool(info.get("worn", false)))
	var holder := Node3D.new()
	holder.add_child(node)
	var aabb := _merged_aabb(node)
	var axis: String = info.get("axis", "y")
	# turn the long axis to Y first
	var pre := Basis()
	match axis:
		"x": pre = Basis(Vector3(0, 0, 1), deg_to_rad(90.0))
		"z": pre = Basis(Vector3(1, 0, 0), deg_to_rad(-90.0))
	var size := aabb.size
	var long: float = size.y
	match axis:
		"x": long = size.x
		"z": long = size.z
	var k: float = float(info.get("length", 1.0)) / maxf(long, 0.001)
	var grip: float = float(info.get("grip", 0.2))
	var local_pivot := aabb.position + size * 0.5
	match axis:
		"y": local_pivot.y = aabb.position.y + size.y * grip
		"x": local_pivot.x = aabb.position.x + size.x * grip
		"z": local_pivot.z = aabb.position.z + size.z * grip
	node.transform = Transform3D(pre * Basis().scaled(Vector3.ONE * k), -(pre * (local_pivot * k)))
	var tilt := Basis(Vector3(1, 0, 0), deg_to_rad(180.0 + float(info.get("pitch", 0.0))))
	var roll := Basis(Vector3(0, 1, 0), deg_to_rad(float(info.get("roll", 0.0))))
	holder.transform = Transform3D(tilt * roll, info.get("offset", Vector3.ZERO))
	_hand.add_child(holder)
	_weapon_node = holder


func _merged_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		var t := Transform3D.IDENTITY
		var cur: Node = g
		while cur != null and cur != n.get_parent():
			if cur is Node3D:
				t = (cur as Node3D).transform * t
			cur = cur.get_parent()
		var b := t * g.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


# ----------------------------------------------------------------- animation

func _has(a: String) -> bool:
	return anim != null and anim.has_animation(a)


func play_state(state: String, force: bool = false) -> void:
	if anim == null:
		return
	if not force and (state == _state or _clock < _busy_until):
		return
	_state = state
	var name := ""
	var speed := 1.0
	match state:
		"idle": name = "Idle"
		"run": name = "Run"
		"sprint": name = "Sprint"
		"jump": name = "JumpStart"
		"fall": name = "JumpLoop"
		"land": name = "JumpLand"
		"slide": name = "SlideLoop"
		"cast_idle": name = "CastIdle"
		"death": name = "Death"
	if _has(name) and anim.current_animation != name:
		anim.play(name, -1.0, speed)


## One-shot clips: attack styles ("MeleeA", "MeleeB", "MeleeC", "Attack", "CastShoot", "Throw", "Hook", "HitChest", "HitHead", "Knockback", "Block",
## "Consume", "ChestOpen", "Revive", "SlideStart", "SlideExit", "CastEnter", "CastExit"). Locomotion resumes when it ends.
func play_once(name: String, speed: float = 1.0, lock: bool = true) -> void:
	if not _has(name):
		return
	anim.play(name, 0.06, speed)
	if lock:
		_busy_until = _clock + anim.get_animation(name).length / maxf(speed, 0.1) * 0.85
	_state = ""


func _process(delta: float) -> void:
	_clock += delta
	if _flash_mat != null and _flash_mat.albedo_color.a > 0.0:
		_flash_mat.albedo_color.a = maxf(0.0, _flash_mat.albedo_color.a - delta * 6.0)
		if _flash_mat.albedo_color.a <= 0.0:
			for m in meshes:
				(m as MeshInstance3D).material_overlay = null


func flash(color: Color = Color(1, 0.3, 0.3)) -> void:
	_flash_mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	for m in meshes:
		(m as MeshInstance3D).material_overlay = _flash_mat


## Ghost look for the local player's own invisibility (others simply cannot see the model).
func set_ghost(on: bool) -> void:
	for n in _armor_nodes:
		if is_instance_valid(n):
			(n as Node3D).visible = not on
	if on == _ghost:
		return
	_ghost = on
	for m in meshes:
		var mi := m as MeshInstance3D
		if on:
			var src: Material = mi.get_active_material(0)
			var g := StandardMaterial3D.new()
			if src is BaseMaterial3D:
				g.albedo_texture = (src as BaseMaterial3D).albedo_texture
			g.albedo_color = Color(0.75, 0.8, 1.0, 0.32)
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.material_override = g
		else:
			mi.material_override = null


func set_model_visible(v: bool) -> void:
	for n in _armor_nodes:
		if is_instance_valid(n):
			(n as Node3D).visible = v
	for m in meshes:
		(m as MeshInstance3D).visible = v
	if _weapon_node != null:
		_weapon_node.visible = v
	if _plate != null:
		_plate.visible = v
	if _ring != null:
		_ring.visible = v


## The class models are not centred on their feet (capes and weapons pull the model's middle sideways), so the body would orbit the team ring and the armory
## turntable. Put the hips of the rest pose over the origin instead.
func _center_on_hips(inst: Node3D) -> void:
	if skeleton == null:
		return
	var hi := skeleton.find_bone("DEF-hips")
	if hi < 0:
		return
	var t := Transform3D.IDENTITY
	var cur: Node = skeleton
	while cur != null and cur != inst:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	var hm: Vector3 = inst.transform.basis * (t * skeleton.get_bone_global_rest(hi).origin)
	inst.position = Vector3(-hm.x, 0.0, -hm.z)


func hide_ring() -> void:
	if _ring != null:
		_ring.visible = false


# ----------------------------------------------------------------- recipes: clips in a row, a body pose on top and a glow at the hands

## clips: [[clip, speed, hold_seconds (optional)], ...] played one after the other; poses: [[kind, amount, seconds, delay (optional)], ...].
## glow_mode: 0 none, 1 right hand, 2 both hands, 3 ground ring. Returns the total time the recipe takes.
func play_recipe(clips: Array, poses: Array, glow: Color = Color(0, 0, 0, 0), glow_mode: int = 0) -> float:
	if anim == null:
		return 0.0
	if _recipe_tween != null and _recipe_tween.is_valid():
		_recipe_tween.kill()
	_stop_poses()
	_recipe_tween = create_tween()
	var total := 0.0
	var first := true
	for c in clips:
		var clip: String = c[0]
		var spd: float = float(c[1]) if c.size() > 1 else 1.0
		var hold: float = float(c[2]) if c.size() > 2 else 0.0
		if not _has(clip):
			continue
		var dur: float = hold if hold > 0.0 else anim.get_animation(clip).length / maxf(spd, 0.1) * 0.9
		if first:
			anim.play(clip, 0.06, spd)
			first = false
		else:
			_recipe_tween.tween_callback(func() -> void: anim.play(clip, 0.06, spd))
		_recipe_tween.tween_interval(dur)
		total += dur
	_state = ""
	_busy_until = _clock + total
	for p in poses:
		var delay: float = float(p[3]) if p.size() > 3 else 0.0
		if delay <= 0.0:
			pose_kick(String(p[0]), float(p[1]), float(p[2]))
		else:
			var tw := create_tween()
			_pose_tweens.append(tw)
			tw.tween_interval(delay)
			tw.tween_callback(pose_kick.bind(String(p[0]), float(p[1]), float(p[2])))
	if glow.a > 0.0:
		match glow_mode:
			1: hand_glow(glow, minf(total, 0.9), false)
			2: hand_glow(glow, minf(total, 0.9), true)
			3: Fx.ring(global_position, 1.6, glow, minf(total, 0.8))
	return total


var _pose_tweens: Array = []


func _stop_poses() -> void:
	for t in _pose_tweens:
		if t is Tween and (t as Tween).is_valid():
			(t as Tween).kill()
	_pose_tweens.clear()
	if _pose != null:
		_pose.position = Vector3.ZERO
		_pose.rotation = Vector3.ZERO
		_pose.scale = Vector3.ONE


## A body movement on top of the clip, out and back: lean_fwd, lean_back, tilt, crouch, rise, hop, lunge, recoil, spin (amount = turns), pulse, shrink, shake, sway.
func pose_kick(kind: String, amt: float, secs: float) -> void:
	if _pose == null:
		return
	var out := secs * 0.4
	var back := secs * 0.6
	var tw := create_tween()
	_pose_tweens.append(tw)
	match kind:
		"lean_fwd": _there_back(tw, "rotation:x", -amt, 0.0, out, back)
		"lean_back": _there_back(tw, "rotation:x", amt, 0.0, out, back)
		"tilt": _there_back(tw, "rotation:z", amt, 0.0, out, back)
		"spin":
			tw.tween_property(_pose, "rotation:y", TAU * amt, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tw.tween_callback(func() -> void: _pose.rotation.y = 0.0)
		"crouch":
			_there_back(tw, "scale:y", 1.0 - amt, 1.0, out, back)
			var tw2 := create_tween()
			_pose_tweens.append(tw2)
			_there_back(tw2, "scale:x", 1.0 + amt * 0.3, 1.0, out, back)
		"rise": _there_back(tw, "position:y", amt, 0.0, out, back)
		"hop":
			tw.tween_property(_pose, "position:y", amt, secs * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(_pose, "position:y", 0.0, secs * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"lunge": _there_back(tw, "position:z", -amt, 0.0, out, back)
		"recoil": _there_back(tw, "position:z", amt, 0.0, out, back)
		"pulse":
			_there_back(tw, "scale", Vector3.ONE * (1.0 + amt), Vector3.ONE, out, back)
		"shrink":
			_there_back(tw, "scale", Vector3.ONE * (1.0 - amt), Vector3.ONE, out, back)
		"shake":
			tw.tween_method(func(f: float) -> void:
				_pose.position = Vector3(sin(f * 60.0) * amt * (1.0 - f), cos(f * 47.0) * amt * 0.5 * (1.0 - f), 0.0), 0.0, 1.0, secs)
			tw.tween_callback(func() -> void: _pose.position = Vector3.ZERO)
		"sway":
			tw.tween_method(func(f: float) -> void: _pose.rotation.z = sin(f * TAU * 1.5) * amt, 0.0, 1.0, secs)
			tw.tween_callback(func() -> void: _pose.rotation.z = 0.0)


func _there_back(tw: Tween, prop: String, target: Variant, home: Variant, out: float, back: float) -> void:
	tw.tween_property(_pose, prop, target, out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pose, prop, home, back).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _hand_attachment(bone: String) -> BoneAttachment3D:
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	skeleton.add_child(a)
	return a


## A glow that swells in one or both hands in `color`.
func hand_glow(color: Color, secs: float, both: bool) -> void:
	if skeleton == null:
		return
	if _hand == null:
		_hand = _hand_attachment(HAND_BONE)
	if both and _hand_l == null:
		_hand_l = _hand_attachment("DEF-hand.L")
	var hands: Array = [_hand]
	if both:
		hands.append(_hand_l)
	for h in hands:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = Fx.TEX["soft"]
		m.albedo_color = Color(color.r, color.g, color.b, 0.9)
		m.no_depth_test = false
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * 0.15
		(h as Node).add_child(mi)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.75, secs * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "albedo_color:a", 0.0, secs).set_delay(secs * 0.4)
		tw.chain().tween_callback(mi.queue_free)


func _make_matte(mi: MeshInstance3D, amount: float) -> void:
	for s in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(s)
		if src is BaseMaterial3D:
			var m := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			m.roughness = lerpf(m.roughness, 0.95, amount)
			m.metallic = lerpf(m.metallic, 0.0, amount)
			m.metallic_specular = lerpf(m.metallic_specular, 0.12, amount)
			m.rim_enabled = false
			mi.set_surface_override_material(s, m)
