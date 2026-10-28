class_name QuestSkills
extends RefCounted
## The 50 quest skills: what each one does when used (use) and which quest earns it (RULES: event kind and goal).
## Quest skills are not class skills: no own-class buff. One slot, key V. Data: design/quest_skills.json (via Data.quest_skills).

# id -> [progress kind, goal]. Kinds are counted by Quests.gd from match events.
const RULES := {
	"quick_step": ["distance", 300], "second_wind": ["damage_taken", 150], "sharp_eye": ["hit_streak", 8], "stone_skin": ["hits_taken", 3], "light_feet": ["jumps", 10],
	"scavenger_s_nose": ["crates", 2], "brave_heart": ["capture_standing", 12], "quick_hands": ["kills", 3], "mana_spring": ["skills_used", 5], "camp_fire": ["unseen_moving", 15],
	"trail_blazer": ["pads", 3], "bounty_hunter": ["kills", 1], "shadow_step": ["kills_behind", 2], "ricochet": ["kills_aoe", 5], "iron_will": ["kills_low", 2],
	"battle_cry": ["captures", 1], "smoke_bomb": ["unseen_moving", 10], "vampiric_touch": ["heal_from_kills", 100], "grapple_line": ["kills_high", 2], "mirror_shield": ["hits_taken", 5],
	"pathfinder": ["points_visited", 3], "overcharge": ["meter_full", 2], "lucky_coin": ["crates", 3], "rushing_gale": ["pads", 6], "cleanse_the_land": ["statuses_removed", 5],
	"dead_reckoning": ["crits", 5], "phase_cloak": ["unseen_total", 30], "earth_tremor": ["cc_applied", 6], "static_field": ["aoe_damage", 600], "guardian_angel": ["ally_heals", 2],
	"gravity_well": ["pushed", 4], "eagle_vision": ["enemies_seen", 10], "last_stand": ["low_health_time", 8], "thirst_for_blood": ["oneshots", 10], "time_skip": ["kills", 5],
	"soul_siphon": ["kills_same_skill", 3], "mirror_image": ["kills", 6], "storm_step": ["kill_chain", 3], "fortress": ["capture_standing", 20], "hunter_s_mark": ["kills", 1],
	"warp_strike": ["kills_after_sprint", 3], "phoenix_rebirth": ["kills_low", 3], "sky_hunter": ["kills_high", 5], "dominion": ["captures", 2], "blood_moon": ["damage_dealt", 2000],
	"void_walker": ["enemy_half_time", 40], "colossus": ["absorbed", 1500], "time_lord": ["kills", 12], "reaper_s_contract": ["kills_no_damage", 10], "world_breaker": ["score", 8],
}


static func rule(id: String) -> Array:
	return RULES.get(id, ["kills", 3])


static func use(c: Combatant) -> bool:
	var id := Game.quest_skill
	var demo := false
	if c.match_ref != null and c.match_ref.quests.demo_skill != "":
		id = c.match_ref.quests.demo_skill
		demo = true
	if id == "" or not Data.quest_by_id.has(id):
		return false
	if c.dead or not c.statuses.can_cast():
		return false
	if c.cooldowns.get("quest", 0.0) > 0.0 and not demo:
		return false
	var q: Dictionary = Data.quest_by_id[id]
	c.cooldowns["quest"] = 0.0 if demo else float(q.get("cooldown_seconds", 30.0))
	apply_effect(c, id)
	var col := rarity_color(q)
	Fx.ring(c.global_position, 2.5, col, 0.6)
	if c.match_ref != null:
		c.match_ref.hud_toast(String(q["name"]), col)
	return true


static func rarity_color(q: Dictionary) -> Color:
	return Data.rarity_color(String(q["rarity"]))


static func _allies_near(c: Combatant, r: float) -> Array:
	var out: Array = []
	for a in c.match_ref.allies_of(c.team):
		if not a.dead and a.global_position.distance_to(c.global_position) <= r:
			out.append(a)
	return out


static func _enemies_near(c: Combatant, r: float) -> Array:
	var out: Array = []
	for e in c.match_ref.enemies_of(c.team):
		if not e.dead and e.global_position.distance_to(c.global_position) <= r:
			out.append(e)
	return out


static func _hot(c: Combatant, total: float, seconds: float) -> void:
	var steps := int(seconds * 2.0)
	for i in steps:
		Util.after(c, 0.5 * (i + 1), func() -> void:
			if is_instance_valid(c) and not c.dead:
				c.heal(total / float(steps), null, false))


static func _zone(c: Combatant, at: Vector3, r: float, dur: float, kind: String, props: Dictionary) -> Zone:
	var z := Zone.new()
	z.radius = r
	for k in props:
		z.set(k, props[k])
	c.match_ref.add_child(z)
	z.start(c, at, r, dur, kind)
	return z


