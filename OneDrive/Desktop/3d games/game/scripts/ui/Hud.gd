class_name Hud
extends CanvasLayer
## The in-match HUD: health, mana, class meter, status icons, skill slots with cooldown rings, ultimate, kill-streak badge, XP and level,
## scores and capture points, minimap, kill feed, crosshair, prompts, toasts, mission tracker, scoreboard, respawn timer and the result screen.
## Also hosts the overlays: level-up cards, crate-open screen, armory, NPC dialog, pause menu.

var m: Match
var p: Player
var root: Control
var _hp: UiKit.Bar
var _mp: UiKit.Bar
var _meter: UiKit.Bar
var _stamina: UiKit.Bar
var _fps_label: Label
var _xp: UiKit.Bar
var _status_row: HBoxContainer
var _slots: Dictionary = {}
var _quest_slot: UiKit.SkillSlot
var _potion_label: Label
var _level_label: Label
var _score_label: Label
var _flag_label: Label
var _time_label: Label
var _points_box: HBoxContainer
var _prompt: Label
var _toast_box: VBoxContainer
var _feed: VBoxContainer
var _crosshair: Control
var _streak: Control
var _streak_label: Label
var _tracker: Label
var _tracker_bar: UiKit.Bar
var _respawn: Label
var _vignette: ColorRect
var _minimap: Control
var _cards: CardPicker
var _scoreboard: Control
var _center_msg: Label
var _status_cache: Dictionary = {}
var _hit_flash := 0.0
var _overlay_open := false
var _wheel: WeaponWheel
var _armory: Armory
var _dialog: Control
var _pause: Control
var _loot_flash := 0.0


func setup(match_ref: Match) -> void:
	m = match_ref
	p = m.player
	layer = 10
	root = Control.new()
	UiKit.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	_cards = CardPicker.new()
	root.add_child(_cards)
	m.score_changed.connect(_on_score)
	m.toast.connect(show_toast)
	m.player_respawn_timer.connect(func(s: float) -> void:
		_respawn.visible = true
		_respawn.text = "Back in the fight in %d..." % int(ceilf(s)))
	p.health_changed.connect(_on_health)
	p.mana_changed.connect(func(c: float, mx: float) -> void: _mp.set_value(c / maxf(mx, 1.0), "%d / %d" % [int(c), int(mx)]))
	p.damaged.connect(func(_a: float, _s: Node, _i: Dictionary) -> void: _hit_flash = 0.45)
	p.statuses.changed.connect(_refresh_statuses)
	Game.xp_changed.connect(_on_xp)
	Game.leveled_up.connect(func(l: int) -> void:
		show_toast("LEVEL %d!" % l, UiKit.GOLD)
		Fx.level_up(p))
	Game.card_picked.connect(func(_id: String, _s: int) -> void: p.rebuild_stats())
	Game.equipment_changed.connect(p.rebuild_stats)
	Game.skills_unlocked.connect(func(ids: Array) -> void:
		show_toast("New skill unlocked: " + String(Data.skills[ids[0]]["name"]), Color(0.6, 1.0, 0.7)))
	Game.potions_changed.connect(_refresh_potions)
	m.quests.changed.connect(_refresh_tracker)
	m.quests.offer.connect(_show_dialog)
	m.quests.finished.connect(func(_d: Dictionary, ok: bool, text: String) -> void: show_toast(text, Color(0.5, 1.0, 0.6) if ok else Color(1.0, 0.5, 0.4)))
	p.skill_used.connect(func(_s: String, _k: Dictionary) -> void: pass)
	_on_xp(Game.xp, Game.xp_for_next(), Game.level)
	_on_health(p.health, p.max_health())
	_refresh_potions()
	_refresh_statuses()
	_build_minimap()


