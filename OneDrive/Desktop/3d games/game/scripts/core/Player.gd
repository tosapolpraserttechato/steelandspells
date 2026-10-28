class_name Player
extends Combatant
## The local player: third-person over-the-shoulder camera, mouse aim, keyboard movement, skills, weapon, interact, potions.

signal interact_prompt(text: String)
signal camera_hit(strength: float)

const MOUSE_SENS := 0.0024

var cam_rig: Node3D
var arm: SpringArm3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.15
var ui_blocked := false                     # a menu / card picker / crate screen is open
var shake := 0.0
var interact_target: Node = null
const SNIPE_FAMILIES := ["bow", "spiritbow", "crossbow", "staff", "wand", "orb"]     # hold aim for a second and the next shot is a long, hard sniper shot
const SNIPE_READY := 0.9
var aiming := false
var _fov := 75.0
var _respawn_cam_t := 0.0


func setup_player(cls: String, name_text: String, team_name: String = "red") -> void:
	setup(cls, team_name, name_text, true)
	cam_rig = Node3D.new()
	cam_rig.top_level = true
	add_child(cam_rig)
	arm = SpringArm3D.new()
	arm.spring_length = 3.4
	arm.collision_mask = 1
	arm.margin = 0.25
	arm.shape = SphereShape3D.new()
	(arm.shape as SphereShape3D).radius = 0.25
	cam_rig.add_child(arm)
	cam = Camera3D.new()
	cam.fov = _fov
	cam.far = 900.0
	cam.near = 0.08
	cam.current = true
	arm.add_child(cam)
	cam.position = Vector3(0.0, 0.0, 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	skill_ids = Game.skills_for(cls).duplicate()
	damaged.connect(func(amount: float, _s: Node, _i: Dictionary) -> void: shake = minf(1.0, shake + amount / 60.0))


func _unhandled_input(event: InputEvent) -> void:
	if ui_blocked or dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = MOUSE_SENS * float(Settings.v["sensitivity"]) * (0.4 if (aiming and snipe_charge >= SNIPE_READY) else (0.6 if aiming else 1.0))
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens * (-1.0 if bool(Settings.v["invert_y"]) else 1.0), -1.25, 0.9)


func _physics_process(delta: float) -> void:
	tick(delta)
	_update_camera(delta)
	if dead:
		physics_move(delta, Vector3.ZERO, false)
		return
	var wish := Vector3.ZERO
	var jump := false
	var sprint := false
	var slide := false
	if not ui_blocked:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var basis := Basis(Vector3.UP, yaw)
		wish = (basis * Vector3(iv.x, 0, iv.y))
		if wish.length() > 1.0:
			wish = wish.normalized()
		jump = Input.is_action_just_pressed("jump")
		sprint = Input.is_action_pressed("sprint")
		slide = Input.is_action_just_pressed("slide")
		aiming = Input.is_action_pressed("aim")
	wish_dir = wish
	_update_aim()
	if aiming and not dead and not weapon.is_empty() and String(weapon.get("family", "")) in SNIPE_FAMILIES:
		var was_ready := snipe_charge >= SNIPE_READY
		snipe_charge += delta
		if not was_ready and snipe_charge >= SNIPE_READY:
			Sfx.play("chime", -4.0, 1.5)
	else:
		snipe_charge = maxf(0.0, snipe_charge - delta * 4.0)
	# face where the camera looks while fighting, else where we run
	if aiming or Input.is_action_pressed("attack") or casting_lock > 0.0:
		face_toward(Vector3(-sin(yaw), 0, -cos(yaw)), false, delta)
	elif wish.length() > 0.1:
		face_toward(wish, false, delta)
	physics_move(delta, wish, jump, sprint, slide)
	if not ui_blocked:
		_handle_actions()
	_update_unseen(delta)
	_find_interactable()
	if Net.is_client:
		Net.client_update(self, delta)