static func apply_effect(c: Combatant, id: String) -> void:
	var fwd := c.forward_vector()
	var tmp := func(key: String, mods: Dictionary, dur: float) -> void: c.add_temp_mods("q_" + key, mods, dur)
	match id:
		"quick_step":
			c.sprint_boost = 1.5
			c.sprint_boost_left = 3.0
			c.stamina = 100.0
			c.set_meta("last_sprint", Time.get_ticks_msec() / 1000.0)
		"second_wind":
			_hot(c, c.max_health() * 0.2, 3.0)
		"sharp_eye", "pathfinder", "eagle_vision":
			var r := 20.0 if id != "eagle_vision" else 40.0
			var d := 4.0 if id == "sharp_eye" else (10.0 if id == "pathfinder" else 5.0)
			for e in _enemies_near(c, r):
				e.statuses.apply("marked", d, 1, c)
		"stone_skin":
			tmp.call("stone", {"armor": {"add": 0.25}}, 4.0)
		"light_feet":
			tmp.call("jump", {"extra_jumps": {"add": 1.0}}, 8.0)
		"scavenger_s_nose":
			c.match_ref.reveal_loot_until = Time.get_ticks_msec() / 1000.0 + 8.0
		"brave_heart":
			c.statuses.apply("cleanse_shield", 5.0, 1, c)
		"quick_hands":
			tmp.call("hands", {"fire_rate": {"mult": 0.3}, "reload_speed": {"mult": 0.3}}, 5.0)
		"mana_spring":
			c.restore_mana(c.max_mana() * 0.3)
			for s in c.cooldowns:
				c.cooldowns[s] = maxf(0.0, c.cooldowns[s] - 2.0)
		"camp_fire":
			_zone(c, c.global_position, 6.0, 8.0, "fire", {"heal_amount": 4.0, "affects_allies": true, "allies_only": true, "tick": 1.0})
		"trail_blazer":
			_zone(c, c.global_position, 5.0, 6.0, "heal", {"allies_only": true, "affects_allies": true, "sts": [{"id": "haste", "dur": 1.5}], "tick": 0.5})
		"bounty_hunter", "hunter_s_mark":
			var e := c.nearest_enemy(80.0)
			if e != null:
				e.statuses.apply("marked", 8.0 if id == "bounty_hunter" else 10.0, 1, c)
				if id == "hunter_s_mark":
					e.set_meta("hunter_mark_by", c)
		"shadow_step":
			SkillRunner._teleport(c, {}, {"dist": 10.0}, Color(0.6, 0.4, 0.9))
		"ricochet":
			tmp.call("rico", {"pierce_chance": {"add": 1.0}, "ricochet": {"add": 0.5}}, 10.0)
		"iron_will":
			c.statuses.apply("barrier", 5.0, 1, c, c.max_health() * 0.25 / 60.0)
		"battle_cry":
			for a in _allies_near(c, 12.0):
				a.add_temp_mods("q_cry", {"move_speed": {"mult": 0.1}, "weapon_damage": {"mult": 0.1}, "spell_damage": {"mult": 0.1}}, 6.0)
		"smoke_bomb":
			_zone(c, c.global_position, 6.0, 6.0, "smoke", {"sts": [{"id": "blind", "dur": 1.5}], "tick": 0.5})
			c.statuses.apply("haste", 4.0, 1, c)
		"vampiric_touch":
			tmp.call("vamp", {"lifesteal": {"add": 0.25}}, 6.0)
		"grapple_line":
			var to := c.aim_point
			var rel := to - c.global_position
			if rel.length() > 25.0:
				rel = rel.normalized() * 25.0
			c.forced_vel = Vector3(rel.x, 0, rel.z) / 0.9
			c.forced_time = 0.8
			c.velocity.y = 6.0 + maxf(rel.y, 0.0) * 1.2
		"mirror_shield":
			c.statuses.apply("barrier", 3.0, 1, c, 1.5)
		"overcharge":
			tmp.call("overch", {"meter_gain": {"mult": 0.5}}, 10.0)
		"lucky_coin":
			c.set_meta("lucky_coin", true)
		"rushing_gale":
			c.statuses.apply("haste", 5.0, 1, c)
			tmp.call("gale", {"move_speed": {"mult": 0.1}}, 5.0)
		"cleanse_the_land":
			c.statuses.cleanse()
			c.statuses.apply("cleanse_shield", 2.0, 1, c)
			for a in _allies_near(c, 8.0):
				a.statuses.cleanse()
				a.statuses.apply("cleanse_shield", 2.0, 1, c)
		"dead_reckoning":
			tmp.call("crit", {"crit_chance": {"add": 1.0}}, 5.0)
		"phase_cloak":
			c.statuses.apply("invisible", 4.0, 1, c)
		"earth_tremor":
			SkillRunner._burst(c, c.global_position, 8.0, {"dmg": 15.0, "sts": [{"id": "slow", "dur": 2.0}, {"id": "stun", "dur": 1.0}], "knock": 6.0}, false, Color(0.7, 0.55, 0.3))
		"static_field":
			var z := _zone(c, c.global_position, 5.0, 6.0, "storm", {"dmg": 15.0, "tick": 1.0, "magic": true})
			z.follow = c
		"guardian_angel":
			var best: Combatant = null
			var bd := 1e9
			for a in c.match_ref.allies_of(c.team):
				if a != c and not a.dead and a.global_position.distance_to(c.global_position) < bd:
					bd = a.global_position.distance_to(c.global_position)
					best = a
			if best != null:
				best.statuses.apply("barrier", 6.0, 1, c, 150.0 / 60.0)
		"gravity_well":
			_zone(c, c.aim_point if c.aim_point != Vector3.ZERO else c.global_position, 8.0, 1.5, "void", {"pull": 9.0, "tick": 0.3})
		"last_stand":
			tmp.call("last", {"last_stand": {"add": 1.0}, "weapon_damage": {"mult": 0.3}, "spell_damage": {"mult": 0.3}}, 6.0)
		"thirst_for_blood":
			c.set_meta("xray_until", Time.get_ticks_msec() / 1000.0 + 10.0)
			for e in c.match_ref.enemies_of(c.team):
				if not e.dead:
					e.statuses.apply("marked", 10.0, 1, c)
		"time_skip":
			c.rewind(4.0)
		"soul_siphon":
			tmp.call("siphon", {"heal_on_kill": {"add": c.max_health() * 0.15}, "kill_cdr": {"add": 0.1}}, 10.0)
		"mirror_image":
			for i in 2:
				c.match_ref.spawn_minion("mirror", c.global_position + Vector3(2.0 * (i * 2 - 1), 0, 0), c, 8.0)
		"storm_step":
			var runner := SkillRunner.SprintRunner.new()
			runner.c = c
			runner.time_left = 3.0
			runner.fx = {"dmg": 10.0, "sts": [{"id": "stun", "dur": 1.2}]}
			runner.color = Color(1, 1, 0.5)
			c.sprint_boost = 2.0
			c.sprint_boost_left = 3.0
			c.stamina = 100.0
			c.set_meta("last_sprint", Time.get_ticks_msec() / 1000.0)
			c.match_ref.add_child(runner)
		"fortress":
			for a in _allies_near(c, 6.0):
				a.statuses.apply("barrier", 6.0, 1, c, 2.0)
			_zone(c, c.global_position, 6.0, 6.0, "frost", {"tick": 1.0})
		"warp_strike":
			var t := c.nearest_enemy(20.0)
			if t != null:
				c.global_position = t.global_position - (t.global_position - c.global_position).normalized() * 1.5
				SkillRunner._burst(c, t.global_position, 4.0, {"dmg": 150.0, "sts": []}, false, Color(0.8, 0.5, 1.0))
		"phoenix_rebirth":
			tmp.call("phoenix", {"revive_health": {"add": 0.5}}, 9999.0)
		"sky_hunter":
			tmp.call("glide", {"glide": {"add": 1.0}}, 6.0)
		"dominion":
			c.statuses.apply("empower", 12.0, 1, c)
			c.statuses.apply("haste", 12.0, 1, c)
		"blood_moon":
			tmp.call("moon", {"lifesteal": {"add": 0.3}, "weapon_damage": {"mult": 0.25}, "spell_damage": {"mult": 0.25}}, 12.0)
		"void_walker":
			c.collision_mask = 0
			Util.after(c, 3.0, func() -> void:
				if is_instance_valid(c):
					c.collision_mask = 1
					c.snap_to_ground())
		"colossus":
			tmp.call("colossus", {"max_health": {"mult": 0.5}}, 10.0)
			c.model.scale *= 1.4
			Util.after(c, 10.0, func() -> void:
				if is_instance_valid(c):
					c.model.scale /= 1.4)
		"time_lord":
			for e in _enemies_near(c, 25.0):
				e.statuses.apply("slow", 6.0, 1, c)
				e.statuses.apply("chill", 6.0, 3, c)
		"reaper_s_contract":
			for i in 2:
				Util.after(c, 6.0 * i + 0.5, func() -> void:
					if not is_instance_valid(c) or c.dead:
						return
					for e in _enemies_near(c, 15.0):
						if e.health < e.max_health() * 0.2:
							Fx.lightning_strike(e.global_position)
							e.take_damage(99999.0, c, {"dot": "reaper", "no_status": true})
							break)
		"world_breaker":
			SkillRunner._burst(c, c.global_position, 10.0, {"dmg": 300.0, "sts": [{"id": "stun", "dur": 1.0}], "knock": 16.0}, false, Color(0.9, 0.6, 0.3))
			Fx.ring(c.global_position, 10.0, Color(1.0, 0.6, 0.3), 0.8)
		_:
			c.statuses.apply("haste", 4.0, 1, c)
