class_name Quests
extends Node
## NPC missions (XP and a full heal) and quest-skill quests (a demo of the skill, then a chance to earn it), tracked from match events.
## Match.gd calls on_event(name, data) for the player's kills, hits, jumps, captures...; tick() handles the time-based kinds.

signal changed()
signal offer(data: Dictionary)                    # the NPC dialog shows this
signal finished(data: Dictionary, success: bool, reward_text: String)

var match_ref: Match = null
var active: Dictionary = {}                       # {type, title, text, kind, goal, progress, time_left, skill_id, reward_xp}
var demo_skill := ""
var _pending: Dictionary = {}
var _kill_chain_t := -99.0
var _kill_chain_n := 0
var _seen: Dictionary = {}
var _last_pos := Vector3.ZERO
var _same_skill_slot := ""
var _same_skill_n := 0


func is_busy() -> bool:
	return not active.is_empty() or not _pending.is_empty()


# ----------------------------------------------------------------- offers

func offer_mission(npc: Node) -> void:
	var kinds := [
		{"title": "Hunt", "text": "Defeat 3 enemies.", "kind": "kills", "goal": 3, "time": 100.0},
		{"title": "Take the field", "text": "Capture a point.", "kind": "captures", "goal": 1, "time": 150.0},
		{"title": "Hold the line", "text": "Stand on a capture point for 20 seconds.", "kind": "capture_standing", "goal": 20, "time": 150.0},
		{"title": "High ground", "text": "Defeat an enemy from above.", "kind": "kills_high", "goal": 1, "time": 150.0},
		{"title": "Chain reaction", "text": "Defeat 2 enemies within 8 seconds of each other.", "kind": "kill_chain", "goal": 2, "time": 150.0},
		{"title": "Treasure", "text": "Open a loot crate.", "kind": "crates", "goal": 1, "time": 150.0},
	]
	var m: Dictionary = kinds[randi() % kinds.size()].duplicate()
	m["type"] = "mission"
	m["reward_xp"] = 120 + 6 * Game.level
	m["reward_text"] = "%d XP and a full heal" % m["reward_xp"]
	m["npc"] = npc
	_pending = m
	offer.emit(m)


func offer_quest(npc: Node, skill_id: String) -> void:
	if not Data.quest_by_id.has(skill_id):
		return
	var q: Dictionary = Data.quest_by_id[skill_id]
	var r := QuestSkills.rule(skill_id)
	var d := {"type": "quest", "title": String(q["name"]), "text": "Quest: %s. %s" % [q["quest"], "Demo: " + String(q["demo"])], "kind": r[0], "goal": r[1],
		"time": float(q["quest_time_limit_seconds"]) if q["quest_time_limit_seconds"] != null else 120.0, "skill_id": skill_id, "reward_xp": 60,
		"reward_text": "%d%% chance to learn %s (%s)" % [q["reward_chance_percent"], q["name"], String(q["rarity"]).capitalize()], "rarity": q["rarity"], "npc": npc,
		"effect": q["effect"]}
	_pending = d
	offer.emit(d)


func decline() -> void:
	_pending = {}


func accept() -> void:
	if _pending.is_empty():
		return
	active = _pending.duplicate()
	_pending = {}
	active["progress"] = 0.0
	active["time_left"] = float(active["time"])
	_kill_chain_n = 0
	_seen = {}
	var p: Combatant = match_ref.player
	_last_pos = p.global_position
	if active["type"] == "quest":
		demo_skill = String(active["skill_id"])
		p.cooldowns["quest"] = 0.0
		match_ref.hud_toast("Quest started: use the demo with V", QuestSkills.rarity_color(Data.quest_by_id[demo_skill]))
	else:
		match_ref.hud_toast("Mission started", Color(1.0, 0.85, 0.3))
	changed.emit()


func abort() -> void:
	if active.is_empty():
		return
	var a := active
	active = {}
	demo_skill = ""
	finished.emit(a, false, "Quest failed")
	changed.emit()


# ----------------------------------------------------------------- progress

func _add(amount: float) -> void:
	if active.is_empty():
		return
	active["progress"] = float(active["progress"]) + amount
	changed.emit()
	if float(active["progress"]) >= float(active["goal"]):
		_complete()


func _complete() -> void:
	var a := active
	active = {}
	demo_skill = ""
	var p: Combatant = match_ref.player
	var text := ""
	if a["type"] == "mission":
		Game.add_xp(float(a["reward_xp"]))
		p.health = p.max_health()
		p.mana = p.max_mana()
		p.health_changed.emit(p.health, p.max_health())
		Fx.level_up(p)
		text = "Mission complete: %s" % a["reward_text"]
	else:
		var q: Dictionary = Data.quest_by_id[a["skill_id"]]
		Game.add_xp(float(a["reward_xp"]))
		if randf() * 100.0 < float(q["reward_chance_percent"]):
			Game.quest_skill = String(a["skill_id"])
			Game.save_profile()
			Game.quest_skill_changed.emit()
			text = "You learned %s! Press V to use it." % q["name"]
		else:
			text = "Quest done, but the skill did not come this time. Try again when the sage returns."
	finished.emit(a, true, text)
	if a.has("npc") and is_instance_valid(a["npc"]) and a["type"] == "quest":
		a["npc"].available = false
		a["npc"].visible = false
		a["npc"]._roll_timer = 60.0
	changed.emit()


