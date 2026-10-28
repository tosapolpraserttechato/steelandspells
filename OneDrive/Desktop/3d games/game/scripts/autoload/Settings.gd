extends Node
## The player's settings, saved in user://settings.cfg: volume, display and control options, and the key bindings (any action can be rebound).
## Other scripts read `Settings.v["name"]`; anything that has to react to a change listens to `changed`.

signal changed()

const FILE := "user://settings.cfg"
const DEFAULTS := {
	"master": 0.8, "music": 0.5, "sfx": 0.8,                       # volumes 0..1
	"brightness": 1.0, "contrast": 1.0, "saturation": 1.0,          # picture
	"fullscreen": false, "vsync": true, "show_fps": false, "title_panorama": true, "quality": 1,                 # quality: 0 low, 1 medium, 2 high (how much scenery, shadows and animals)
	"fov": 75.0, "sensitivity": 1.0, "invert_y": false, "shake": 1.0,
}
## The actions that can be rebound: [action, label, group]
const BINDABLE := [
	["move_forward", "Move forward", "Movement"], ["move_back", "Move back", "Movement"], ["move_left", "Move left", "Movement"], ["move_right", "Move right", "Movement"],
	["jump", "Jump", "Movement"], ["sprint", "Sprint (hold)", "Movement"], ["slide", "Slide / crouch", "Movement"],
	["attack", "Attack", "Combat"], ["aim", "Aim", "Combat"], ["skill_1", "Skill 1", "Combat"], ["skill_2", "Skill 2", "Combat"], ["skill_3", "Skill 3", "Combat"],
	["skill_sig", "Signature skill", "Combat"], ["ultimate", "Ultimate", "Combat"], ["quest_skill", "Quest skill", "Combat"], ["meter", "Class meter", "Combat"], ["potion", "Use potion", "Combat"], ["weapon_wheel", "Weapon wheel (hold)", "Combat"],
	["interact", "Interact", "Other"], ["armory", "Armory", "Other"], ["scoreboard", "Scoreboard", "Other"], ["card_toggle", "Hide / show cards", "Other"], ["card_reroll", "Reroll cards", "Other"],
	["card_1", "Pick card 1", "Other"], ["card_2", "Pick card 2", "Other"], ["card_3", "Pick card 3", "Other"], ["menu", "Pause menu", "Other"],
]

var v: Dictionary = DEFAULTS.duplicate()
var _default_events: Dictionary = {}
var _overlay: CanvasLayer
var _overlay_rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for e in BINDABLE:
		_default_events[e[0]] = InputMap.action_get_events(e[0]).duplicate() if InputMap.has_action(e[0]) else []
	_make_buses()
	_make_overlay()
	load_file()
	apply()


# ----------------------------------------------------------------- saving and loading

func load_file() -> void:
	var cf := ConfigFile.new()
	if cf.load(FILE) != OK:
		return
	for k in DEFAULTS:
		if cf.has_section_key("settings", k):
			v[k] = cf.get_value("settings", k, DEFAULTS[k])
	for e in BINDABLE:
		var a: String = e[0]
		if cf.has_section_key("binds", a):
			var arr: Array = cf.get_value("binds", a, [])
			InputMap.action_erase_events(a)
			for code in arr:
				var ev := _decode(String(code))
				if ev != null:
					InputMap.action_add_event(a, ev)


func save_file() -> void:
	var cf := ConfigFile.new()
	for k in DEFAULTS:
		cf.set_value("settings", k, v[k])
	for e in BINDABLE:
		var a: String = e[0]
		var arr: Array = []
		for ev in InputMap.action_get_events(a):
			arr.append(_encode(ev))
		cf.set_value("binds", a, arr)
	cf.save(FILE)


func _encode(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return "k:%d" % (ev as InputEventKey).physical_keycode
	if ev is InputEventMouseButton:
		return "m:%d" % (ev as InputEventMouseButton).button_index
	return ""


func _decode(s: String) -> InputEvent:
	var parts := s.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "k":
		var ev := InputEventKey.new()
		ev.physical_keycode = int(parts[1]) as Key
		return ev
	if parts[0] == "m":
		var ev := InputEventMouseButton.new()
		ev.button_index = int(parts[1]) as MouseButton
		return ev
	return null


# ----------------------------------------------------------------- applying

func set_value(key: String, value: Variant) -> void:
	v[key] = value
	apply()
	save_file()


func reset_all() -> void:
	v = DEFAULTS.duplicate()
	reset_binds()
	apply()
	save_file()


func _make_buses() -> void:
	for nm in ["Music", "SFX"]:
		if AudioServer.get_bus_index(nm) < 0:
			AudioServer.add_bus()
			var i := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(i, nm)
			AudioServer.set_bus_send(i, "Master")


func _make_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 120
	add_child(_overlay)
	_overlay_rect = ColorRect.new()
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/screen_adjust.gdshader")
	_overlay_rect.material = _mat
	_overlay.add_child(_overlay_rect)


func apply() -> void:
	_set_bus("Master", float(v["master"]))
	_set_bus("Music", float(v["music"]))
	_set_bus("SFX", float(v["sfx"]))
	if _mat != null:
		_mat.set_shader_parameter("brightness", float(v["brightness"]))
		_mat.set_shader_parameter("contrast", float(v["contrast"]))
		_mat.set_shader_parameter("saturation", float(v["saturation"]))
		# no extra pass at all while everything is at its normal value
		_overlay_rect.visible = absf(float(v["brightness"]) - 1.0) > 0.01 or absf(float(v["contrast"]) - 1.0) > 0.01 or absf(float(v["saturation"]) - 1.0) > 0.01
	if DisplayServer.get_name() != "headless":
		var want_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(v["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want_mode:
			DisplayServer.window_set_mode(want_mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(v["vsync"]) else DisplayServer.VSYNC_DISABLED)
	changed.emit()


func _set_bus(nm: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(nm)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(i, linear <= 0.001)


# ----------------------------------------------------------------- key bindings

## Text for the key(s) bound to `action`, for the menus and hints.
func key_text(action: String) -> String:
	var parts: Array = []
	for ev in InputMap.action_get_events(action):
		parts.append(event_text(ev))
	return " / ".join(parts) if not parts.is_empty() else "(not set)"


func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical((ev as InputEventKey).physical_keycode))
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Mouse 1"
			MOUSE_BUTTON_RIGHT: return "Mouse 2"
			MOUSE_BUTTON_MIDDLE: return "Mouse 3"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
	return "?"


## Gives `action` the single input `ev`. A key already used by another bindable action is taken from it (so two actions never share a key).
## Returns the label of the action that lost its key, or "".
func rebind(action: String, ev: InputEvent) -> String:
	var taken := ""
	var code := _encode(ev)
	for e in BINDABLE:
		var a: String = e[0]
		if a == action:
			continue
		for old in InputMap.action_get_events(a):
			if _encode(old) == code:
				InputMap.action_erase_event(a, old)
				taken = String(e[1])
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	save_file()
	changed.emit()
	return taken


func reset_binds() -> void:
	for e in BINDABLE:
		var a: String = e[0]
		InputMap.action_erase_events(a)
		for ev in _default_events[a]:
			InputMap.action_add_event(a, ev)
	save_file()
	changed.emit()


## 0 low, 1 medium, 2 high. The scenery, rim, animals and shadows scale with it (Decor.gd, Border.gd, Critters.gd, MapLoader.apply_environment).
func quality() -> int:
	return clampi(int(v.get("quality", 1)), 0, 2)
