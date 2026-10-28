class_name HazardNode
extends Node3D
## Map hazards and field mechanics from the map's markers (kind: hazard, bounce_pad, slide, current, updraft, spore_pod, jump_pad, cannon).
## The numbers come from each marker (radius, damage, interval...); this script decides what each hazard does.

var kind := ""                       # marker kind
var hz := ""                         # hazard / mechanic name
var data: Dictionary = {}
var radius := 4.0
var match_ref: Match = null
var _t := 0.0
var _phase := "wait"                 # for periodic hazards: wait -> warn -> burst
var _phase_t := 0.0
var _vis: Node3D
var _telegraph: Node3D
var _pod_timer := 0.0
var _cannon_cd := 0.0
var _dir := Vector3.ZERO
var _target := Vector3.ZERO
var _inside: Dictionary = {}


func setup(marker: Dictionary, ref: Match) -> void:
	match_ref = ref
	data = marker
	kind = String(marker.get("kind", ""))
	hz = String(marker.get("hazard", marker.get("mechanic", "")))
	radius = float(marker.get("radius", marker.get("cap_radius", 3.0)))
	position = marker["pos"]
	if marker.has("direction"):
		var d: Array = marker["direction"]
		_dir = Vector3(float(d[0]), 0.0, -float(d[1])).normalized()
	if marker.has("target"):
		_target = MapLoader.blender_to_godot(marker["target"])
	_phase_t = randf_range(0.0, float(marker.get("interval_seconds", 10.0)))
	match kind:
		"hazard":
			_make_hazard_visual()
		"jump_pad", "bounce_pad":
			var col := Color(0.5, 0.9, 1.0) if kind == "jump_pad" else Color(1.0, 0.9, 0.4)
			if not marker.get("quiet", false):
				add_child(Fx.hazard("spores", radius) if kind == "bounce_pad" else _pad_fx(col))
		"updraft":
			add_child(Fx.hazard("moon_dust", radius))
		"spore_pod":
			add_child(Fx.hazard("spores", radius))
		"cannon":
			pass


func _pad_fx(col: Color) -> Node3D:
	var n := Node3D.new()
	n.add_child(Fx.particles({"tex": "star", "amount": 10, "life": 1.0, "shape": "ring", "radius": radius, "dir": Vector3.UP, "spread": 6, "vel": [1.0, 2.5], "size": [0.12, 0.25],
		"colors": [Color(col.r, col.g, col.b, 0), Color(col.r, col.g, col.b, 1), Color(col.r, col.g, col.b, 0)]}))
	return n


func _make_hazard_visual() -> void:
	var fxkind := ""
	match hz:
		"lava": fxkind = "lava"
		"steam_vent": fxkind = "steam"
		"poison_water": fxkind = "poison_water"
		"quicksand": fxkind = "quicksand"
		"thorn_vines": fxkind = "spores"
		"avalanche": fxkind = "snow"
		"eclipse_dark_zone": fxkind = "fog_wisp"
		"cursed_grave": fxkind = "fog_wisp"
		"jellyfish_swarm": fxkind = "bubbles"
	if fxkind != "":
		_vis = Fx.hazard(fxkind, radius)
		add_child(_vis)


func tick(delta: float, combatants: Array) -> void:
	_t += delta
	match kind:
		"hazard": _tick_hazard(delta, combatants)
		"jump_pad": _tick_pad(combatants, false)
		"bounce_pad": _tick_pad(combatants, true)
		"slide", "current": _tick_push(delta, combatants)
		"updraft": _tick_updraft(delta, combatants)
		"spore_pod": _tick_pod(delta, combatants)
		"cannon": _cannon_cd = maxf(0.0, _cannon_cd - delta)


func _inside_any(combatants: Array, r: float) -> Array:
	var out: Array = []
	for c in combatants:
		if c.dead:
			continue
		var d: Vector3 = c.global_position - global_position
		if Vector2(d.x, d.z).length() <= r and absf(d.y) < 5.0:
			out.append(c)
	return out


# ----------------------------------------------------------------- hazards

