class_name MainMenu
extends Control
## The title screen: a painted night sky with mountains, a moon and drifting embers; the logo; the menu (Play, Armory); the map, mode and team size;
## and your hero standing in a magic circle on the right (arrows change the class). Play opens the lobby, where the map is voted.

signal play_pressed()
signal armory_pressed()
signal net_pressed()

var _mode_btn: Button
var _bots_label: Label
var _preview: ModelPreview
var _class_label: Label
var _class_sub: Label


## The animated backdrop: sky gradient, stars, a moon with a halo, three rows of mountains and rising embers.
class Backdrop extends Control:
	var _t := 0.0
	var _stars: Array = []
	var _embers: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 110:
			_stars.append([rng.randf(), rng.randf() * 0.55, rng.randf_range(0.6, 2.0), rng.randf() * TAU])
		for i in 46:
			_embers.append([rng.randf(), rng.randf(), rng.randf_range(0.02, 0.07), rng.randf_range(1.0, 3.2), rng.randf() * TAU])

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _ridge(seed_off: float, base: float, amp: float, rough: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var n := 40
		for i in n + 1:
			var x := size.x * i / n
			var u := float(i) / n
			var y := size.y * base - size.y * amp * (0.5 + 0.5 * sin(u * 6.0 + seed_off) * 0.6 + 0.35 * sin(u * 13.0 + seed_off * 2.1) * rough + 0.15 * sin(u * 29.0 + seed_off * 3.7))
			pts.append(Vector2(x, y))
		pts.append(Vector2(size.x, size.y))
		pts.append(Vector2(0, size.y))
		return pts

	func _draw() -> void:
		var s := size
		# sky
		var top := Color(0.03, 0.03, 0.10)
		var mid := Color(0.16, 0.08, 0.26)
		var low := Color(0.62, 0.30, 0.28)
		var sky := PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.55), Vector2(0, s.y * 0.55)])
		draw_polygon(sky, PackedColorArray([top, top, mid, mid]))
		var sky2 := PackedVector2Array([Vector2(0, s.y * 0.55), Vector2(s.x, s.y * 0.55), Vector2(s.x, s.y * 0.85), Vector2(0, s.y * 0.85)])
		draw_polygon(sky2, PackedColorArray([mid, mid, low, low]))
		# stars
		for st in _stars:
			var tw := 0.5 + 0.5 * sin(_t * st[2] + st[3])
			draw_circle(Vector2(st[0] * s.x, st[1] * s.y), 0.6 + st[2] * 0.5, Color(1, 0.96, 0.85, 0.25 + 0.6 * tw))
		# moon with a halo
		var mc := Vector2(s.x * 0.62, s.y * 0.2)
		for i in 7:
			draw_circle(mc, s.y * (0.28 - 0.03 * i), Color(0.8, 0.75, 1.0, 0.025 + 0.012 * i))
		draw_circle(mc, s.y * 0.075, Color(0.96, 0.95, 0.88))
		draw_circle(mc + Vector2(s.y * 0.02, -s.y * 0.012), s.y * 0.07, Color(0.9, 0.88, 0.8))
		draw_circle(mc + Vector2(-s.y * 0.02, s.y * 0.015), s.y * 0.012, Color(0.8, 0.78, 0.72))
		draw_circle(mc + Vector2(s.y * 0.025, s.y * 0.03), s.y * 0.009, Color(0.8, 0.78, 0.72))
		# mountains
		var far := Color(0.22, 0.14, 0.3)
		var mid_c := Color(0.12, 0.09, 0.2)
		var near := Color(0.05, 0.05, 0.1)
		draw_colored_polygon(_ridge(0.5, 0.78, 0.30, 1.0), far)
		draw_colored_polygon(_ridge(2.2, 0.86, 0.24, 1.2), mid_c)
		draw_colored_polygon(_ridge(4.6, 0.95, 0.18, 0.8), near)
		# a castle on the far ridge
		var cx := s.x * 0.2
		var cy := s.y * 0.60
		var cc := Color(0.1, 0.07, 0.17)
		draw_rect(Rect2(cx - 40, cy - 38, 80, 60), cc)
		for k in 5:
			draw_rect(Rect2(cx - 40 + k * 18, cy - 46, 10, 10), cc)
		draw_rect(Rect2(cx - 62, cy - 66, 22, 88), cc)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 66, cy - 66), Vector2(cx - 51, cy - 92), Vector2(cx - 36, cy - 66)]), cc)
		draw_rect(Rect2(cx + 40, cy - 80, 24, 102), cc)
		draw_colored_polygon(PackedVector2Array([Vector2(cx + 36, cy - 80), Vector2(cx + 52, cy - 108), Vector2(cx + 68, cy - 80)]), cc)
		for w in [Vector2(cx - 52, cy - 40), Vector2(cx + 52, cy - 56), Vector2(cx - 8, cy - 14), Vector2(cx + 14, cy - 14)]:
			draw_rect(Rect2(w, Vector2(4, 8)), Color(1.0, 0.8, 0.4, 0.8 + 0.2 * sin(_t * 2.0 + w.x)))
		# embers rising
		for e in _embers:
			var p := fposmod(e[1] - _t * e[2], 1.0)
			var x: float = e[0] * s.x + sin(_t * 0.7 + e[4]) * 14.0
			var a := sin(p * PI)
			draw_circle(Vector2(x, p * s.y), e[3], Color(1.0, 0.65, 0.3, 0.7 * a))
			draw_circle(Vector2(x, p * s.y), e[3] * 2.6, Color(1.0, 0.5, 0.2, 0.12 * a))
		# vignette
		var edge := Color(0, 0, 0, 0.5)
		var clear := Color(0, 0, 0, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.22, 0), Vector2(s.x * 0.22, s.y), Vector2(0, s.y)]), PackedColorArray([edge, clear, clear, edge]))
		draw_polygon(PackedVector2Array([Vector2(s.x * 0.78, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x * 0.78, s.y)]), PackedColorArray([clear, edge, edge, clear]))