func _build_hud() -> void:
	_vignette = ColorRect.new()
	_vignette.color = Color(1, 0, 0, 0)
	UiKit.full_rect(_vignette)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_vignette)
	# crosshair
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.custom_minimum_size = Vector2(40, 40)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func() -> void:
		var c := Vector2(20, 20)
		var col := Color(1, 1, 1, 0.9)
		_crosshair.draw_line(c + Vector2(-9, 0), c + Vector2(-3, 0), col, 2.0)
		_crosshair.draw_line(c + Vector2(9, 0), c + Vector2(3, 0), col, 2.0)
		_crosshair.draw_line(c + Vector2(0, -9), c + Vector2(0, -3), col, 2.0)
		_crosshair.draw_line(c + Vector2(0, 9), c + Vector2(0, 3), col, 2.0)
		_crosshair.draw_circle(c, 1.5, col))
	root.add_child(_crosshair)
	_crosshair.position = Vector2(-20, -20)
	# bottom-left: bars and statuses
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(24, -190)
	bl.custom_minimum_size = Vector2(420, 170)
	bl.add_theme_constant_override("separation", 4)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bl)
	bl.anchor_top = 1.0
	bl.anchor_bottom = 1.0
	bl.offset_top = -190
	bl.offset_bottom = -20
	bl.offset_left = 24
	bl.offset_right = 444
	_status_row = HBoxContainer.new()
	_status_row.custom_minimum_size = Vector2(420, 40)
	_status_row.add_theme_constant_override("separation", 4)
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.add_child(_status_row)
	_hp = UiKit.Bar.new()
	_hp.custom_minimum_size = Vector2(420, 26)
	_hp.color = Color(0.85, 0.2, 0.25)
	bl.add_child(_hp)
	_mp = UiKit.Bar.new()
	_mp.custom_minimum_size = Vector2(420, 16)
	_mp.color = Color(0.25, 0.45, 1.0)
	bl.add_child(_mp)
	_stamina = UiKit.Bar.new()
	_stamina.custom_minimum_size = Vector2(420, 8)
	_stamina.color = Color(0.4, 0.85, 0.45)
	_stamina.show_text = false
	bl.add_child(_stamina)
	_meter = UiKit.Bar.new()
	_meter.custom_minimum_size = Vector2(420, 14)
	_meter.color = Data.color_of(Data.classes[p.class_id]["color"])
	bl.add_child(_meter)
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 12)
	lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.add_child(lr)
	_level_label = UiKit.label("Lv 1", 20, UiKit.GOLD)
	lr.add_child(_level_label)
	_potion_label = UiKit.label("", 15, Color(0.9, 0.7, 0.7))
	lr.add_child(_potion_label)
	var meter_name := UiKit.label(String(Data.classes[p.class_id]["meter"]["name"]), 13, UiKit.DIM)
	lr.add_child(meter_name)
	# XP bar along the bottom
	_xp = UiKit.Bar.new()
	_xp.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_xp.anchor_top = 1.0
	_xp.anchor_bottom = 1.0
	_xp.offset_top = -10
	_xp.offset_bottom = 0
	_xp.color = Color(0.9, 0.75, 0.2)
	_xp.show_text = false
	root.add_child(_xp)
	# bottom-center: skills
	var sk := HBoxContainer.new()
	sk.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sk.anchor_left = 0.5
	sk.anchor_right = 0.5
	sk.anchor_top = 1.0
	sk.anchor_bottom = 1.0
	sk.offset_left = -300
	sk.offset_right = 300
	sk.offset_top = -76
	sk.offset_bottom = -16
	sk.alignment = BoxContainer.ALIGNMENT_CENTER
	sk.add_theme_constant_override("separation", 6)
	sk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sk)
	for slot in [["s1", "Q"], ["s2", "E"], ["s3", "R"], ["sig", "F"], ["ult", "X"]]:
		var w := UiKit.SkillSlot.new()
		w.custom_minimum_size = Vector2(52, 52)
		w.letter = slot[1]
		w.special = slot[0] == "sig"
		w.ready_glow = true
		if slot[0] == "ult":
			w.ult = true
			w.charge = 0.0
			w.custom_minimum_size = Vector2(60, 60)
		sk.add_child(w)
		_slots[slot[0]] = w
	_quest_slot = UiKit.SkillSlot.new()
	_quest_slot.custom_minimum_size = Vector2(44, 44)
	_quest_slot.letter = "V"
	_quest_slot.frame_color = Color(0.7, 0.5, 1.0)
	sk.add_child(_quest_slot)
	_fps_label = UiKit.label("", 15, Color(0.7, 1.0, 0.7))
	_fps_label.position = Vector2(12, 8)
	root.add_child(_fps_label)
	# top center: score
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -200
	top.offset_right = 200
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_score_label = UiKit.label("0   -   0", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_score_label)
	_time_label = UiKit.label("10:00", 20, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_time_label)
	_points_box = HBoxContainer.new()
	_points_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_points_box.add_theme_constant_override("separation", 10)
	_points_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_points_box)
	if m.mode != "ctf":
		for cp in m.capture_points:
			var l := UiKit.label(cp.point_name, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			l.custom_minimum_size = Vector2(36, 0)
			_points_box.add_child(l)
	else:
		_flag_label = UiKit.label("", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		top.add_child(_flag_label)
	if _flag_label == null and not m.moon.is_empty():
		_flag_label = UiKit.label("", 16, Color(0.8, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		top.add_child(_flag_label)
	# prompt and toasts
	_prompt = UiKit.label("", 22, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.6
	_prompt.anchor_bottom = 0.6
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	root.add_child(_prompt)
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.offset_left = -300
	_toast_box.offset_right = 300
	_toast_box.offset_top = 110
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)
	# kill feed (top right under the minimap)
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.anchor_left = 1.0
	_feed.anchor_right = 1.0
	_feed.offset_left = -330
	_feed.offset_right = -14
	_feed.offset_top = 230
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_feed)
	# kill streak badge
	_streak = Control.new()
	_streak.custom_minimum_size = Vector2(120, 90)
	_streak.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_streak.anchor_top = 1.0
	_streak.anchor_bottom = 1.0
	_streak.offset_left = 460
	_streak.offset_right = 600
	_streak.offset_top = -170
	_streak.offset_bottom = -30
	_streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak.draw.connect(_draw_streak)
	root.add_child(_streak)
	# mission tracker (left)
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tr.offset_left = 20
	tr.offset_top = 90
	tr.custom_minimum_size = Vector2(340, 0)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	_tracker = UiKit.label("", 16, Color(1.0, 0.95, 0.7))
	_tracker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tracker.custom_minimum_size = Vector2(340, 0)
	tr.add_child(_tracker)
	_tracker_bar = UiKit.Bar.new()
	_tracker_bar.custom_minimum_size = Vector2(300, 12)
	_tracker_bar.color = Color(1.0, 0.85, 0.3)
	_tracker_bar.show_text = false
	_tracker_bar.visible = false
	tr.add_child(_tracker_bar)
	_respawn = UiKit.label("", 40, Color(1, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_respawn.set_anchors_preset(Control.PRESET_CENTER)
	_respawn.anchor_left = 0.5
	_respawn.anchor_right = 0.5
	_respawn.anchor_top = 0.4
	_respawn.anchor_bottom = 0.4
	_respawn.offset_left = -400
	_respawn.offset_right = 400
	_respawn.visible = false
	root.add_child(_respawn)
	_center_msg = UiKit.label("", 48, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_center_msg.set_anchors_preset(Control.PRESET_CENTER)
	_center_msg.anchor_left = 0.5
	_center_msg.anchor_right = 0.5
	_center_msg.anchor_top = 0.3
	_center_msg.anchor_bottom = 0.3
	_center_msg.offset_left = -500
	_center_msg.offset_right = 500
	root.add_child(_center_msg)


func _draw_streak() -> void:
	if p == null or p.streak <= 0:
		return
	var c := Vector2(60, 60)
	var frac := clampf(p.streak_timer / 25.0, 0.0, 1.0)
	_streak.draw_circle(c, 40, Color(0, 0, 0, 0.55))
	_streak.draw_arc(c, 40, -PI / 2.0, -PI / 2.0 + TAU * frac, 40, Color(1.0, 0.45, 0.2), 6.0)
	var f := ThemeDB.fallback_font
	_streak.draw_string(f, Vector2(c.x - 18, c.y + 8), "x%d" % p.streak, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	_streak.draw_string(f, Vector2(c.x - 30, c.y + 34), "+%d%% dmg" % (mini(p.streak, 10) * 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.8, 0.5))


# ----------------------------------------------------------------- minimap

func _build_minimap() -> void:
	_minimap = Control.new()
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.anchor_left = 1.0
	_minimap.anchor_right = 1.0
	_minimap.offset_left = -214
	_minimap.offset_right = -14
	_minimap.offset_top = 14
	_minimap.offset_bottom = 214
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.draw.connect(_draw_minimap)
	root.add_child(_minimap)
	_wheel = WeaponWheel.new()
	root.add_child(_wheel)


func _map_to_mini(pos: Vector3, center: Vector3, scale: float) -> Vector2:
	return Vector2(100, 100) + Vector2(pos.x - center.x, pos.z - center.z) * scale


func _draw_minimap() -> void:
	var s := Vector2(200, 200)
	_minimap.draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.05, 0.08, 0.72), true)
	_minimap.draw_rect(Rect2(Vector2.ZERO, s), Color(0.6, 0.6, 0.75, 0.8), false, 2.0)
	if p == null:
		return
	var view := 150.0                                      # metres across
	var scale := 200.0 / view
	var center := p.global_position
	for t in m.flags:                                      # capture the flag: a small flag for each team's flag
		var fl: FlagNode = m.flags[t]
		var q := _map_to_mini(fl.global_position, center, scale)
		q = Vector2(clampf(q.x, 8, 192), clampf(q.y, 8, 192))              # kept on the edge of the map when far away
		var fc: Color = FlagNode.TEAM_COLOR[t]
		_minimap.draw_line(q, q + Vector2(0, -12), Color(0.9, 0.9, 0.85), 2.0)
		_minimap.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -12), q + Vector2(10, -8), q + Vector2(0, -4)]), fc)
	for d in m.airdrops:                                  # air drops: a gold diamond, kept on the edge when far away
		var q := _map_to_mini(d.global_position, center, scale)
		q = Vector2(clampf(q.x, 8, 192), clampf(q.y, 8, 192))
		var gc := Color(1.0, 0.85, 0.3, 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0))
		_minimap.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -7), q + Vector2(6, 0), q + Vector2(0, 7), q + Vector2(-6, 0)]), gc)
	for cp in (m.capture_points if m.mode != "ctf" else []):
		var q := _map_to_mini(cp.global_position, center, scale)
		if q.x < 4 or q.y < 4 or q.x > 196 or q.y > 196:
			continue
		var col := Color(0.85, 0.85, 0.85)
		if cp.owner_team == "red":
			col = Color(1.0, 0.35, 0.3)
		elif cp.owner_team == "blue":
			col = Color(0.35, 0.55, 1.0)
		_minimap.draw_arc(q, cp.radius * scale, 0, TAU, 24, col, 2.0)
		_minimap.draw_string(ThemeDB.fallback_font, q + Vector2(-5, 6), cp.point_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
	var now := Time.get_ticks_msec() / 1000.0
	for cr in m.crates:
		if cr.is_open:
			continue
		var q := _map_to_mini(cr.global_position, center, scale)
		if q.x < 4 or q.y < 4 or q.x > 196 or q.y > 196:
			continue
		var cc := Data.rarity_color("legendary" if cr.gold else cr.rarity)
		_minimap.draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), cc, true)
	for n in m.npcs:
		if not n.available:
			continue
		var q := _map_to_mini(n.global_position, center, scale)
		if q.x > 4 and q.y > 4 and q.x < 196 and q.y < 196:
			_minimap.draw_string(ThemeDB.fallback_font, q + Vector2(-4, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.9, 0.3))
	for c in m.combatants:
		if c.dead:
			continue
		var q := _map_to_mini(c.global_position, center, scale)
		if q.x < 4 or q.y < 4 or q.x > 196 or q.y > 196:
			continue
		var ally: bool = c.team == p.team
		if not ally and not (p.has_line_of_sight(c) and c.is_visible_to(p) and c.global_position.distance_to(p.global_position) < float(p.stats.value("sight", 70.0))) and not c.statuses.has("marked") and not m.is_lit(c):
			continue
		var col2 := Color(0.4, 1.0, 0.5) if c == p else (Color(0.3, 0.9, 0.85) if ally else Color(1.0, 0.35, 0.3))
		_minimap.draw_circle(q, 4.0 if c == p else 3.0, col2)
		if c == p:
			var f := p.forward_vector()
			_minimap.draw_line(q, q + Vector2(f.x, f.z) * 12.0, col2, 2.0)


