class_name CrateOpen
extends Control
## The crate-open screen. A chest of the crate's rarity (Chest.gd) opens in its own way for each rarity (a creak, a hop, a burst, a spin with lightning, a levitation
## with rays, a rune storm), then a SLIDER of items rolls past and slows down on the item you got, then the roll is revealed one beat at a time:
## item type -> which item -> old or brand new -> skin -> modifier (or the flaw of an old item). Space skips. At the end: Equip / Keep / Compare.

signal closed(result: Dictionary)

const STEP_TIME := 0.5
const CARD_W := 150.0
const SLIDE_SECONDS := 4.6

var result: Dictionary = {}
var crate: Node = null
var _vp: SubViewport
var _crate_node: Node3D
var _chest: Chest
var _light: OmniLight3D
var _cam: Camera3D
var _steps_box: VBoxContainer
var _card_holder: Control
var _buttons: HBoxContainer
var _title: Label
var _t := 0.0
var _phase := "open"                # open -> slider -> steps -> done
var _step_index := 0
var _step_timer := 0.0
var _reel_label: Label
var _step_rows: Array = []
var _rarity := "common"
var _compare_label: Label
var _open_tween: Tween
var _slider_clip: Control
var _slider_strip: Control
var _slider_tween: Tween
var _slider_cards := 0
var _slider_target := 0
var _last_tick := -1
var _flash: ColorRect
var _debug_phase := ""
var _hint: Label


func open_with(roll: Dictionary, crate_node: Node = null) -> void:
	result = roll
	crate = crate_node
	_rarity = String(roll.get("crate_rarity", roll["rarity"]))
	_build()
	visible = true


