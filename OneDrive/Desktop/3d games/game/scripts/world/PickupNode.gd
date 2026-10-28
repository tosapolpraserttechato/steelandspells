class_name PickupNode
extends Node3D
## Health, ammo, armor and power-weapon pickups from the map's `pickup` markers. Walk over one to take it; it comes back after 30 s.

var item := "health"
var radius := 1.6
var respawn := 30.0
var _timer := 0.0
var _icon: Sprite3D
var _glow: Node3D
var _active := true
var _t := 0.0


func setup(kind: String) -> void:
	item = kind
	var info := _info(kind)
	_icon = Sprite3D.new()
	_icon.texture = Fx.TEX[info["tex"]]
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.modulate = info["color"]
	_icon.pixel_size = 0.012
	_icon.shaded = false
	_icon.transparent = true
	_icon.position = Vector3(0, 1.3, 0)
	add_child(_icon)
	_glow = Fx.particles({"tex": "soft", "amount": 8, "life": 1.4, "shape": "ring", "radius": 0.7, "dir": Vector3.UP, "spread": 5, "vel": [0.4, 0.9], "size": [0.12, 0.22],
		"colors": [Color(info["color"].r, info["color"].g, info["color"].b, 0), Color(info["color"].r, info["color"].g, info["color"].b, 0.9), Color(info["color"].r, info["color"].g, info["color"].b, 0)]})
	add_child(_glow)
	var light := OmniLight3D.new()
	light.light_color = info["color"]
	light.light_energy = 0.8
	light.omni_range = 5.0
	light.position = Vector3(0, 1.0, 0)
	add_child(light)


static func _info(kind: String) -> Dictionary:
	match kind:
		"health": return {"tex": "star", "color": Color(0.4, 1.0, 0.5), "name": "Healing"}
		"ammo": return {"tex": "arrow", "color": Color(1.0, 0.85, 0.35), "name": "Ammo and mana"}
		"armor": return {"tex": "hex", "color": Color(0.5, 0.8, 1.0), "name": "Armor"}
		"power_weapon": return {"tex": "star", "color": Color(1.0, 0.35, 0.3), "name": "Power"}
	return {"tex": "soft", "color": Color.WHITE, "name": kind}


func tick(delta: float, combatants: Array) -> void:
	_t += delta
	if _icon != null:
		_icon.position.y = 1.3 + sin(_t * 2.0) * 0.12
	if not _active:
		_timer -= delta
		if _timer <= 0.0:
			_active = true
			_icon.visible = true
			_glow.visible = true
		return
	for c in combatants:
		if c.dead:
			continue
		if c.global_position.distance_to(global_position) < radius and _wants(c):
			_give(c)
			_active = false
			_timer = respawn
			_icon.visible = false
			_glow.visible = false
			return


## LAN host: is it there to take?
func is_up() -> bool:
	return _active


## LAN client: show the pickup as taken or back, as the host says.
func set_up(up: bool) -> void:
	if _icon == null or up == _active:
		return
	_active = up
	_icon.visible = up
	_glow.visible = up
	if not up:
		Fx.ring(global_position, 2.0, _info(item)["color"], 0.5)


func _wants(c: Combatant) -> bool:
	match item:
		"health": return c.health < c.max_health() - 1.0
		"ammo": return c.mana < c.max_mana() - 1.0 or (c.weapon.has("ammo") and c.ammo < float(c.weapon["ammo"]))
	return true


func _give(c: Combatant) -> void:
	var col: Color = _info(item)["color"]
	Fx.ring(global_position, 2.0, col, 0.5)
	match item:
		"health":
			c.heal(c.max_health() * 0.5 * (1.0 + c.stats.mult_sum("heal_pickup")), c)
		"ammo":
			c.restore_mana(c.max_mana() * 0.5)
			if c.weapon.has("ammo"):
				c.ammo = float(c.weapon["ammo"]) * (1.0 + c.stats.mult_sum("max_ammo"))
				c.reload_left = 0.0
		"armor":
			c.statuses.apply("barrier", 12.0, 1, c, 1.4)
		"power_weapon":
			c.statuses.apply("empower", 15.0, 1, c)
			c.statuses.apply("haste", 5.0, 1, c)