# ----------------------------------------------------------------- updates

func _process(delta: float) -> void:
	if p == null or not is_instance_valid(p):
		return
	_hit_flash = maxf(0.0, _hit_flash - delta * 1.5)
	_vignette.color = Color(0.8, 0.0, 0.0, _hit_flash * 0.35 + (0.25 * (1.0 - p.health / p.max_health()) if p.health < p.max_health() * 0.3 else 0.0))
	_time_label.text = "%d:%02d" % [int(m.time_left) / 60, int(m.time_left) % 60]
	_meter.set_value(p.meter / 100.0, "")
	_stamina.set_value(p.stamina / 100.0)
	_fps_label.visible = bool(Settings.v["show_fps"])
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_stamina.color = Color(0.4, 0.85, 0.45) if p.stamina > 30.0 else Color(0.95, 0.55, 0.25)
	_stamina.modulate.a = 1.0 if (p.stamina < 99.0 or p.sprinting) else 0.35
	for slot in _slots:
		var w: UiKit.SkillSlot = _slots[slot]
		var sk: Dictionary = p.skill_for_slot(slot)
		if sk.is_empty():
			continue
		w.set_skill(sk)
		w.tooltip_text = "%s
%s" % [sk["name"], sk["desc"]]
		w.cooldown = float(p.cooldowns.get(slot, 0.0))
		w.cooldown_total = maxf(p.skill_cooldown_total(sk), 0.1)
		if slot == "ult":
			w.charge = p.ult_charge / 100.0
		w.disabled = not p.statuses.can_cast() or (float(sk.get("mana", 0.0)) > p.mana and slot != "ult")
		w.queue_redraw()
	var qid := Game.quest_skill
	if m.quests.demo_skill != "":
		qid = m.quests.demo_skill
	if qid != "" and Data.quest_by_id.has(qid):
		var q: Dictionary = Data.quest_by_id[qid]
		_quest_slot.set_quest(q)
		_quest_slot.tooltip_text = "%s
