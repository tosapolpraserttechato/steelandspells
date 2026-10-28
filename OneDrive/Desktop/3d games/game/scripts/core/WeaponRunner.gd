class_name WeaponRunner
extends RefCounted
## The basic attack of the equipped weapon (mouse 1): melee swings in an arc, bows and crossbows shoot arrows and bolts (ammo),
## staffs, wands, orbs, tomes and spirit bows cast bolts (mana), thrown weapons arc, gauntlets punch with a small shockwave.

const MELEE_ANIMS := ["MeleeA", "MeleeB", "MeleeC"]


static func attack(c: Combatant) -> bool:
	if c.dead or c.attack_cd > 0.0 or c.casting_lock > 0.0 or c.reload_left > 0.0:
		return false
	if not c.statuses.can_attack():
		return false
	var w: Dictionary = c.weapon
	if w.is_empty():
		return false
	var rate: float = float(w.get("rate", 1.5)) * (1.0 + c.stats.mult_sum("fire_rate"))
	var ramp: Array = (w.get("mech", {}) as Dictionary).get("ramp", [])
	if not ramp.is_empty():                                # the longer it keeps firing, the faster it shoots (ramp: [gain per shot, most stacks])
		var now := Time.get_ticks_msec() / 1000.0
		var n := int(c.get_meta("ramp_n", 0))
		if now - float(c.get_meta("ramp_t", -9.0)) > 1.4:
			n = 0
		c.set_meta("ramp_n", mini(n + 1, int(ramp[1])))
		c.set_meta("ramp_t", now)
		rate *= 1.0 + float(ramp[0]) * float(n)
	if c.statuses.has("chill") or c.statuses.has("slow"):
		rate *= 0.9
	c.attack_cd = 1.0 / maxf(rate, 0.2)
	var fire: String = w["fire"]
	var mana_cost: float = float(w.get("mana", 0.0))
	var power := 1.0
	if mana_cost > 0.0:
		if not c.spend_mana(mana_cost):
			power = 0.55                                # out of mana: weak attack
	if w.has("ammo") and fire != "melee":
		if c.ammo < 1.0:
			c.reload_left = 1.6 / (1.0 + c.stats.mult_sum("reload_speed") - c.stats.mult_sum("reload_time"))
			return false
		c.ammo -= 1.0
		if c.ammo < 1.0:
			c.reload_left = 1.6 / maxf(0.3, 1.0 + c.stats.mult_sum("reload_speed") - c.stats.mult_sum("reload_time"))
	Sfx.at("swing" if fire == "melee" else "zap", c.global_position, -3.0, 0.9 + 0.2 * randf())
	match fire:
		"melee": _melee(c, w, power)
		"projectile": _shoot(c, w, power, false)
		"thrown": _shoot(c, w, power, true)
	c.add_meter(2.0)
	c.attacked.emit()
	return true


## The mechanics a weapon can have (the "mech" key of its data): lifesteal, execute [hp fraction, multiplier], lunge, double (second strike at that fraction), pull, knock, chain [targets, falloff],
## mana_hit, ramp [rate gain per shot, most stacks] (see attack), burst [shots, gap], pierce, homing. Several can be combined.
static func _after_hit(c: Combatant, victim: Combatant, dealt: float, w: Dictionary, color: Color) -> void:
	var mech: Dictionary = w.get("mech", {})
	if mech.is_empty() or dealt <= 0.0:
		return
	if mech.has("lifesteal"):
		c.heal(dealt * float(mech["lifesteal"]), null, false)
	if mech.has("mana_hit"):
		c.mana = minf(c.max_mana(), c.mana + float(mech["mana_hit"]))
		c.mana_changed.emit(c.mana, c.max_mana())
	if mech.has("chain"):
		var n: int = int(mech["chain"][0])
		var falloff: float = float(mech["chain"][1])
		var hit := 0
		var others: Array = []
		for e in c.match_ref.enemies_of(c.team):
			if e != victim and not e.dead and e.global_position.distance_to(victim.global_position) < 8.0:
				others.append(e)
		others.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.global_position.distance_to(victim.global_position) < b.global_position.distance_to(victim.global_position))
		for e in others:
			if hit >= n:
				break
			c.deal(e, dealt * falloff, {"magic": bool(w["magic"]), "no_status": true})
			Fx.impact(e.chest_position(), color, false)
			Fx.ring(e.global_position, 0.9, color, 0.2)
			hit += 1