func _update_camera(delta: float) -> void:
	if cam_rig == null:
		return
	var follow := global_position + Vector3(0, 1.55 * float(stats.value("size", 1.0)), 0)
	cam_rig.global_position = cam_rig.global_position.lerp(follow, clampf(delta * 18.0, 0.0, 1.0))
	cam_rig.rotation = Vector3(pitch, yaw, 0)
	var side := 0.9 if not aiming else 0.6
	arm.spring_length = lerpf(arm.spring_length, 3.3 if not aiming else 2.4, clampf(delta * 8.0, 0.0, 1.0))
	cam.position = cam.position.lerp(Vector3(side, 0.25, 0), clampf(delta * 10.0, 0.0, 1.0))
	var base_fov: float = float(Settings.v["fov"])
	var target_fov := 32.0 if (aiming and snipe_charge >= SNIPE_READY) else (base_fov - 5.0 if aiming else (base_fov + 7.0 if sprinting else base_fov))
	_fov = lerpf(_fov, target_fov, clampf(delta * 6.0, 0.0, 1.0))
	cam.fov = _fov
	if shake > 0.0:
		cam.h_offset = randf_range(-1, 1) * shake * 0.05 * float(Settings.v["shake"])
		cam.v_offset = randf_range(-1, 1) * shake * 0.05 * float(Settings.v["shake"])
		shake = maxf(0.0, shake - delta * 2.5)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


## The point under the crosshair: ray from the camera through the screen centre.
func _update_aim() -> void:
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from + dir * 1.0, from + dir * 220.0, 1 | 2)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var point: Vector3 = hit["position"] if not hit.is_empty() else from + dir * 220.0
	aim_point = point
	var origin := chest_position()
	aim_dir = (point - origin).normalized()
	if (point - origin).length() < 2.0:
		aim_dir = dir


func _handle_actions() -> void:
	if Net.is_client:
		# a joined game: the host runs the attacks and skills; here the presses are only sent (see Net.client_update for the held attack button)
		for pair in [["skill_1", "s1"], ["skill_2", "s2"], ["skill_3", "s3"], ["skill_sig", "sig"], ["ultimate", "ult"]]:
			if Input.is_action_just_pressed(pair[0]):
				Net.client_skill(String(pair[1]), aim_dir, aim_point)
		if Input.is_action_just_pressed("potion"):
			use_potion()
		if Input.is_action_just_pressed("quest_skill"):
			QuestSkills.use(self)
		if Input.is_action_just_pressed("interact") and interact_target != null and is_instance_valid(interact_target):
			interact_target.interact(self)
		return
	if Input.is_action_pressed("attack"):
		WeaponRunner.attack(self)
	if Input.is_action_just_pressed("skill_1"):
		SkillRunner.use(self, "s1")
	if Input.is_action_just_pressed("skill_2"):
		SkillRunner.use(self, "s2")
	if Input.is_action_just_pressed("skill_3"):
		SkillRunner.use(self, "sig" if false else "s3")
	if Input.is_action_just_pressed("skill_sig"):
		SkillRunner.use(self, "sig")
	if Input.is_action_just_pressed("ultimate"):
		SkillRunner.use(self, "ult")
	if Input.is_action_just_pressed("potion"):
		use_potion()
	if Input.is_action_just_pressed("quest_skill"):
		QuestSkills.use(self)
	if Input.is_action_just_pressed("interact") and interact_target != null and is_instance_valid(interact_target):
		interact_target.interact(self)


func use_potion() -> bool:
	for id in ["potion_health", "potion_mana", "potion_shield", "potion_speed", "potion_cleanse", "potion_rage"]:
		if Game.potions.get(id, 0) > 0:
			return drink(id)
	return false


func drink(id: String) -> bool:
	if not Game.use_potion(id):
		return false
	if Net.is_client:
		Net.client_drink(id)                                 # the host applies it for real; here only the picture
	apply_potion(id)
	return true


func _update_unseen(delta: float) -> void:
	# hidden recovery: no enemy has line of sight for a while
	var seen := false
	if match_ref != null:
		for e in match_ref.enemies_of(team):
			if e.dead:
				continue
			if e.global_position.distance_to(global_position) < float(e.stats.value("sight", 70.0)) and e.has_line_of_sight(self):
				seen = true
				break
	if seen:
		unseen_time = 0.0
	else:
		unseen_time += delta


func _find_interactable() -> void:
	var best: Node = null
	var bd := 3.2
	if match_ref != null:
		for n in match_ref.interactables:
			if not is_instance_valid(n) or not n.can_interact(self):
				continue
			var d: float = n.global_position.distance_to(global_position)
			if d < bd:
				bd = d
				best = n
	if best != interact_target:
		interact_target = best
		interact_prompt.emit(best.prompt_text() if best != null else "")


func die(killer: Node) -> void:
	super.die(killer)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if false else Input.mouse_mode


func set_ui_blocked(b: bool) -> void:
	ui_blocked = b
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if b else Input.MOUSE_MODE_CAPTURED