%s" % [q["name"], q.get("effect", "")]
		_quest_slot.cooldown = float(p.cooldowns.get("quest", 0.0))
		_quest_slot.cooldown_total = float(q.get("cooldown_seconds", 30.0)) if float(q.get("cooldown_seconds", 30.0)) > 0.0 else 1.0
	else:
		_quest_slot.set_quest({})
	_quest_slot.queue_redraw()
	if _flag_label != null and not m.moon.is_empty():
		_flag_label.text = m.current_moon_text()
	if _flag_label != null and m.flags.size() == 2:
		var mine: FlagNode = m.flags[p.team]
		var theirs: FlagNode = m.flags["blue" if p.team == "red" else "red"]
		_flag_label.text = "Your flag: %s     Enemy flag: %s" % [_flag_text(mine), _flag_text(theirs)]
		_flag_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5) if (mine.state != "home" or theirs.state == "carried") else Color(0.85, 0.85, 0.9))
	for i in (m.capture_points.size() if m.mode != "ctf" else 0):
		var cp: CapturePoint = m.capture_points[i]
		var l: Label = _points_box.get_child(i)
		var col := Color(0.85, 0.85, 0.85)
		if cp.owner_team == "red":
			col = Color(1.0, 0.4, 0.35)
		elif cp.owner_team == "blue":
			col = Color(0.4, 0.6, 1.0)
		l.add_theme_color_override("font_color", col)
	if m.quests.active.size() > 0:
		var a: Dictionary = m.quests.active
		_tracker.text = "%s: %s\n%d / %d   (%ds)" % [a["title"], a["text"], int(a["progress"]), int(a["goal"]), int(a["time_left"])]
		_tracker_bar.visible = true
		_tracker_bar.set_value(float(a["progress"]) / maxf(float(a["goal"]), 1.0))
	_minimap.queue_redraw()
	_streak.queue_redraw()
	if _wheel != null:
		if Input.is_action_just_pressed("weapon_wheel") and not _overlay_open and not p.dead:
			_wheel.open()
			p.set_ui_blocked(true)
		elif _wheel.visible and not Input.is_action_pressed("weapon_wheel"):
			var pick := _wheel.close()
			p.set_ui_blocked(false)
			if not pick.is_empty() and pick != Game.equipped_item("weapon"):
				Game.equip(pick)
				p.rebuild_stats()
				show_toast("%s in hand" % Loot.item_name(pick), Data.rarity_color(String(pick["rarity"])))
	if Input.is_action_just_pressed("armory") and not _overlay_open and m != null:
		open_armory()
	if Input.is_action_just_pressed("menu") and not _overlay_open:
		open_pause()
	if _scoreboard != null:
		_scoreboard.visible = Input.is_action_pressed("scoreboard")
		if _scoreboard.visible:
			_scoreboard.queue_redraw()
	elif Input.is_action_just_pressed("scoreboard"):
		_make_scoreboard()