func _build() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.05, 0.99)
	UiKit.full_rect(back)
	add_child(back)
	var col := Data.rarity_color(_rarity)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.0
	root.anchor_bottom = 1.0
	root.offset_left = -460
	root.offset_right = 460
	root.offset_top = 14
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	_title = UiKit.label("%s CRATE" % ("GOLD" if result.get("gold", false) else String(Data.rarity(_rarity)["name"]).to_upper()), 34, col, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_title)
	# the chest, in its own little 3D world
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(920, 200)
	svc.stretch = true
	root.add_child(svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.size = Vector2i(920, 200)
	svc.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.8)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.2
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.75, 4.9)
	_cam.rotation_degrees = Vector3(-11, 0, 0)
	_cam.fov = 38
	_vp.add_child(_cam)
	_crate_node = Node3D.new()
	_vp.add_child(_crate_node)
	_chest = Chest.make(_rarity)
	_crate_node.add_child(_chest)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 0.0
	_light.omni_range = 8.0
	_light.position = Vector3(0, 1.2, 1.2)
	_vp.add_child(_light)
	# the slider: a window of cards that scroll by (hidden until the chest is open)
	_slider_clip = Control.new()
	_slider_clip.custom_minimum_size = Vector2(920, 120)
	_slider_clip.clip_contents = true
	_slider_clip.visible = false
	root.add_child(_slider_clip)
	_build_slider()
	# reveal rows
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 20)
	root.add_child(mid)
	_steps_box = VBoxContainer.new()
	_steps_box.add_theme_constant_override("separation", 3)
	_steps_box.custom_minimum_size = Vector2(470, 200)
	mid.add_child(_steps_box)
	_card_holder = Control.new()
	_card_holder.custom_minimum_size = Vector2(430, 225)
	mid.add_child(_card_holder)
	# The buttons sit in a bar pinned to the bottom of the screen. They used to be the last row of the column above, and in a window that is not tall enough the column
	# pushed them off the bottom edge: nothing to click, a softlock (Esc still closed it, but nobody knew).
	var bar := VBoxContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 0
	bar.offset_right = 0
	bar.offset_top = -104
	bar.offset_bottom = -6
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.add_theme_constant_override("separation", 2)
	add_child(bar)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	bar.add_child(_buttons)
	_hint = UiKit.label("Space: skip the roll", 15, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	bar.add_child(_hint)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	UiKit.full_rect(_flash)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_phase = "open"
	_t = 0.0
	Game.save_profile()
	_start_open()


# ----------------------------------------------------------------- opening the chest: a different one for each rarity

func _glow() -> float:
	return float(Data.rarity(_rarity)["glow"])


func _burst(amount: int, spread: float, up: float = 1.0) -> void:
	var col := Data.rarity_color(_rarity)
	var p := Fx.particles({"tex": "star", "amount": amount, "life": 1.6, "one_shot": true, "burst": 1.0, "vel": [2.0 * up, 6.0 * up], "dir": Vector3.UP, "spread": spread,
		"gravity": Vector3(0, -2, 0), "size": [0.1, 0.28], "colors": [Color(1, 1, 1, 1), Color(col.r, col.g, col.b, 0.9), Color(col.r, col.g, col.b, 0)]})
	p.position = Vector3(0, 0.7, 0.1)
	_vp.add_child(p)


func _beam() -> void:
	var b := Fx.crate_beam(_rarity, 4.5)
	b.position = Vector3(0, 0.55, 0)
	_vp.add_child(b)


func _flash_screen(a: float, secs: float) -> void:
	_flash.color = Color(1, 1, 1, a)
	create_tween().tween_property(_flash, "color:a", 0.0, secs)


func _start_open() -> void:
	var tw := create_tween()
	_open_tween = tw
	var open := func(angle: float) -> void: _chest.set_lid(angle)
	var shake := func(k: float) -> void:
		_crate_node.rotation.y = sin(k * 90.0) * 0.07 * (1.0 - k * 0.2)
		_crate_node.rotation.z = sin(k * 120.0) * 0.05
	match _rarity:
		"common":
			# a creak: a small wobble, the lid lifts slowly with a puff of dust
			tw.tween_method(shake, 0.0, 0.5, 0.6)
			tw.tween_callback(func() -> void: _light.light_energy = 1.0)
			tw.tween_method(open, 0.0, 70.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void: _burst(18, 70.0, 0.6))
		"uncommon":
			# a hop, then the lid pops open with a bounce
			tw.tween_property(_crate_node, "position:y", 0.45, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(_crate_node, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_method(open, 0.0, 100.0, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void:
				_burst(34, 60.0)
				_light.light_energy = 3.0)
		"rare":
			# a hard shake, then the lid bursts open under a column of blue light
			tw.tween_method(shake, 0.0, 1.0, 1.0)
			tw.tween_method(open, 0.0, 115.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void:
				_burst(60, 55.0)
				_beam()
				_light.light_energy = 4.0
				_flash_screen(0.25, 0.4))
		"epic":
			# the chest rises and spins twice, lightning strikes it, the lid is flung back
			tw.tween_property(_crate_node, "position:y", 0.7, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(_crate_node, "rotation:y", TAU * 2.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_callback(func() -> void:
				Fx.lightning_strike(_crate_node.global_position, 4.0)
				_flash_screen(0.45, 0.5))
			tw.tween_method(open, 0.0, 125.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void:
				_burst(90, 70.0, 1.2)
				_beam()
				_light.light_energy = 5.0)
			tw.tween_property(_crate_node, "position:y", 0.2, 0.5).set_trans(Tween.TRANS_SINE)
		"legendary":
			# the chest floats up in a ring of golden light, the lid lifts slowly and the room fills with light
			tw.tween_property(_crate_node, "position:y", 0.7, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(_light, "light_energy", 5.0, 1.2)
			tw.tween_callback(func() -> void:
				_beam()
				Fx.ring(_crate_node.global_position, 6.0, Color(1.0, 0.85, 0.35), 1.0))
			tw.tween_method(open, 0.0, 130.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tw.tween_callback(func() -> void:
				_burst(140, 80.0, 1.4)
				_flash_screen(0.7, 0.9)
				_light.light_energy = 6.0)
		_:
			# mythic: the chest hovers in a storm of runes, cracks, and the lid is thrown off with a shockwave
			tw.tween_property(_crate_node, "position:y", 0.85, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(_crate_node, "rotation:y", TAU * 3.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.parallel().tween_property(_light, "light_energy", 5.0, 1.8)
			tw.tween_callback(func() -> void:
				Fx.lightning_strike(_crate_node.global_position, 5.0)
				_flash_screen(0.9, 0.7))
			tw.tween_method(open, 0.0, 150.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void:
				_burst(200, 90.0, 1.6)
				_beam()
				Fx.ring(_crate_node.global_position, 8.0, Data.rarity_color(_rarity), 1.2)
				_light.light_energy = 7.0)
			tw.tween_interval(0.4)
	tw.tween_callback(_begin_slider)


# ----------------------------------------------------------------- the slider

func _card_names() -> Array:
	var pool: Array = []
	for i in Data.weapon_order:
		pool.append(Data.weapons[i]["name"])
	for i in Data.armor_order:
		pool.append(Data.armor_sets[i]["name"])
	for i in Data.rune_order:
		pool.append(Data.runes[i]["name"])
	pool.append_array(["Card reroll", "Experience"])
	return pool


## The name and rarity shown on the card the slider stops on.
func _target_card() -> Array:
	if result.has("item"):
		var it: Dictionary = result["item"]
		return [Loot.item_name(it), String(it["rarity"])]
	if result["type"] == "reroll":
		return ["Card reroll", _rarity]
	return ["Experience", _rarity]


func _build_slider() -> void:
	_slider_strip = Control.new()
	_slider_clip.add_child(_slider_strip)
	var names := _card_names()
	_slider_cards = 46
	_slider_target = 38 + randi() % 3
	for i in _slider_cards:
		var nm: String = names[randi() % names.size()]
		var rar: String = Data.rarity_ids[Loot._pick([40.0, 28.0, 18.0, 9.0, 4.0, 1.0])]
		if i == _slider_target:
			var tc := _target_card()
			nm = tc[0]
			rar = tc[1]
		_slider_strip.add_child(_make_card(i, nm, rar))
	_slider_strip.size = Vector2(_slider_cards * CARD_W, 128)
	_slider_strip.position = Vector2(0, 0)
	# the marker in the middle
	var marker := Control.new()
	marker.size = Vector2(920, 128)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.draw.connect(func() -> void:
		marker.draw_line(Vector2(460, 0), Vector2(460, 128), Color(1, 0.9, 0.5, 0.9), 3.0)
		marker.draw_colored_polygon(PackedVector2Array([Vector2(446, 0), Vector2(474, 0), Vector2(460, 16)]), Color(1, 0.9, 0.5))
		marker.draw_colored_polygon(PackedVector2Array([Vector2(446, 128), Vector2(474, 128), Vector2(460, 112)]), Color(1, 0.9, 0.5)))
	_slider_clip.add_child(marker)
	# the edges fade to black
	var fade := Control.new()
	fade.size = Vector2(920, 128)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.draw.connect(func() -> void:
		var edge := Color(0, 0, 0, 0.9)
		var clear := Color(0, 0, 0, 0)
		fade.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(150, 0), Vector2(150, 128), Vector2(0, 128)]), PackedColorArray([edge, clear, clear, edge]))
		fade.draw_polygon(PackedVector2Array([Vector2(770, 0), Vector2(920, 0), Vector2(920, 128), Vector2(770, 128)]), PackedColorArray([clear, edge, edge, clear])))
	_slider_clip.add_child(fade)


func _make_card(i: int, nm: String, rar: String) -> Control:
	var c := Control.new()
	c.position = Vector2(i * CARD_W, 0)
	c.size = Vector2(CARD_W - 6, 128)
	var col := Data.rarity_color(rar)
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(3, 8, CARD_W - 12, 112), col.darkened(0.7), true)
		c.draw_rect(Rect2(3, 8, CARD_W - 12, 112), col, false, 3.0)
		c.draw_rect(Rect2(3, 100, CARD_W - 12, 20), col.darkened(0.2), true)
		var f := UiKit.serif()
		# a small gem in the middle in the card's rarity colour
		c.draw_colored_polygon(PackedVector2Array([Vector2(66, 34), Vector2(87, 56), Vector2(66, 82), Vector2(45, 56)]), col.lightened(0.15))
		c.draw_colored_polygon(PackedVector2Array([Vector2(66, 34), Vector2(87, 56), Vector2(66, 56)]), col.lightened(0.5))
		c.draw_string(f, Vector2(8, 115), nm.substr(0, 17), HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 20, 14, Color(0.05, 0.05, 0.08)))
	return c


func _begin_slider() -> void:
	_phase = "slider"
	_title.text = "..."
	_slider_clip.visible = true
	var target_x := -(float(_slider_target) * CARD_W + CARD_W * 0.5 - 460.0) + randf_range(-CARD_W * 0.3, CARD_W * 0.3)
	_slider_tween = create_tween()
	_slider_tween.tween_property(_slider_strip, "position:x", target_x, SLIDE_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_slider_tween.tween_callback(_slider_done)


func _slider_done() -> void:
	_title.text = "%s CRATE" % ("GOLD" if result.get("gold", false) else String(Data.rarity(_rarity)["name"]).to_upper())
	var tc := _target_card()
	_light.light_color = Data.rarity_color(String(tc[1]))
	_light.light_energy = 6.0
	_flash_screen(0.18, 0.3)
	Sfx.play("chime")
	_phase = "steps"
	_step_index = 0
	_step_timer = 0.0
	_begin_step()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var glow := _glow()
	_chest.spin_extras(_t)
	if OS.get_environment("TOAST_DEBUG") != "" and _phase != _debug_phase:
		_debug_phase = _phase
		print("CRATE phase ", _phase, " at ", snappedf(_t, 0.1), " rarity ", _rarity, " type ", result.get("type", "?"))
	match _phase:
		"slider":
			# a tick every time a card passes the marker
			var idx := int(floor((460.0 - _slider_strip.position.x) / CARD_W))
			if idx != _last_tick:
				_last_tick = idx
				Sfx.play("click", -6.0, 1.0 + 0.2 * (1.0 - float(idx) / float(_slider_cards)))
			_light.light_energy = lerpf(_light.light_energy, 2.0 + 3.0 * glow, delta * 2.0)
		"steps":
			_step_timer += delta
			_crate_node.rotation.y += delta * 0.5
			if _reel_label != null:
				_reel_label.text = _random_name()
			if _step_timer >= STEP_TIME:
				_lock_step()
				_step_index += 1
				_step_timer = 0.0
				if _step_index >= result["steps"].size():
					_finish()
				else:
					_begin_step()
		"done":
			_crate_node.rotation.y += delta * 0.5


func _random_name() -> String:
	var pool: Array = []
	match result.get("type", "weapon"):
		"weapon": pool = Data.weapon_order.map(func(i: String) -> String: return Data.weapons[i]["name"])
		"rune": pool = Data.rune_order.map(func(i: String) -> String: return Data.runes[i]["name"])
		"armor", "shield": pool = Data.armor_order.map(func(i: String) -> String: return Data.armor_sets[i]["name"])
		_: pool = ["Weapon", "Armor piece", "Shield", "Rune", "Card reroll", "Experience"]
	return pool[randi() % pool.size()]


func _begin_step() -> void:
	var step: Dictionary = result["steps"][_step_index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var lab := UiKit.label(String(step["label"]) + ":", 18, UiKit.DIM)
	lab.custom_minimum_size = Vector2(130, 0)
	row.add_child(lab)
	_reel_label = UiKit.label("...", 18, Color(1, 1, 1, 0.7))
	_reel_label.custom_minimum_size = Vector2(320, 0)
	row.add_child(_reel_label)
	_steps_box.add_child(row)
	_step_rows.append(row)
	while _steps_box.get_child_count() > 6:
		_steps_box.get_child(0).queue_free()
		_steps_box.remove_child(_steps_box.get_child(0))


func _lock_step() -> void:
	if _reel_label == null:
		return
	var step: Dictionary = result["steps"][_step_index]
	_reel_label.text = String(step["value"])
	_reel_label.add_theme_color_override("font_color", Data.rarity_color(String(step["rarity"])))
	_reel_label.add_theme_font_size_override("font_size", 20)
	_reel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reel_label.custom_minimum_size = Vector2(320, 0)
	var col := Data.rarity_color(String(step["rarity"]))
	_light.light_color = col
	_light.light_energy = 5.0
	_reel_label = null


func _finish() -> void:
	_phase = "done"
	_show_result()


func _skip() -> void:
	if _phase == "done":
		return
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	if _slider_tween != null and _slider_tween.is_valid():
		_slider_tween.kill()
	_slider_clip.visible = false
	_chest.set_lid(115.0)
	_light.light_color = Data.rarity_color(String(_target_card()[1]))
	_light.light_energy = 6.0
	for c in _steps_box.get_children():
		c.queue_free()
	for s in result["steps"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var lab := UiKit.label(String(s["label"]) + ":", 18, UiKit.DIM)
		lab.custom_minimum_size = Vector2(130, 0)
		row.add_child(lab)
		var vl := UiKit.label(String(s["value"]), 20, Data.rarity_color(String(s["rarity"])))
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vl.custom_minimum_size = Vector2(320, 0)
		row.add_child(vl)
		_steps_box.add_child(row)
	_reel_label = null
	_phase = "done"
	_show_result()


func _show_result() -> void:
	if _hint != null:
		_hint.text = "Enter or Esc: keep it and close"
	for c in _buttons.get_children():
		c.queue_free()
	var type: String = result["type"]
	if type == "reroll":
		Game.add_rerolls(int(result["reroll"]))
		_buttons.add_child(UiKit.button("Take it", _close, 20))
		return
	if type == "xp":
		Game.add_xp(float(result["xp"]), true)
		_buttons.add_child(UiKit.button("Take it", _close, 20))
		return
	var item: Dictionary = result["item"]
	Game.add_item(item)
	var card := RarityFrame.new()
	card.custom_minimum_size = Vector2(420, 220)
	card.size = Vector2(420, 220)
	card.position = Vector2(0, 0)
	var lines: Array = Loot.describe(item)
	card.set_data(String(item["rarity"]), Loot.item_name(item), ("Brand new" if item.get("new", false) else "Old and worn") if item["kind"] != "rune" else "Rune",
		"\n".join(lines.slice(0, 3)), "")
	card.magic_icon = (item["kind"] == "weapon" and Data.weapons[item["id"]]["magic"]) or (item["kind"] == "armor" and Data.armor_sets[item["set"]]["magic"])
	card.set_art(IconArt.glyph_for_item(item), IconArt.category_for_item(item))
	if item["kind"] == "weapon" and Data.weapons.has(item["id"]):
		card.set_weapon(Data.weapons[item["id"]])
	_card_holder.add_child(card)
	if item.has("aura"):
		var a := UiKit.label("Aura: %s" % ("Gold" if item["aura"] == "gold" else String(item["aura"]).capitalize()), 18, Data.rarity_color("legendary" if item["aura"] == "gold" else "mythic"))
		a.position = Vector2(8, 238)
		_card_holder.add_child(a)
	if item["kind"] == "rune":
		_buttons.add_child(UiKit.button("Keep (Armory: socket it)", _close, 18, Vector2(260, 44)))
	else:
		_buttons.add_child(UiKit.button("Equip", func() -> void:
			Game.equip(item)
			_close(), 20))
		_buttons.add_child(UiKit.button("Keep in bag", _close, 20))
		_buttons.add_child(UiKit.button("Compare", func() -> void: _compare(item), 20))
	_compare_label = UiKit.label("", 16, UiKit.DIM)
	_buttons.get_parent().add_child(_compare_label)
	_buttons.get_parent().move_child(_compare_label, _buttons.get_index() + 1)


func _compare(item: Dictionary) -> void:
	var slot: String = "weapon" if item["kind"] == "weapon" else String(item["slot"])
	var cur: Dictionary = Game.equipped_item(slot)
	if cur.is_empty() or cur["uid"] == item["uid"]:
		_compare_label.text = "Nothing equipped in that slot yet."
		return
	_compare_label.text = "Now: %s (%s)\n    New: %s (%s)" % [Loot.item_name(cur), String(cur["rarity"]).capitalize(), Loot.item_name(item), String(item["rarity"]).capitalize()]


func _close() -> void:
	visible = false
	closed.emit(result)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("skip"):
		_skip()
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("menu") or event.is_action_pressed("ui_accept")) and _phase == "done":              # Esc or Enter closes it (keeps the item)
		_close()