static func _melee(c: Combatant, w: Dictionary, power: float) -> void:
	var mech: Dictionary = w.get("mech", {})
	var reach: float = float(w.get("range", 3.2)) * (1.0 + c.stats.mult_sum("weapon_range")) + 0.4
	var arc: float = float(w.get("arc", 100.0))
	var color := Weapons.color_for(w)
	c.combo = (c.combo + 1) % MELEE_ANIMS.size()
	if c.model != null:
		AnimRecipes.play_weapon(c, w, c.combo, float(w.get("rate", 1.5)) / 1.5)
		Fx.slash_trail(c.model, color, arc, reach * 0.95, 1.0 * float(c.stats.value("size", 1.0)), c.combo % 2 == 1)
	c.casting_lock = 0.12
	var dmg_base: float = float(w.get("dmg", 40.0)) * power
	var fwd := SkillRunner._aim_dir(c)
	fwd.y = 0.0
	fwd = fwd.normalized()
	if mech.has("lunge"):
		c.add_impulse(fwd * float(mech["lunge"]) * 1.6)                  # the swing carries you forward
	# one round of hits; `scale` is 1 for the first strike and the "double" fraction for the second
	var strike := func(scale: float) -> void:
		if not is_instance_valid(c) or c.dead:
			return
		var hit_any := false
		for e in c.match_ref.enemies_of(c.team):
			if e.dead:
				continue
			var rel: Vector3 = e.global_position - c.global_position
			rel.y = 0.0
			var d := rel.length()
			var tolerance := 0.45 * float(e.stats.value("size", 1.0))
			if d > reach + tolerance:
				continue
			if d > 0.6 and fwd.angle_to(rel.normalized()) > deg_to_rad(arc * 0.5) + atan2(tolerance, maxf(d, 0.1)):
				continue
			var amount := dmg_base * scale
			if mech.has("execute") and e.health < e.max_health() * float(mech["execute"][0]):
				amount *= float(mech["execute"][1])
			var info := {"magic": bool(w["magic"]), "melee": true, "aoe": false}
			var dealt := c.deal(e, amount, info)
			hit_any = true
			var kb: float = 3.0 + (3.0 if String(w["family"]) in ["heavy", "mace"] else 0.0) + float(mech.get("knock", 0.0))
			e.add_impulse(rel.normalized() * kb * 0.5)
			if mech.has("pull"):
				e.add_impulse(-rel.normalized() * float(mech["pull"]) * 1.2)
			if w.has("stun") and randf() < float(w["stun"]):
				e.statuses.apply("stun", 0.5, 1, c)
			Fx.impact(e.chest_position(), color, false)
			_after_hit(c, e, dealt, w, color)
			if c.stats.add_sum("melee_shockwave") > 0.0:
				Fx.ring(c.global_position, 3.0, color, 0.3)
				for e2 in c.match_ref.enemies_of(c.team):
					if e2 != e and not e2.dead and e2.global_position.distance_to(e.global_position) < 3.5:
						c.deal(e2, dmg_base * c.stats.add_sum("melee_shockwave"), {"magic": bool(w["magic"]), "melee": true, "no_status": true})
		if w.has("shockwave") and scale >= 1.0:
			Fx.ring(c.global_position + fwd * 1.5, float(w["shockwave"]), color, 0.35)
			for e in c.match_ref.enemies_of(c.team):
				if not e.dead and e.global_position.distance_to(c.global_position + fwd * 1.5) <= float(w["shockwave"]):
					var sd := c.deal(e, dmg_base * 0.35, {"magic": true, "aoe": true, "no_status": true})
					if mech.has("pull"):
						e.add_impulse((c.global_position - e.global_position).normalized() * float(mech["pull"]) * 0.8)
					_after_hit(c, e, sd, w, color)
		var mc := c.stats.add_sum("melee_cdr")
		if hit_any and mc > 0.0:
			for s in c.cooldowns:
				c.cooldowns[s] = maxf(0.0, c.cooldowns[s] - mc)
	Util.after(c, 0.13, func() -> void: strike.call(1.0))
	if mech.has("double"):
		Util.after(c, 0.30, func() -> void:
			if c.model != null:
				Fx.slash_trail(c.model, color, arc, reach * 0.9, 1.0, c.combo % 2 == 0)
			strike.call(float(mech["double"])))