func on_event(name: String, d: Dictionary) -> void:
	if active.is_empty():
		return
	var kind: String = active["kind"]
	match name:
		"kill":
			match kind:
				"kills": _add(1.0)
				"kills_behind": if d.get("behind", false): _add(1.0)
				"kills_aoe": if d.get("aoe", false): _add(1.0)
				"kills_low": if float(d.get("own_hp", 1.0)) < 0.5: _add(1.0)
				"kills_high": if d.get("high", false): _add(1.0)
				"kills_after_sprint": if d.get("after_sprint", false): _add(1.0)
				"oneshots": if d.get("oneshot", false): _add(1.0)
				"kills_no_damage": _add(1.0)
				"kill_chain":
					var now := Time.get_ticks_msec() / 1000.0
					_kill_chain_n = _kill_chain_n + 1 if now - _kill_chain_t < 8.0 else 1
					_kill_chain_t = now
					if _kill_chain_n >= 2:
						active["progress"] = float(_kill_chain_n)
						changed.emit()
						if float(active["progress"]) >= float(active["goal"]):
							_complete()
				"kills_same_skill":
					var slot := String(d.get("slot", ""))
					if slot != "" and slot == _same_skill_slot:
						_same_skill_n += 1
					else:
						_same_skill_slot = slot
						_same_skill_n = 1 if slot != "" else 0
					active["progress"] = float(_same_skill_n)
					changed.emit()
					if _same_skill_n >= int(active["goal"]):
						_complete()
				"score": _add(1.0)
			if kind == "heal_from_kills":
				_add(float(d.get("heal", 0.0)))
		"damage_dealt":
			if kind == "damage_dealt":
				_add(float(d.get("amount", 0.0)))
			elif kind == "aoe_damage" and d.get("aoe", false):
				_add(float(d.get("amount", 0.0)))
		"damage_taken":
			if kind == "damage_taken":
				_add(float(d.get("amount", 0.0)))
			elif kind == "hits_taken":
				_add(1.0)
			elif kind == "absorbed":
				_add(float(d.get("absorbed", 0.0)))
			elif kind == "kills_no_damage":
				active["progress"] = 0.0
				changed.emit()
		"hit":
			if kind == "hit_streak":
				_add(1.0)
			elif kind == "crits" and d.get("crit", false):
				_add(1.0)
		"miss":
			if kind == "hit_streak":
				active["progress"] = 0.0
				changed.emit()
		"jump":
			if kind == "jumps":
				_add(1.0)
		"crate":
			if kind == "crates":
				_add(1.0)
			elif kind == "score":
				_add(2.0)
		"capture":
			if kind == "captures":
				_add(1.0)
			elif kind == "score":
				_add(3.0)
		"jump_pad":
			if kind == "pads":
				_add(1.0)
		"skill_used":
			if kind == "skills_used":
				var s := String(d.get("slot", ""))
				if not active.has("used"):
					active["used"] = {}
				if not active["used"].has(s):
					active["used"][s] = true
					_add(1.0)
		"meter_full":
			if kind == "meter_full":
				_add(1.0)
		"status_removed":
			if kind == "statuses_removed":
				_add(1.0)
		"cc":
			if kind == "cc_applied":
				_add(1.0)
			elif kind == "pushed":
				_add(1.0)
		"ally_heal":
			if kind == "ally_heals":
				_add(1.0)
		"death":
			if kind in ["kills_no_damage", "kill_chain"] or active["type"] == "quest" and kind in ["kills", "kills_high"]:
				pass


func tick(delta: float) -> void:
	if active.is_empty():
		return
	active["time_left"] = float(active["time_left"]) - delta
	if float(active["time_left"]) <= 0.0:
		abort()
		return
	var p: Combatant = match_ref.player
	if p == null or p.dead:
		return
	var kind: String = active["kind"]
	match kind:
		"distance":
			_add(p.global_position.distance_to(_last_pos) if p.is_on_floor() else 0.0)
		"unseen_moving":
			if p.unseen_time > 2.0 and p.velocity.length() > 1.0:
				_add(delta)
		"unseen_total":
			if p.unseen_time > 2.0:
				_add(delta)
		"low_health_time":
			if p.health < p.max_health() * 0.2:
				_add(delta)
		"enemy_half_time":
			if match_ref.in_enemy_half(p):
				_add(delta)
		"capture_standing":
			if match_ref.player_on_capture_point():
				_add(delta)
		"enemies_seen":
			for e in match_ref.enemies_of(p.team):
				if not e.dead and not _seen.has(e) and e.global_position.distance_to(p.global_position) < 50.0 and p.has_line_of_sight(e):
					_seen[e] = true
					_add(1.0)
		"points_visited":
			for cp in match_ref.capture_points:
				if not _seen.has(cp) and cp.global_position.distance_to(p.global_position) < cp.radius:
					_seen[cp] = true
					_add(1.0)
	_last_pos = p.global_position