func _on_health(c: float, mx: float) -> void:
	_hp.set_value(c / maxf(mx, 1.0), "%d / %d" % [int(ceilf(c)), int(mx)])
	_hp.color = Color(0.85, 0.2, 0.25) if c > mx * 0.3 else Color(1.0, 0.1, 0.1)


func _on_xp(x: int, need: int, lv: int) -> void:
	_xp.set_value(float(x) / maxf(need, 1.0))
	_level_label.text = "Lv %d" % lv


func _on_score(r: int, b: int) -> void:
	_score_label.text = "%d   -   %d" % [r, b]


func _flag_text(f: FlagNode) -> String:
	match f.state:
		"carried":
			return "TAKEN by %s" % (f.carrier.display_name if f.carrier != null and is_instance_valid(f.carrier) else "?")
		"dropped":
			return "dropped (%ds)" % int(maxf(f._return_t, 0.0))
	return "home"


func _refresh_potions() -> void:
	var parts: Array = []
	for id in Data.potions:
		var n: int = int(Game.potions.get(id, 0))
		if n > 0:
			parts.append("%s x%d" % [String(Data.potions[id]["name"]).replace(" Potion", ""), n])
	_potion_label.text = "Z: " + (", ".join(parts) if parts.size() > 0 else "no potions")


