class_name RemotePlayer
extends Combatant
## LAN host: a player on another machine. That machine moves its own character (so the controls feel instant there) and sends where it stands, which way it faces and which buttons
## are held; this fighter copies that and does the fighting on the host: attacks, skills, damage, statuses and death all happen here, like for any bot.

var peer_id := 0
var net_pos := Vector3.ZERO
var net_vel := Vector3.ZERO
var net_yaw := 0.0
var net_state := "idle"
var attack_held := false
var client_dead := false
var have_input := false


func setup_remote(info: Dictionary) -> void:
	is_remote = true
	remote_data = {"items": info.get("items", {}), "cards": info.get("cards", {}), "level": info.get("level", {})}      # before setup(): rebuild_stats reads it
	setup(String(info["class"]), String(info["team"]), String(info.get("name", "Guest")), false)
	var picks: Array = info.get("skills", [])
	if not picks.is_empty():
		skill_ids = picks.duplicate()


## One input packet from the player's machine: [position, model yaw, animation state, velocity, aim direction, aim point, attack held, dead].
func net_in(a: Array) -> void:
	client_dead = bool(a[7])
	if client_dead and not dead:
		return                                       # the player has not heard yet that they were brought back; keep the host's spawn point
	net_pos = a[0]
	net_yaw = float(a[1])
	net_state = String(a[2])
	net_vel = a[3]
	aim_dir = a[4]
	aim_point = a[5]
	attack_held = bool(a[6])
	if not have_input:
		have_input = true
		global_position = net_pos


func _physics_process(delta: float) -> void:
	tick(delta)
	if dead or not have_input:
		return
	global_position = global_position.lerp(net_pos, clampf(delta * 25.0, 0.0, 1.0))
	velocity = net_vel
	wish_dir = Vector3(net_vel.x, 0.0, net_vel.z)
	model.rotation.y = lerp_angle(model.rotation.y, net_yaw, clampf(delta * 20.0, 0.0, 1.0))
	facing = Vector3(-sin(net_yaw), 0.0, -cos(net_yaw))
	sprinting = net_state == "sprint"
	model.play_state(net_state)
	model.set_loco_speed(Vector2(net_vel.x, net_vel.z).length())
	if attack_held:
		WeaponRunner.attack(self)
