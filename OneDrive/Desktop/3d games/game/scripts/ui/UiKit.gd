class_name UiKit
extends RefCounted
## Small helpers for building the UI in code. One fantasy look for all of it: a serif face for headings, dark blue-stone panels with gold trim and
## ornate corners, stone buttons with a gold edge.

const BG := Color(0.05, 0.05, 0.08, 0.92)
const PANEL := Color(0.07, 0.08, 0.13, 0.96)
const TEXT := Color(0.95, 0.93, 0.88)
const DIM := Color(0.72, 0.72, 0.8)
const GOLD := Color(1.0, 0.85, 0.4)
const GOLD_DARK := Color(0.62, 0.46, 0.18)

static var _serif: Font


## The heading face (a serif that every Windows machine has; the default face is used when none is found).
static func serif() -> Font:
	if _serif == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Constantia", "Georgia", "Cambria", "Times New Roman"])
		f.font_weight = 700
		f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		_serif = f
	return _serif


static func label(text: String, size: int = 16, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4 if size >= 14 else 2)
	if size >= 17:
		l.add_theme_font_override("font", serif())
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel(color: Color = PANEL, border: Color = GOLD_DARK, radius: int = 8) -> PanelContainer:
	var p := FantasyPanel.new()
	p.fill = color
	p.border = border
	p.radius = radius
	return p