## Status icons: a ring that drains with the time left, a stack number, harmful = red frame, helpful = green frame, plus a symbol letter.
func _refresh_statuses() -> void:
	for c in _status_row.get_children():
		c.queue_free()
	for id in p.statuses.active:
		var d: Dictionary = Data.statuses[id]
		var e: Dictionary = p.statuses.active[id]
		var icon := StatusIcon.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.setup(id, d, e)
		icon.tooltip_text = "%s\n%s" % [d["name"], d["desc"]]
		_status_row.add_child(icon)


func set_prompt(text: String) -> void:
	_prompt.text = text


func show_toast(text: String, color: Color = Color.WHITE) -> void:
	var l := UiKit.label(text, 26, color, HORIZONTAL_ALIGNMENT_CENTER)
	_toast_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	while _toast_box.get_child_count() > 4:
		_toast_box.get_child(0).queue_free()
		break


func add_kill_feed(killer: Node, victim: Combatant) -> void:
	var kn := "The world"
	var kcol := Color(0.8, 0.8, 0.8)
	if killer is Combatant:
		kn = (killer as Combatant).display_name
		kcol = Color(1.0, 0.4, 0.35) if (killer as Combatant).team == "red" else Color(0.45, 0.6, 1.0)
	var l := UiKit.label("%s  >  %s" % [kn, victim.display_name], 15, kcol, HORIZONTAL_ALIGNMENT_RIGHT)
	_feed.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	while _feed.get_child_count() > 6:
		_feed.get_child(0).queue_free()
		break


func on_player_kill(victim: Combatant) -> void:
	show_toast("Defeated %s" % victim.display_name, Color(1.0, 0.8, 0.4))
	if p.streak >= 2:
		show_toast("Kill streak x%d" % p.streak, Color(1.0, 0.55, 0.3))


func on_player_died(killer: Node) -> void:
	_center_msg.text = "You were defeated" + (" by %s" % (killer as Combatant).display_name if killer is Combatant else "")
	p.set_ui_blocked(false)


func on_respawn() -> void:
	_respawn.visible = false
	_center_msg.text = ""


func _refresh_tracker() -> void:
	if m.quests.active.is_empty():
		_tracker.text = ""
		_tracker_bar.visible = false


# ----------------------------------------------------------------- overlays

func _lock(on: bool) -> void:
	_overlay_open = on
	p.set_ui_blocked(on)
	if not on and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func show_crate_open(crate: LootCrateNode, result: Dictionary) -> void:
	Sfx.play("chest")
	_lock(true)
	var c := CrateOpen.new()
	root.add_child(c)
	c.open_with(result, crate)
	c.closed.connect(func(_r: Dictionary) -> void:
		_lock(false)
		p.rebuild_stats()
		if result["type"] == "reroll":
			show_toast("+%d card reroll(s)" % int(result["reroll"]), Color(0.8, 0.6, 1.0)))


func open_armory() -> void:
	_lock(true)
	_armory = Armory.new()
	_armory.in_match = true
	root.add_child(_armory)
	_armory.closed.connect(func(_start: bool) -> void:
		_armory.queue_free()
		_lock(false)
		p.skill_ids = Game.skills_for(p.class_id).duplicate()
		p.rebuild_stats())


func open_pause() -> void:
	_lock(true)
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.7)
	UiKit.full_rect(panel)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -150
	v.offset_right = 150
	v.offset_top = -150
	v.offset_bottom = 150
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UiKit.label("PAUSED", 36, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.button("Resume", func() -> void:
		panel.queue_free()
		_lock(false), 22, Vector2(300, 48)))
	v.add_child(UiKit.button("Armory (I)", func() -> void:
		panel.queue_free()
		_lock(false)
		open_armory(), 22, Vector2(300, 48)))
	v.add_child(UiKit.button("Settings", func() -> void:
		var sm := SettingsMenu.new()
		root.add_child(sm), 22, Vector2(300, 48)))
	v.add_child(UiKit.button("Leave match", func() -> void:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		m.get_parent().show_menu(), 22, Vector2(300, 48)))