## A dark fade from the left (and a little at the bottom) so the menu stays readable over the panorama.
class Shade extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		var dark := Color(0.02, 0.02, 0.06, 0.86)
		var clear := Color(0.02, 0.02, 0.06, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.6, 0), Vector2(s.x * 0.6, s.y), Vector2(0, s.y)]), PackedColorArray([dark, clear, clear, dark]))
		var low := Color(0.02, 0.02, 0.06, 0.7)
		draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.72), Vector2(s.x, s.y * 0.72), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([clear, clear, low, low]))


func _ready() -> void:
	UiKit.full_rect(self)
	var back := Backdrop.new()
	UiKit.full_rect(back)
	add_child(back)
	if bool(Settings.v.get("title_panorama", true)):
		add_child(MapPanorama.new())
		var shade := Shade.new()
		UiKit.full_rect(shade)
		add_child(shade)
	# ---- left column: logo and menu
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	v.offset_left = 56
	v.offset_top = 34
	v.offset_right = 500
	v.offset_bottom = -30
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	v.add_child(_logo())
	v.add_child(UiKit.label("%d classes   |   %d maps   |   no guns, only steel and spells" % [Data.class_order.size(), Data.maps.size()], 14, Color(0.85, 0.8, 0.95)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)
	v.add_child(UiKit.button("PLAY", func() -> void: play_pressed.emit(), 32, Vector2(400, 62)))
	v.add_child(UiKit.button("LAN GAME  (host or join friends)", func() -> void: net_pressed.emit(), 20, Vector2(400, 38)))
	v.add_child(UiKit.button("ARMORY  (class, skills, gear)", func() -> void: armory_pressed.emit(), 20, Vector2(400, 38)))
	v.add_child(UiKit.button("SHOP  (buy crates with gold)", func() -> void: add_child(ShopMenu.new()), 18, Vector2(400, 36)))
	v.add_child(_crates_button())
	v.add_child(UiKit.button("LEADERBOARD  (kills, deaths, K/D)", func() -> void: add_child(LeaderboardMenu.new()), 18, Vector2(400, 36)))
	v.add_child(UiKit.button("SETTINGS  (sound, picture, keys)", func() -> void: add_child(SettingsMenu.new()), 18, Vector2(400, 36)))
	v.add_child(_match_panel())
	var hint := UiKit.label("WASD move   Space jump   Shift sprint   Ctrl slide   mouse attack\nQ E R skills   F signature   X ultimate   V quest skill   G interact\nI armory   Tab hide cards   B scoreboard   Z potion", 12, Color(0.72, 0.72, 0.82))
	v.add_child(hint)
	# ---- right: the hero in the magic circle
	_preview = ModelPreview.new()
	_preview.show_hint = false
	_preview.show_off = true
	_preview.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_preview.offset_left = -690
	_preview.offset_right = -30
	_preview.offset_top = 30
	_preview.offset_bottom = -120
	add_child(_preview)
	var nav := HBoxContainer.new()
	nav.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	nav.anchor_left = 1.0
	nav.anchor_top = 1.0
	nav.offset_left = -690
	nav.offset_right = -30
	nav.offset_top = -112
	nav.offset_bottom = -34
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 14)
	add_child(nav)
	nav.add_child(UiKit.button("<", func() -> void: _step_class(-1), 22, Vector2(48, 48)))
	var names := VBoxContainer.new()
	names.custom_minimum_size = Vector2(340, 0)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 0)
	_class_label = UiKit.label("", 32, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_class_sub = UiKit.label("", 14, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	names.add_child(_class_label)
	names.add_child(_class_sub)
	nav.add_child(names)
	nav.add_child(UiKit.button(">", func() -> void: _step_class(1), 22, Vector2(48, 48)))
	_refresh()


## The title: a gold crest with two crossed swords and the name in big serif letters.
func _logo() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(420, 150)
	c.draw.connect(func() -> void:
		var f := UiKit.serif()
		var gold := Color(1.0, 0.84, 0.4)
		# crossed swords behind the title
		var mid := Vector2(210, 4)
		for sgn in [-1.0, 1.0]:
			var tip: Vector2 = mid + Vector2(sgn * 120.0, -2.0)
			var hilt: Vector2 = mid + Vector2(-sgn * 90.0, 36.0)
			c.draw_line(hilt, tip, Color(0.04, 0.04, 0.08), 9.0, true)
			c.draw_line(hilt, tip, Color(0.75, 0.8, 0.9), 5.0, true)
			c.draw_line(hilt, tip, Color(1, 1, 1, 0.7), 1.5, true)
			var d: Vector2 = (tip - hilt).normalized()
			var gp: Vector2 = hilt + d * 22.0
			var nrm := Vector2(-d.y, d.x)
			c.draw_line(gp - nrm * 12.0, gp + nrm * 12.0, gold, 5.0, true)
		c.draw_circle(mid + Vector2(0, 20), 17.0, Color(0.05, 0.05, 0.1))
		c.draw_arc(mid + Vector2(0, 20), 17.0, 0.0, TAU, 32, gold, 3.0, true)
		var diamond := PackedVector2Array([mid + Vector2(0, 8), mid + Vector2(10, 20), mid + Vector2(0, 32), mid + Vector2(-10, 20)])
		c.draw_colored_polygon(diamond, gold)
		var t1 := "FANTASY"
		var t2 := "TEAM SHOOTER"
		var w1 := f.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
		var w2 := f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		for off in [Vector2(3, 4), Vector2(-1, 2), Vector2(2, 0)]:
			c.draw_string(f, Vector2(210 - w1 * 0.5, 100) + off, t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(0, 0, 0, 0.8))
			c.draw_string(f, Vector2(210 - w2 * 0.5, 140) + off, t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0, 0, 0, 0.8))
		c.draw_string(f, Vector2(210 - w1 * 0.5, 100), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(1.0, 0.93, 0.62))
		c.draw_string(f, Vector2(210 - w2 * 0.5, 140), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, gold))
	return c


func _match_panel() -> Control:
	var p := UiKit.panel(Color(0.06, 0.06, 0.11, 0.9), UiKit.GOLD_DARK, 8)
	p.custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UiKit.label("MATCH", 18, UiKit.GOLD))
	v.add_child(UiKit.label("The map is voted in the lobby from four random maps.", 13, UiKit.DIM))
	_mode_btn = UiKit.button("", func() -> void:
		var order := ["domination", "tdm", "ctf"]
		Game.game_mode = order[(order.find(Game.game_mode) + 1) % order.size()]
		_refresh(), 16, Vector2(380, 36))
	v.add_child(_mode_btn)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	v.add_child(brow)
	brow.add_child(UiKit.button("-", func() -> void:
		Game.bots_per_team = maxi(1, Game.bots_per_team - 1)
		_refresh(), 18, Vector2(40, 34)))
	_bots_label = UiKit.label("", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_bots_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bots_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brow.add_child(_bots_label)
	brow.add_child(UiKit.button("+", func() -> void:
		Game.bots_per_team = mini(11, Game.bots_per_team + 1)
		_refresh(), 18, Vector2(40, 34)))
	return p


func _step_class(d: int) -> void:
	var i: int = Data.class_order.find(Game.selected_class)
	Game.selected_class = Data.class_order[(i + d + Data.class_order.size()) % Data.class_order.size()]
	Game.save_profile()
	_refresh()


func _refresh() -> void:
	_mode_btn.text = {"domination": "Mode: Domination (hold points)", "tdm": "Mode: Team Deathmatch", "ctf": "Mode: Capture the Flag (3 captures)"}.get(Game.game_mode, "Mode: Domination (hold points)")
	_bots_label.text = "Team size: you + %d allies vs %d foes" % [Game.bots_per_team, Game.bots_per_team + 1]
	if _preview != null:
		_preview.show_class(Game.selected_class, String(Game.equipped_item("weapon").get("id", "")))
		var cd: Dictionary = Data.classes[Game.selected_class]
		_class_label.text = String(cd["name"]).to_upper()
		_class_label.add_theme_color_override("font_color", Data.color_of(cd["color"]).lerp(Color(1, 0.9, 0.6), 0.35))
		_class_sub.text = "%s   |   home: %s   |   class level %d (%s)" % [("Magic" if cd["magic"] else "Non-magic"), String(cd["home_map"]).replace("_", " ").capitalize(), Game.class_level(Game.selected_class), Game.class_bonus_text(Game.selected_class)]


func debug_dump() -> void:
	print("MENU self ", get_global_rect(), " preview ", _preview.get_global_rect(), " vp ", _preview.vp.size, " model ", _preview.model, " label ", _class_label.text)


func refresh_class() -> void:
	_refresh()


## The CRATES button shows how many crates wait to be opened.
func _crates_button() -> Button:
	var b := UiKit.button("", func() -> void: pass, 18, Vector2(400, 36))
	var set_text := func() -> void:
		b.text = "CRATES  (%d to open)" % Game.crate_count()
	set_text.call()
	b.pressed.connect(func() -> void:
		var m := CratesMenu.new()
		m.closed.connect(func() -> void: set_text.call())
		add_child(m))
	return b