func _tick_hazard(delta: float, combatants: Array) -> void:
	match hz:
		"thorn_vines":
			for c in _inside_any(combatants, radius):
				c.statuses.apply("slow", 1.0, 1, null)
				c.take_damage(4.0 * delta, null, {"dot": "thorns", "no_status": true, "color": [0.4, 0.8, 0.3]})
		"quicksand":
			for c in _inside_any(combatants, radius):
				c.statuses.apply("slow", 1.2, 1, null)
				c.velocity.y = minf(c.velocity.y, 0.0)
				c.take_damage(float(data.get("damage_per_second", 6.0)) * delta, null, {"dot": "quicksand", "no_status": true, "color": [0.9, 0.75, 0.4]})
		"poison_water":
			for c in _inside_any(combatants, radius):
				c.statuses.apply("poison", 3.0, 1, null)
				c.take_damage(float(data.get("damage_per_second", 7.0)) * delta, null, {"dot": "poison_water", "no_status": true, "color": [0.5, 0.95, 0.25]})
		"lava":
			for c in _inside_any(combatants, radius):
				c.statuses.apply("burn", 3.0, 2, null)
				c.take_damage(28.0 * delta, null, {"dot": "lava", "no_status": true, "color": [1.0, 0.5, 0.1]})
		"jellyfish_swarm":
			position += _dir * 0.6 * delta * sin(_t * 0.3) * 0.0
			for c in _inside_any(combatants, radius):
				c.statuses.apply("shock", 4.0, 1, null)
		"eclipse_dark_zone":
			for c in _inside_any(combatants, radius):
				c.statuses.apply("weaken", 1.2, 1, null)
				c.statuses.absorb(float(data.get("shield_drain_per_second", 12.0)) * delta)
		"rising_tide":
			for c in _inside_any(combatants, radius):
				if c.global_position.y < float(data.get("flood_level_z", 1.0)) + 1.0:
					c.statuses.apply("slow", 1.0, 1, null)
		"cursed_grave":
			_phase_t -= delta
			if _phase_t <= 0.0:
				_phase_t = float(data.get("ghost_interval_seconds", 25.0))
				match_ref.spawn_ghost(global_position + Vector3(0, 1.0, 0), float(data.get("ghost_speed", 4.5)), float(data.get("ghost_damage", 18.0)))
		"steam_vent", "lightning_strike", "avalanche", "falling_stalactite", "falling_piece":
			_tick_periodic(delta, combatants)


## wait (interval) -> warn (telegraph) -> burst.
func _tick_periodic(delta: float, combatants: Array) -> void:
	var interval := float(data.get("interval_seconds", 20.0))
	var warn := float(data.get("warning_seconds", 2.5))
	_phase_t -= delta
	match _phase:
		"wait":
			if _phase_t <= 0.0:
				_phase = "warn"
				_phase_t = warn
				var col := _hazard_color()
				_telegraph = Fx.telegraph(global_position, radius, col, warn)
		"warn":
			if _phase_t <= 0.0:
				_phase = "burst"
				_phase_t = float(data.get("burst_seconds", 0.0))
				_do_burst(combatants)
				if _phase_t <= 0.0:
					_phase = "wait"
					_phase_t = interval
		"burst":
			# steam keeps burning while the vent runs
			for c in _inside_any(combatants, radius):
				c.statuses.apply("burn", 2.0, 1, null)
				c.take_damage(float(data.get("damage_per_second", 14.0)) * delta, null, {"dot": "steam", "no_status": true, "color": [1.0, 0.6, 0.2]})
			if _phase_t <= 0.0:
				_phase = "wait"
				_phase_t = interval


func _hazard_color() -> Color:
	match hz:
		"lightning_strike": return Color(0.9, 0.9, 0.4)
		"avalanche": return Color(0.8, 0.92, 1.0)
		"steam_vent": return Color(1.0, 0.6, 0.3)
		"falling_stalactite": return Color(0.7, 0.8, 1.0)
		"falling_piece": return Color(1.0, 0.4, 0.4)
	return Color(1.0, 0.5, 0.3)


func _do_burst(combatants: Array) -> void:
	var col := _hazard_color()
	match hz:
		"lightning_strike":
			Fx.lightning_strike(global_position)
			_hit_area(combatants, 90.0, [{"id": "shock", "dur": 3.0}])
		"avalanche":
			Fx.impact(global_position + Vector3(0, 1.5, 0), col, true)
			Fx.ring(global_position, radius, col, 0.8)
			_hit_area(combatants, 120.0, [{"id": "chill", "dur": 4.0, "n": 3}], _dir * 12.0)
		"falling_stalactite", "falling_piece":
			Fx.impact(global_position + Vector3(0, 0.5, 0), col, true)
			Fx.ring(global_position, radius, col, 0.5)
			_hit_area(combatants, float(data.get("damage", 45.0)), [{"id": "stun", "dur": 1.0}] if hz == "falling_piece" else [])
		"steam_vent":
			Fx.impact(global_position + Vector3(0, 1.0, 0), col, true)


func _hit_area(combatants: Array, dmg: float, list: Array, push: Vector3 = Vector3.ZERO) -> void:
	for c in _inside_any(combatants, radius + 0.4):
		c.take_damage(dmg, null, {"dot": "hazard", "no_status": true, "color": [_hazard_color().r, _hazard_color().g, _hazard_color().b]})
		for s in list:
			c.statuses.apply(String(s["id"]), float(s.get("dur", -1.0)), int(s.get("n", 1)), null)
		if push != Vector3.ZERO:
			c.add_impulse(push)
		else:
			c.add_impulse(Vector3(0, 6.0, 0))