func _show_dialog(d: Dictionary) -> void:
	_lock(true)
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.55)
	UiKit.full_rect(panel)
	root.add_child(panel)
	var box := UiKit.panel(Color(0.08, 0.08, 0.12, 0.98), Data.rarity_color(String(d.get("rarity", "uncommon"))) if d["type"] == "quest" else UiKit.GOLD)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = -170
	box.offset_bottom = 170
	panel.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	v.add_child(UiKit.label(("Wandering Sage" if d["type"] == "quest" else "Mission") + ": " + String(d["title"]), 28, UiKit.GOLD))
	var t := UiKit.label(String(d["text"]), 20)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(560, 0)
	v.add_child(t)
	v.add_child(UiKit.label("Time: %d seconds" % int(d["time"]), 18, UiKit.DIM))
	v.add_child(UiKit.label("Reward: " + String(d["reward_text"]), 18, Color(0.6, 1.0, 0.7)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	row.add_child(UiKit.button("Accept", func() -> void:
		m.quests.accept()
		panel.queue_free()
		_lock(false), 20))
	row.add_child(UiKit.button("Not now", func() -> void:
		m.quests.decline()
		panel.queue_free()
		_lock(false), 20))


func _make_scoreboard() -> void:
	_scoreboard = Control.new()
	UiKit.full_rect(_scoreboard)
	_scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scoreboard.draw.connect(func() -> void:
		var f := UiKit.serif()
		var ctf: bool = m.mode == "ctf"
		var x0 := _scoreboard.size.x * 0.5 - 380.0
		var y := 96.0
		var xs := [0.0, 200.0, 370.0, 420.0, 475.0, 560.0, 640.0]          # name, class, kills, deaths, K/D, streak, flags
		var heads := ["Name", "Class", "K", "D", "K/D", "Streak", "Flags"]
		var count := 0
		for c in m.combatants:
			if not (c is Bot and (c as Bot).life_left >= 0.0):
				count += 1
		_scoreboard.draw_rect(Rect2(Vector2(x0 - 20, y - 46), Vector2(780, 98 + 25.0 * count + 20)), Color(0.02, 0.02, 0.06, 0.82), true)
		_scoreboard.draw_rect(Rect2(Vector2(x0 - 20, y - 46), Vector2(780, 98 + 25.0 * count + 20)), UiKit.GOLD_DARK, false, 2.0)
		for i in heads.size() - (0 if ctf else 1):
			_scoreboard.draw_string(f, Vector2(x0 + xs[i], y - 14), heads[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiKit.GOLD)
		for team in ["red", "blue"]:
			var col := Color(1.0, 0.55, 0.5) if team == "red" else Color(0.6, 0.75, 1.0)
			y += 28.0
			_scoreboard.draw_string(f, Vector2(x0, y), "%s TEAM    %d" % [team.to_upper(), int(m.score[team])], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col.lerp(Color.WHITE, 0.2))
			var rows: Array = []
			for c in m.combatants:
				if c.team == team and not (c is Bot and (c as Bot).life_left >= 0.0):
					rows.append(c)
			rows.sort_custom(func(a: Combatant, b: Combatant) -> bool: return Game.kd(a.kills, a.deaths) > Game.kd(b.kills, b.deaths))      # best kill/death ratio first
			for c in rows:
				y += 25.0
				if c == p:
					_scoreboard.draw_rect(Rect2(Vector2(x0 - 8, y - 18), Vector2(760, 24)), Color(1.0, 0.85, 0.4, 0.16), true)
				var kd := Game.kd(c.kills, c.deaths)
				var cells := [c.display_name + (" (carrying the flag)" if c.carrying_flag != null else ""), Data.classes[c.class_id]["name"], str(c.kills), str(c.deaths), "%.2f" % kd, str(c.streak), str(c.captures)]
				var kd_col := Color(0.55, 1.0, 0.6) if kd >= 1.5 else (Color(1.0, 0.5, 0.45) if kd < 0.8 and c.deaths > 1 else Color(1, 1, 1))
				for i in cells.size() - (0 if ctf else 1):
					_scoreboard.draw_string(f, Vector2(x0 + xs[i], y), cells[i], HORIZONTAL_ALIGNMENT_LEFT, 190 if i < 2 else -1, 17, kd_col if i == 4 else col)
			y += 10.0)
	root.add_child(_scoreboard)


func show_result(winner: String) -> void:
	p.set_ui_blocked(true)
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.75)
	UiKit.full_rect(panel)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -380
	v.offset_right = 380
	v.offset_top = -200
	v.offset_bottom = 200
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var won := winner == p.team
	v.add_child(UiKit.label("VICTORY" if won else ("DRAW" if winner == "draw" else "DEFEAT"), 64, Color(0.5, 1.0, 0.6) if won else Color(1.0, 0.45, 0.4), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label("Score %d - %d     Level: %d" % [m.score["red"], m.score["blue"], Game.level], 20, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var extra := ("   Flags captured: %d" % p.captures) if m.mode == "ctf" else ""
	v.add_child(UiKit.label("Kills %d    Deaths %d    K/D %.2f%s" % [p.kills, p.deaths, Game.kd(p.kills, p.deaths), extra], 24, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label("Career K/D %.2f  (%d kills, %d deaths in %d matches)" % [Game.kd(int(Game.career["kills"]), int(Game.career["deaths"])), int(Game.career["kills"]), int(Game.career["deaths"]), int(Game.career["matches"])], 16, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if Game.last_class_gain.size() >= 4:
		var g: Array = Game.last_class_gain
		var cname: String = String(Data.classes[Game.last_class_id]["name"])
		var ctext := "%s +%d class XP: class level %d (%s)" % [cname, int(g[3]), int(g[1]), Game.class_bonus_text(Game.last_class_id)]
		if int(g[1]) > int(g[0]):
			ctext += "   LEVEL UP!"
		for sid in g[2]:
			ctext += "   New skill: %s" % String(Data.skills[sid]["name"])
		v.add_child(UiKit.label(ctext, 16, Color(0.7, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	if not Game.last_rewards.is_empty():
		var names: PackedStringArray = []
		for k in Game.last_rewards:
			var parts := String(k).split(":")
			var kind_name: String = {"any": "loot", "weapon_new": "new weapon", "weapon_old": "old weapon"}.get(parts[0], String(Game.CRATE_KINDS.get(parts[0], parts[0])))
			names.append("%s %s" % [String(parts[1]).capitalize(), kind_name])
		v.add_child(UiKit.label("Crates earned: " + ", ".join(names) + "   (open them from the title screen: CRATES)", 16, Data.rarity_color(String(Game.last_rewards[0]).split(":")[1]), HORIZONTAL_ALIGNMENT_CENTER))
	if Game.last_rewards.is_empty():
		v.add_child(UiKit.label("No crate this time. Win, score and keep a winning streak for better chances.", 16, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if Game.last_odds != "":
		v.add_child(UiKit.label("Your chances for each crate this match: " + Game.last_odds, 13, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.button("Back to menu", func() -> void:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		m.get_parent().show_menu(), 24, Vector2(300, 54)))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## One status icon: a rounded square with a frame (red harmful / green helpful), a symbol letter, a stack number and a draining time ring.
class StatusIcon extends Control:
	var id := ""
	var d: Dictionary = {}
	var e: Dictionary = {}

	func setup(i: String, data: Dictionary, entry: Dictionary) -> void:
		id = i
		d = data
		e = entry

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var s := size
		var c := s * 0.5
		var harmful: bool = d["harmful"]
		var col := Data.color_of(d["color"])
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.05, 0.08, 0.85), true)
		draw_circle(c, s.x * 0.28, Color(col.r, col.g, col.b, 0.85))
		var f := ThemeDB.fallback_font
		var sym: String = _symbol(String(d.get("symbol", "")))
		draw_string(f, Vector2(c.x - 6, c.y + 7), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.05, 0.05, 0.1))
		var frac := clampf(float(e["time"]) / maxf(float(e["total"]), 0.01), 0.0, 1.0)
		draw_arc(c, s.x * 0.46, -PI / 2.0, -PI / 2.0 + TAU * frac, 28, Color(1, 1, 1, 0.9), 3.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.3, 0.3) if harmful else Color(0.4, 1.0, 0.5), false, 2.5)
		if harmful:
			draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(0, 10)]), Color(1.0, 0.3, 0.3))
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(s.x, 0), Vector2(s.x - 10, 0), Vector2(s.x, 10)]), Color(0.4, 1.0, 0.5))
		if int(e["stacks"]) > 1:
			draw_string(f, Vector2(s.x - 14, s.y - 3), str(int(e["stacks"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

	func _symbol(s: String) -> String:
		match s:
			"flame": return "F"
			"snow": return "*"
			"drop": return "o"
			"bolt": return "Z"
			"stars": return "S"
			"arrow_down": return "v"
			"arrow_up": return "^"
			"roots": return "Y"
			"cross": return "+"
			"mute": return "x"
			"eye": return "O"
			"shield": return "U"
			"plus": return "+"
			"sparkle": return "*"
		return "?"