static func _shoot(c: Combatant, w: Dictionary, power: float, thrown: bool) -> void:
	var mech: Dictionary = w.get("mech", {})
	var color := Weapons.color_for(w)
	var kind := Weapons.bolt_kind(w)
	if c.model != null:
		c.combo = (c.combo + 1) % 6
		AnimRecipes.play_weapon(c, w, c.combo, float(w.get("rate", 1.5)) / 1.5)
	c.casting_lock = 0.1
	var count: int = int(w.get("count", 1))
	var spread: float = float(w.get("spread", 0.0))
	var base := SkillRunner._aim_dir(c)
	var jitter := deg_to_rad(float(w.get("spread_base", 0.6))) * maxf(0.0, 1.0 + c.stats.mult_sum("weapon_spread"))
	var charge: float = float(w.get("charge", 0.0))
	var delay := charge * 0.25
	var volleys := 1
	var gap := 0.0
	if mech.has("burst"):
		volleys = int(mech["burst"][0])
		gap = float(mech["burst"][1])
	var go := func() -> void:
		if not is_instance_valid(c) or c.dead:
			return
		var sniping := bool(c.is_player) and c.snipe_charge >= 0.9 and not thrown
		if sniping:
			c.snipe_charge = 0.0
			Fx.ring(c.eye_position() + c.forward_vector() * 0.8, 1.6, color, 0.4, false)
			Sfx.at("zap", c.global_position, 2.0, 0.7)
		for i in count:
			var p := Projectile.new()
			p.speed = float(w.get("speed", 50.0))
			p.dmg = float(w.get("dmg", 20.0)) * power
			p.splash = float(w.get("radius", 0.0))
			p.life = float(w.get("range", 60.0)) / maxf(p.speed, 1.0) + 0.3
			if sniping:                                   # a sniper shot: faster, a longer way, hits much harder, no spread
				p.speed *= 1.9
				p.dmg *= 2.3
				p.life = float(w.get("range", 60.0)) * 2.2 / p.speed + 0.3
			p.magic = bool(w["magic"])
			p.skill = false
			p.color = color
			p.kind = kind
			p.arc = thrown
			p.ranged = true
			p.pierce = randf() < c.stats.add_sum("pierce_chance")
			p.pierce_left = 1 if p.pierce else 0
			if mech.has("pierce"):
				p.pierce = true
				p.pierce_left = int(mech["pierce"])
			if mech.has("homing"):
				p.homing = float(mech["homing"])
			if mech.has("pull"):
				p.pull = float(mech["pull"])
			if mech.has("knock"):
				p.knock = float(mech["knock"])
			if mech.has("lifesteal") or mech.has("chain") or mech.has("mana_hit"):
				var dmg_shot := p.dmg
				p.on_hit_cb = func(victim: Combatant) -> void:
					if is_instance_valid(c) and is_instance_valid(victim):
						_after_hit(c, victim, dmg_shot, w, color)
			var off := 0.0
			if count > 1:
				off = deg_to_rad(spread) * (float(i) / float(count - 1) - 0.5)
			var jit := 0.0 if sniping else jitter
			var d := base.rotated(Vector3.UP, off + randf_range(-jit, jit)).rotated(base.cross(Vector3.UP).normalized(), randf_range(-jit, jit))
			var from := c.chest_position() + c.forward_vector() * 0.7
			if w["family"] in ["bow", "crossbow", "spiritbow", "thrown"]:
				from = c.eye_position() + c.forward_vector() * 0.5 - Vector3(0, 0.25, 0)
			p.launch(c, from, d)
			if c.stats.add_sum("chain_shot_damage") > 0.0 and int(c.combo) % 6 == 5:
				p.dmg *= 1.0 + c.stats.add_sum("chain_shot_damage")
		c.combo += 1
	var fire_all := func() -> void:
		go.call()
		for v in range(1, volleys):
			Util.after(c, gap * float(v), go)
	if delay > 0.01:
		Util.after(c, delay, fire_all)
	else:
		fire_all.call()