static func button(text: String, cb: Callable, size: int = 18, min_size: Vector2 = Vector2(150, 44)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", serif())
	b.add_theme_color_override("font_color", Color(0.96, 0.92, 0.8))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	b.pressed.connect(cb)
	b.pressed.connect(func() -> void: Sfx.play("click"))
	b.mouse_entered.connect(func() -> void: Sfx.play("hover"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.21)
	sb.border_color = GOLD_DARK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 3
	sb.set_content_margin_all(6)
	var hv := sb.duplicate()
	hv.bg_color = Color(0.2, 0.2, 0.32)
	hv.border_color = GOLD
	var ps := sb.duplicate()
	ps.bg_color = Color(0.3, 0.27, 0.2)
	ps.border_color = Color(1.0, 0.95, 0.6)
	var ds := sb.duplicate()
	ds.bg_color = Color(0.09, 0.09, 0.12)
	ds.border_color = Color(0.3, 0.28, 0.25)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", ps)
	b.add_theme_stylebox_override("disabled", ds)
	return b


## A flat-looking tab/filter button that shows whether it is the active one.
static func tab_button(text: String, active: bool, cb: Callable, size: int = 15, min_size: Vector2 = Vector2(74, 32)) -> Button:
	var b := button(text, cb, size, min_size)
	if active:
		var sb := (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
		sb.bg_color = Color(0.36, 0.28, 0.1)
		sb.border_color = GOLD
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	return b


## A dark blue-stone panel with a gold edge, a soft top light and ornamental corners.
class FantasyPanel extends PanelContainer:
	var fill := Color(0.07, 0.08, 0.13, 0.96)
	var border := Color(0.62, 0.46, 0.18)
	var radius := 8
	var _sb := StyleBoxFlat.new()

	func _init() -> void:
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin_all(14)
		add_theme_stylebox_override("panel", empty)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		_sb.bg_color = fill
		_sb.border_color = border
		_sb.set_border_width_all(2)
		_sb.set_corner_radius_all(radius)
		_sb.shadow_color = Color(0, 0, 0, 0.45)
		_sb.shadow_size = 6
		draw_style_box(_sb, r)
		# a soft light from the top
		var top := PackedVector2Array([Vector2(3, 3), Vector2(size.x - 3, 3), Vector2(size.x - 3, size.y * 0.35), Vector2(3, size.y * 0.35)])
		draw_polygon(top, PackedColorArray([Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
		draw_rect(r.grow(-6), Color(border.r, border.g, border.b, 0.35), false, 1.0)
		# ornamental corners: a gold diamond with two short rules
		var gold := Color(1.0, 0.85, 0.4, 0.9)
		for c in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
			var sx: float = 1.0 if c.x == 0.0 else -1.0
			var sy: float = 1.0 if c.y == 0.0 else -1.0
			var o: Vector2 = c + Vector2(sx * 6.0, sy * 6.0)
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, -5), o + Vector2(5, 0), o + Vector2(0, 5), o + Vector2(-5, 0)]), gold)
			draw_line(o + Vector2(sx * 8.0, 0), o + Vector2(sx * 22.0, 0), gold, 1.5)
			draw_line(o + Vector2(0, sy * 8.0), o + Vector2(0, sy * 22.0), gold, 1.5)


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## A flat horizontal bar: back, fill, optional text drawn by the caller.
class Bar extends Control:
	var value := 1.0
	var color := Color(0.9, 0.2, 0.2)
	var back := Color(0, 0, 0, 0.6)
	var text := ""
	var show_text := true
	var shield := 0.0

	func _draw() -> void:
		var f := clampf(value, 0.0, 1.0)
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.03, 0.03, 0.06, 0.82), true)
		if f > 0.0:
			var w := size.x * f
			var top := color.lightened(0.28)
			var bot := color.darkened(0.3)
			draw_polygon(PackedVector2Array([Vector2(1, 1), Vector2(w, 1), Vector2(w, size.y - 1), Vector2(1, size.y - 1)]), PackedColorArray([top, top, bot, bot]))
			draw_rect(Rect2(1, 1, maxf(w - 1, 0.0), size.y * 0.32), Color(1, 1, 1, 0.16), true)
		if shield > 0.0:
			draw_rect(Rect2(Vector2(size.x * f, 1), Vector2(size.x * clampf(shield, 0.0, 1.0 - f), size.y - 2)), Color(0.55, 0.85, 1.0, 0.85), true)
		# little tick marks every quarter, then a dark outer line and a gold inner line
		for i in range(1, 4):
			draw_line(Vector2(size.x * i / 4.0, 2), Vector2(size.x * i / 4.0, size.y - 2), Color(0, 0, 0, 0.3), 1.0)
		draw_rect(r, Color(0, 0, 0, 0.9), false, 2.5)
		draw_rect(r.grow(-1.0), Color(UiKit.GOLD_DARK.r, UiKit.GOLD_DARK.g, UiKit.GOLD_DARK.b, 0.9), false, 1.2)
		if show_text and text != "":
			var fnt := ThemeDB.fallback_font
			var fs := int(size.y * 0.75)
			var tw := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var p := Vector2((size.x - tw) * 0.5, size.y * 0.8)
			draw_string(fnt, p + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
			draw_string(fnt, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	func set_value(v: float, t: String = "") -> void:
		if v != value or t != text:
			value = v
			text = t
			queue_redraw()


## A skill button: the skill's own picture, frame and colours (SkillArt), a cooldown sweep and a hotkey. Without a `skill` it is a plain tinted gem.
class SkillSlot extends Control:
	var skill: Dictionary = {}                 # a skill from Data.skills; drawn by SkillArt
	var quest: Dictionary = {}                 # a quest skill; the picture is chosen from its name
	var icon_color := Color.WHITE
	var letter := ""
	var name_text := ""
	var cooldown := 0.0
	var cooldown_total := 1.0
	var ready_glow := false
	var frame_color := Color(0.6, 0.6, 0.7)
	var special := false                 # the signature skill has its own frame
	var ult := false
	var charge := -1.0                   # ultimate charge 0..1 (<0 = not an ultimate)
	var disabled := false
	var show_name := true
	var animated := false
	var _t := 0.0

	func set_skill(sk: Dictionary) -> void:
		if sk.get("id", "") != skill.get("id", "-"):
			skill = sk
			queue_redraw()

	func set_quest(q: Dictionary) -> void:
		if q.get("id", "") != quest.get("id", "-"):
			quest = q
			queue_redraw()

	func _process(delta: float) -> void:
		if animated or ready_glow:
			_t += delta
		if animated:
			queue_redraw()

	func _draw() -> void:
		var spec: Dictionary
		if not skill.is_empty():
			spec = SkillArt.spec_for_skill(skill)
		elif not quest.is_empty():
			spec = SkillArt.spec_for_quest(quest)
		else:
			spec = SkillArt.spec_for_quest({"id": "empty", "name": "", "rarity": "common"})
			spec = spec.duplicate()
			spec["glyph"] = "hex"
			spec["colors"] = IconArt.palette_for("hex", Color(0.3, 0.3, 0.4))
			spec["color"] = Color(0.3, 0.3, 0.4)
		SkillArt.draw_button(self, Rect2(Vector2.ZERO, size), spec, {
			"cooldown": cooldown, "cooldown_total": cooldown_total, "charge": charge, "ready": ready_glow, "special": special, "ult": ult,
			"disabled": disabled, "letter": letter, "t": _t, "show_name": show_name and (not skill.is_empty() or not quest.is_empty())})