# ----------------------------------------------------------------- field mechanics

func _tick_pad(combatants: Array, bounce: bool) -> void:
	for c in _inside_any(combatants, radius + 0.5):
		if int(c.get_meta("pad_cd_" + str(get_instance_id()), 0)) > Time.get_ticks_msec():
			continue
		c.set_meta("pad_cd_" + str(get_instance_id()), Time.get_ticks_msec() + 900)
		var g := 24.0
		if bounce:
			if data.get("inward", false):                     # a mushroom foot: fly in toward the middle of the cap so you land on it
				var to_c: Vector3 = global_position - c.global_position
				to_c.y = 0.0
				c.forced_vel = to_c.normalized() * minf(to_c.length() * 1.2, 7.0)
				c.forced_time = 1.1
			else:
				c.forced_vel = Vector3(c.velocity.x * 0.6, 0, c.velocity.z * 0.6)
				c.forced_time = 0.9
			c.velocity.y = float(data.get("launch_speed", 17.0))
		else:
			var t := float(data.get("launch_seconds", 1.1))
			var from: Vector3 = c.global_position
			var to := _target
			var v := Vector3((to.x - from.x) / t, (to.y - from.y + 0.5 * g * t * t) / t, (to.z - from.z) / t)
			c.forced_vel = Vector3(v.x, 0, v.z)
			c.forced_time = t * 0.95
			c.velocity.y = v.y
		c.model.play_state("jump", true)
		Fx.ring(global_position, radius + 1.0, Color(0.5, 0.9, 1.0), 0.4)
		Fx.impact(global_position + Vector3(0, 0.3, 0), Color(0.6, 0.95, 1.0), false)
		if c.is_player:
			match_ref.quests.on_event("jump_pad", {})
			if not data.get("quiet", false):
				match_ref.hud_toast("Launch!", Color(0.6, 0.95, 1.0))


func _tick_push(delta: float, combatants: Array) -> void:
	var half := float(data.get("width", 5.0)) * 0.5
	var strength := 14.0 if String(data.get("boost", data.get("strength", "fast"))) == "fast" else 8.0
	for c in _inside_any(combatants, maxf(half, radius) + 2.0):
		var rel: Vector3 = c.global_position - global_position
		var side := (rel - _dir * rel.dot(_dir)).length()
		if side <= half + 1.0 and absf(rel.dot(_dir)) < 12.0:
			c.add_impulse(_dir * strength * delta * 6.0)


func _tick_updraft(delta: float, combatants: Array) -> void:
	var top := float(data.get("top_height", 17.0))
	var base := float(data.get("base_height", 0.0))
	for c in _inside_any(combatants, radius * 1.3):
		if c.global_position.y < position.y + top and c.global_position.y > position.y + base - 3.0:
			c.velocity.y = minf(c.velocity.y + 40.0 * delta, 11.0)


func _tick_pod(delta: float, combatants: Array) -> void:
	if _pod_timer > 0.0:
		_pod_timer -= delta
		visible = _pod_timer <= 0.0
		return
	for c in _inside_any(combatants, radius + 0.6):
		_pod_timer = float(data.get("respawn_seconds", 45.0))
		visible = false
		c.statuses.apply("haste", float(data.get("boost_seconds", 4.0)), 1, c)
		c.add_meter(float(data.get("meter_charge", 15.0)))
		Fx.impact(global_position + Vector3(0, 0.8, 0), Color(0.9, 0.85, 0.4), true)
		break


# ----------------------------------------------------------------- interactables (cannon)

func can_interact(_p: Node) -> bool:
	return kind == "cannon" and _cannon_cd <= 0.0


func prompt_text() -> String:
	return "Press G to fire the cannon"


func interact(player: Node) -> void:
	if kind != "cannon" or _cannon_cd > 0.0:
		return
	_cannon_cd = float(data.get("reload_seconds", 8.0))
	var from: Vector3 = global_position + Vector3(0, 1.4, 0)
	var dir: Vector3 = (player.aim_point - from).normalized()
	var p := Projectile.new()
	p.speed = 60.0
	p.dmg = float(data.get("damage", 150.0))
	p.splash = float(data.get("splash_radius", 4.0))
	p.life = 4.0
	p.arc = true
	p.kind = "fire"
	p.color = Color(1.0, 0.6, 0.2)
	p.skill = true
	p.launch(player, from, dir + Vector3(0, 0.08, 0))
	Fx.impact(from, Color(1.0, 0.7, 0.3), true)
