class_name SettingsMenu
extends Control
## The settings screen (title screen and pause menu): sound, picture, controls and key bindings. Every change is applied and saved at once (see Settings.gd).

signal closed()

const TABS := ["Sound", "Picture", "Controls", "Key bindings"]

var start_tab := 0
var _tab := 0
var _content: VBoxContainer
var _tab_row: HBoxContainer
var _capturing := ""                       # the action waiting for a new key
var _capture_button: Button
var _note: Label
var _key_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.82)
	UiKit.full_rect(dim)
	add_child(dim)
	var panel := UiKit.panel(Color(0.06, 0.07, 0.12, 0.98), UiKit.GOLD_DARK, 10)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -450
	panel.offset_right = 450
	panel.offset_top = -310
	panel.offset_bottom = 310
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	head.add_child(UiKit.label("SETTINGS", 34, UiKit.GOLD))
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 6)
	_tab_row.alignment = BoxContainer.ALIGNMENT_END
	_tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_tab_row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	_note = UiKit.label("", 15, Color(1.0, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_note)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	foot.add_child(UiKit.button("Reset everything", func() -> void:
		Settings.reset_all()
		_note.text = "All settings and key bindings are back to normal."
		_build(), 17, Vector2(200, 44)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	foot.add_child(UiKit.button("Done", func() -> void: _close(), 22, Vector2(200, 44)))
	_tab = start_tab
	_build()


func _close() -> void:
	Settings.save_file()
	closed.emit()
	queue_free()


func _build() -> void:
	_capturing = ""
	_key_buttons.clear()
	for c in _tab_row.get_children():
		c.queue_free()
	for i in TABS.size():
		var idx := i
		_tab_row.add_child(UiKit.tab_button(TABS[i], i == _tab, func() -> void:
			_tab = idx
			_note.text = ""
			_build(), 16, Vector2(120, 36)))
	for c in _content.get_children():
		c.queue_free()
	match _tab:
		0: _build_sound()
		1: _build_picture()
		2: _build_controls()
		3: _build_keys()


# ----------------------------------------------------------------- widgets

func _row(label: String, tip: String = "") -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 14)
	var l := UiKit.label(label, 19, UiKit.TEXT)
	l.custom_minimum_size = Vector2(250, 0)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	r.add_child(l)
	_content.add_child(r)
	return r


func _slider(label: String, key: String, lo: float, hi: float, step: float, percent: bool = true, tip: String = "") -> void:
	var r := _row(label, tip)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.v[key])
	s.custom_minimum_size = Vector2(340, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.13, 0.2)
	track.border_color = UiKit.GOLD_DARK
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := track.duplicate()
	fill.bg_color = Color(0.75, 0.55, 0.15)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	r.add_child(s)
	var val := UiKit.label("", 18, UiKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	val.custom_minimum_size = Vector2(70, 0)
	r.add_child(val)
	var show := func(x: float) -> void:
		val.text = ("%d%%" % roundi(x * 100.0)) if percent else ("%.1f" % x if hi < 20.0 else "%d" % roundi(x))
	show.call(s.value)
	s.value_changed.connect(func(x: float) -> void:
		show.call(x)
		Settings.set_value(key, x))
	if key in ["master", "music", "sfx"]:
		s.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("chime"))


func _toggle(label: String, key: String, tip: String = "") -> void:
	var r := _row(label, tip)
	var b := UiKit.tab_button("ON" if Settings.v[key] else "OFF", bool(Settings.v[key]), func() -> void: pass, 18, Vector2(110, 36))
	r.add_child(b)
	b.pressed.connect(func() -> void:
		var now := not bool(Settings.v[key])
		Settings.set_value(key, now)
		_build())


func _choice(label: String, key: String, options: Array, tip: String = "") -> void:
	var r := _row(label, tip)
	for i in options.size():
		var idx := i
		var b := UiKit.tab_button(String(options[i]), int(Settings.v[key]) == i, func() -> void: pass, 17, Vector2(110, 36))
		r.add_child(b)
		b.pressed.connect(func() -> void:
			Settings.set_value(key, idx)
			_build())


func _build_sound() -> void:
	_slider("Master volume", "master", 0.0, 1.0, 0.01)
	_slider("Music", "music", 0.0, 1.0, 0.01)
	_slider("Sound effects", "sfx", 0.0, 1.0, 0.01, true, "Spells, hits, footsteps and menu sounds")
	_content.add_child(UiKit.label("Release a slider to hear a sound at that volume.", 14, UiKit.DIM))


func _build_picture() -> void:
	_slider("Brightness", "brightness", 0.6, 1.6, 0.02)
	_slider("Contrast", "contrast", 0.7, 1.4, 0.02)
	_slider("Colour strength", "saturation", 0.0, 1.6, 0.02, true, "0% is black and white")
	_choice("Graphics quality", "quality", ["Low", "Medium", "High"], "How much scenery, shadow and animals there are. Low and Medium run faster on weaker computers. Takes effect when the next match starts.")
	_toggle("Fullscreen", "fullscreen")
	_toggle("VSync", "vsync", "Stops the picture tearing; turn it off for the highest frame rate")
	_toggle("Show frame rate", "show_fps")
	_toggle("Title screen: map panorama", "title_panorama", "The title screen shows the maps slowly turning around. Turn off if it is slow. Takes effect next time the title screen opens.")
	_content.add_child(UiKit.button("Back to normal picture", func() -> void:
		for k in ["brightness", "contrast", "saturation"]:
			Settings.set_value(k, Settings.DEFAULTS[k])
		_build(), 16, Vector2(240, 38)))


func _build_controls() -> void:
	_slider("Mouse sensitivity", "sensitivity", 0.2, 3.0, 0.05, false)
	_slider("Field of view", "fov", 60.0, 110.0, 1.0, false, "How wide the camera sees. The camera narrows a little when aiming.")
	_slider("Camera shake", "shake", 0.0, 1.5, 0.05, true, "0% turns the shake off")
	_toggle("Invert mouse up / down", "invert_y")


func _build_keys() -> void:
	_content.add_child(UiKit.label("Click a key, then press the new key or mouse button. Esc cancels. A key that is already used moves to this action.", 14, UiKit.DIM))
	var group := ""
	var grid: GridContainer
	for e in Settings.BINDABLE:
		if e[2] != group:
			group = e[2]
			_content.add_child(UiKit.label(String(group).to_upper(), 16, UiKit.GOLD))
			grid = GridContainer.new()
			grid.columns = 4
			grid.add_theme_constant_override("h_separation", 16)
			grid.add_theme_constant_override("v_separation", 6)
			_content.add_child(grid)
		var action: String = e[0]
		var l := UiKit.label(String(e[1]), 18, UiKit.TEXT)
		l.custom_minimum_size = Vector2(170, 0)
		grid.add_child(l)
		var b := UiKit.button(Settings.key_text(action), func() -> void: pass, 16, Vector2(190, 34))
		b.pressed.connect(_start_capture.bind(action, b))
		grid.add_child(b)
		_key_buttons[action] = b


func _start_capture(action: String, b: Button) -> void:
	if _capture_button != null and is_instance_valid(_capture_button) and _capturing != "":
		_capture_button.text = Settings.key_text(_capturing)
	_capturing = action
	_capture_button = b
	b.text = "press a key..."
	_note.text = ""


func _input(event: InputEvent) -> void:
	if _capturing == "":
		return
	var ev: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			_capture_button.text = Settings.key_text(_capturing)
			_capturing = ""
			get_viewport().set_input_as_handled()
			return
		var k := InputEventKey.new()
		k.physical_keycode = (event as InputEventKey).physical_keycode
		ev = k
	elif event is InputEventMouseButton and event.pressed:
		var m := InputEventMouseButton.new()
		m.button_index = (event as InputEventMouseButton).button_index
		ev = m
	if ev == null:
		return
	get_viewport().set_input_as_handled()
	var action := _capturing
	_capturing = ""
	var lost := Settings.rebind(action, ev)
	_note.text = "%s is now %s%s" % [_label_of(action), Settings.event_text(ev), ("  (taken from %s)" % lost) if lost != "" else ""]
	# the key may have moved from another action: refresh every label
	for a in _key_buttons:
		(_key_buttons[a] as Button).text = Settings.key_text(a)


func _label_of(action: String) -> String:
	for e in Settings.BINDABLE:
		if e[0] == action:
			return String(e[1])
	return action
