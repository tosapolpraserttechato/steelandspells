class_name NetPuppet
extends Combatant
## LAN client: a copy of a fighter that lives on the host (another player, a bot or a summon). It only shows what the host sends: where it is, how it moves and how much health it has.
## Its attacks and skills are played from the host's messages (Net.replay) with every damage call switched off (Combatant.take_damage does nothing on a joined machine).

var net_id := 0
var target_pos := Vector3.ZERO
var target_yaw := 0.0
var net_state := "idle"


func setup_puppet(info: Dictionary) -> void:
	net_id = int(info["id"])
	setup(String(info["class"]), String(info["team"]), String(info.get("name", "")), false)
	var picks: Array = info.get("skills", [])
	if not picks.is_empty():
		skill_ids = picks.duplicate()
	var wid := String(info.get("weapon", ""))
	if Data.weapons.has(wid):
		weapon = Data.weapons[wid]
		model.hold_weapon(Weapons.visual_for(weapon, "", false))
	target_pos = info["pos"]
	if bool(info.get("minion", false)):
		set_plate_hidden()


## One entry of the host's snapshot: [id, position, model yaw, animation state, dead, health, max health].
func net_apply(e: Array) -> void:
	target_pos = e[1]
	target_yaw = float(e[2])
	net_state = String(e[3])
	var host_dead := bool(e[4])
	health = float(e[5])
	if host_dead and not dead:
		die(null)                                    # the event normally arrives first; this covers a lost one
	elif not host_dead and dead:
		respawn(target_pos)
	if model != null and not dead:
		model.set_health_fraction(health / maxf(float(e[6]), 1.0))


func _physics_process(delta: float) -> void:
	if dead:
		return
	var before := global_position
	global_position = global_position.lerp(target_pos, clampf(delta * 14.0, 0.0, 1.0))
	if global_position.distance_to(target_pos) > 12.0:
		global_position = target_pos                 # a teleport or a respawn
	velocity = (global_position - before) / maxf(delta, 0.001)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clampf(delta * 16.0, 0.0, 1.0))
	facing = Vector3(-sin(model.rotation.y), 0.0, -cos(model.rotation.y))
	model.play_state(net_state)
