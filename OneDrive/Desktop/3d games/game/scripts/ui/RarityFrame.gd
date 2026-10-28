class_name RarityFrame
extends Control
## A card or item panel drawn like a trading card: title banner, a framed picture (IconArt glyph on a coloured window), a rarity ribbon and a text box.
## The rarity is shown three ways at once (design rule: never colour alone): colour, a frame shape with its own corner ornaments and icon
## (square, leaf, diamond, hexagon, star, crown) and the rarity name written out. Higher rarity = more glow, sparkle and motion.
## Layouts: tall (cards), wide (crate result, picture on the left) and compact (inventory slots: picture thumbnail + name). Without a `glyph` it is a plain text panel.

var rarity := "common"
var title := ""
var subtitle := ""
var body := ""
var footer := ""
var badge := ""                          # small pill on the picture (for example "Stack 2/6")
var hotkey := ""
var magic_icon := false                  # the spark icon marks magic gear
var selected := false
var compact := false                     # thumbnail layout for inventory slots
var glyph := ""                          # IconArt glyph shown in the picture window
var category := "utility"                # offense / defense / mobility / skill / meter / economy / class / utility: the window's colours
var art_pal := ""                        # optional palette override for the glyph
var icon_tex: Texture2D                    # a rendered picture of the real weapon model (WeaponIcons) shown instead of the glyph
var weapon_id := ""
var _t := 0.0
var _hover := false
var _sb := StyleBoxFlat.new()

const SHAPES := {"common": "square", "uncommon": "leaf", "rare": "diamond", "epic": "hexagon", "legendary": "star", "mythic": "crown"}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func set_data(r: String, t: String, sub: String = "", b: String = "", foot: String = "") -> void:
	rarity = r
	title = t
	subtitle = sub
	body = b
	footer = foot
	queue_redraw()


func set_art(g: String, cat: String, pal: String = "") -> void:
	icon_tex = null
	weapon_id = ""
	glyph = g
	category = cat
	art_pal = pal
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var big := not compact and glyph != ""
	if Data.rarity_index(rarity) >= 3 or selected or _hover or big:
		queue_redraw()


func _mode() -> String:
	if glyph == "":
		return "text"
	if compact:
		return "compact"
	return "wide" if size.x > size.y * 1.15 else "tall"


func _draw() -> void:
	var col := Data.rarity_color(rarity)
	var glow: float = float(Data.rarity(rarity)["glow"])
	var s := size
	var pulse := 0.5 + 0.5 * sin(_t * (2.0 + 2.0 * glow))
	var mode := _mode()
	var small := mode == "compact" or mode == "text" and compact
	# glow behind the frame
	if glow > 0.05:
		var rings := 2 if small else 4
		for i in rings:
			var g := (rings - i) * (1.5 if small else 3.0)
			draw_rect(Rect2(Vector2(-g, -g), s + Vector2(g, g) * 2.0), Color(col.r, col.g, col.b, (0.05 + 0.08 * glow * pulse) * (1.0 - i * 0.2)), false, 2.0 if small else 3.0)
	var bg := Color(0.07, 0.07, 0.1, 0.96)
	if rarity == "mythic":
		bg = Color(0.1 + 0.05 * pulse, 0.03, 0.05, 0.96)
	draw_rect(Rect2(Vector2.ZERO, s), bg, true)
	var thick := 2.0 + 1.0 * glow * 2.0 + (2.0 if (selected or _hover) else 0.0)
	draw_rect(Rect2(Vector2(thick * 0.5, thick * 0.5), s - Vector2(thick, thick)), col, false, thick)
	_corners(SHAPES[rarity], col, s, small)
	match mode:
		"text":
			_draw_text_card(col, s)
		"compact":
			_draw_compact(col, s)
		"tall":
			_draw_tall(col, s)
		"wide":
			_draw_wide(col, s)
	if rarity == "mythic":
		for i in 6:
			var p := fposmod(_t * 0.25 + i / 6.0, 1.0)
			draw_circle(Vector2(p * s.x, 0.0 if i % 2 == 0 else s.y), 2.5 + 1.5 * pulse, Color(1, 0.5, 0.5, 0.8))


# ---------------------------------------------------------------- layouts

func _draw_tall(col: Color, s: Vector2) -> void:
	var pad := 10.0
	var banner := Rect2(pad, pad, s.x - pad * 2.0, 34.0)
	var art := Rect2(pad + 2.0, banner.end.y + 6.0, s.x - (pad + 2.0) * 2.0, roundf(s.y * 0.41))
	var ribbon := Rect2(art.position.x, art.end.y + 4.0, art.size.x, 20.0)
	var box := Rect2(art.position.x, ribbon.end.y + 4.0, art.size.x, s.y - ribbon.end.y - 4.0 - pad)
	_banner(banner, col, 20)
	_art(art, col)
	_ribbon(ribbon, col)
	_text_box(box, 15)


func _draw_wide(col: Color, s: Vector2) -> void:
	var pad := 10.0
	var art := Rect2(pad, pad, minf(172.0, s.x * 0.4), s.y - pad * 2.0)
	var x0 := art.end.x + 10.0
	var banner := Rect2(x0, pad, s.x - x0 - pad, 34.0)
	var ribbon := Rect2(x0, banner.end.y + 6.0, banner.size.x, 20.0)
	var box := Rect2(x0, ribbon.end.y + 4.0, banner.size.x, s.y - ribbon.end.y - 4.0 - pad)
	_banner(banner, col, 20)
	_art(art, col)
	_ribbon(ribbon, col)
	_text_box(box, 15)


func _draw_compact(col: Color, s: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var th := minf(s.y - 12.0, 72.0)
	var art := Rect2(6.0, (s.y - th) * 0.5, th, th)
	IconArt.draw_card_art(self, art, glyph, category, col, _t if (_hover or selected) else 0.0, Data.rarity_index(rarity), absi(title.hash()) % 1000, art_pal, icon_tex)
	var x0 := art.end.x + 6.0
	var w := s.x - x0 - 6.0
	var y := 18.0
	var lines := _wrap(font, title, w, 13)
	var shown := mini(lines.size(), 2)
	for i in shown:
		draw_string(font, Vector2(x0, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, w, 13, Color.WHITE)
		y += 16.0
	if subtitle != "":
		draw_string(font, Vector2(x0, y), subtitle, HORIZONTAL_ALIGNMENT_LEFT, w, 11, Color(0.75, 0.75, 0.85))
	# rarity shape + name at the bottom
	var rname: String = String(Data.rarity(rarity)["name"])
	_shape_icon(Vector2(x0 + 6.0, s.y - 11.0), 5.5, SHAPES[rarity], col)
	draw_string(font, Vector2(x0 + 16.0, s.y - 7.0), rname, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 11, col)
	if magic_icon:
		_spark(Vector2(s.x - 12.0, 12.0), 5.0, Color(0.7, 0.8, 1.0))


## A plain text panel (no picture): rarity strip, title, subtitle, body, footer.
func _draw_text_card(col: Color, s: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var fs := 13 if compact else 16
	_shape_icon(Vector2(16, 16), 9.0 if not compact else 7.0, SHAPES[rarity], col)
	var rname: String = String(Data.rarity(rarity)["name"]).to_upper()
	draw_string(font, Vector2(30, 21 if not compact else 19), rname, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if magic_icon:
		_spark(Vector2(s.x - 14, 16), 7.0, Color(0.7, 0.8, 1.0))
	if badge != "":
		var bw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(s.x - bw - (30 if magic_icon else 10), 21 if not compact else 19), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
	var y := 52.0 if not compact else 40.0
	if title != "":
		var tfs := 22 if not compact else 15
		for ln in _wrap(font, title, s.x - 24, tfs):
			draw_string(font, Vector2(12, y), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color.WHITE)
			y += tfs * 1.4
	if subtitle != "":
		draw_string(font, Vector2(12, y), subtitle, HORIZONTAL_ALIGNMENT_LEFT, s.x - 24, 13 if not compact else 11, Color(0.75, 0.75, 0.85))
		y += 20.0
	if body != "":
		var bfs := 16 if not compact else 12
		y += 6.0
		for ln in _wrap(font, body, s.x - 24, bfs):
			draw_string(font, Vector2(12, y), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(0.92, 0.92, 0.96))
			y += bfs * 1.4
	if footer != "":
		draw_string(font, Vector2(12, s.y - 12), footer, HORIZONTAL_ALIGNMENT_LEFT, s.x - 24, 13, Color(0.8, 0.8, 0.9, 0.9))
	if hotkey != "":
		draw_string(font, Vector2(s.x - 26, s.y - 10), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.55))


# ---------------------------------------------------------------- pieces

func _rbox(r: Rect2, fill: Color, border: Color, radius: int = 5, bw: int = 1) -> void:
	_sb.bg_color = fill
	_sb.border_color = border
	_sb.set_border_width_all(bw)
	_sb.set_corner_radius_all(radius)
	draw_style_box(_sb, r)


## The title banner: a ribbon with notched ends, in the card's category colour, outlined in the rarity colour.
func _banner(r: Rect2, col: Color, max_fs: int) -> void:
	var font := ThemeDB.fallback_font
	var cc: Array = IconArt.category_colors(category)
	var fill: Color = (cc[0] as Color).lerp(col, 0.18).darkened(0.1)
	var n := 10.0
	var pts := PackedVector2Array([r.position + Vector2(n, 0), Vector2(r.end.x - n, r.position.y), Vector2(r.end.x, r.get_center().y), Vector2(r.end.x - n, r.end.y),
		Vector2(r.position.x + n, r.end.y), Vector2(r.position.x, r.get_center().y)])
	draw_colored_polygon(pts, fill)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(Color(1, 1, 1, 0.16 * (1.0 - (p.y - r.position.y) / r.size.y)))
	draw_polygon(pts, cols)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(0, 0, 0, 0.8), 4.0, true)
	draw_polyline(closed, col, 2.0, true)
	_shape_icon(Vector2(r.position.x + 2.0, r.get_center().y), 4.0, "diamond", col)
	_shape_icon(Vector2(r.end.x - 2.0, r.get_center().y), 4.0, "diamond", col)
	var fs := max_fs
	var avail := r.size.x - 30.0
	while fs > 11 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 1
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := Vector2(r.get_center().x - tw * 0.5, r.get_center().y + fs * 0.34)
	draw_string(font, tp + Vector2(1, 1.5), title, HORIZONTAL_ALIGNMENT_LEFT, avail, fs, Color(0, 0, 0, 0.8))
	draw_string(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, avail, fs, Color.WHITE)


func _art(r: Rect2, col: Color) -> void:
	IconArt.draw_card_art(self, r, glyph, category, col, _t, Data.rarity_index(rarity), absi(title.hash()) % 1000, art_pal, icon_tex)
	var font := ThemeDB.fallback_font
	if hotkey != "":
		var k := Rect2(r.position + Vector2(6, 6), Vector2(24, 24))
		_rbox(k, Color(0.05, 0.05, 0.09, 0.92), Color(1, 1, 1, 0.7), 6, 2)
		var kw := font.get_string_size(hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(font, k.position + Vector2((24.0 - kw) * 0.5, 18.0), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	if badge != "":
		var bw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0
		var b := Rect2(Vector2(r.end.x - bw - 6.0, r.position.y + 6.0), Vector2(bw, 20.0))
		_rbox(b, Color(0.05, 0.05, 0.09, 0.9), col, 10, 1)
		draw_string(font, b.position + Vector2(7.0, 15.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if magic_icon:
		_spark(Vector2(r.end.x - 14.0, r.end.y - 14.0), 7.0, Color(0.7, 0.85, 1.0))


## The strip under the picture: rarity shape + written rarity name on the left, the category (or subtitle) on the right.
func _ribbon(r: Rect2, col: Color) -> void:
	var font := ThemeDB.fallback_font
	_rbox(r, Color(col.r, col.g, col.b, 0.16), Color(col.r, col.g, col.b, 0.55), 4, 1)
	_shape_icon(r.position + Vector2(13.0, 10.0), 6.5, SHAPES[rarity], col)
	var rname: String = String(Data.rarity(rarity)["name"]).to_upper()
	draw_string(font, r.position + Vector2(26.0, 15.0), rname, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	if subtitle != "":
		var sw := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, r.position + Vector2(r.size.x - sw - 8.0, 15.0), subtitle, HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.5, 12, Color(0.85, 0.85, 0.95, 0.9))


## The description box: the text shrinks until it fits.
func _text_box(r: Rect2, max_fs: int) -> void:
	var font := ThemeDB.fallback_font
	_rbox(r, Color(0.0, 0.0, 0.0, 0.38), Color(1, 1, 1, 0.14), 4, 1)
	var foot_h := 16.0 if footer != "" else 0.0
	var inner := Rect2(r.position + Vector2(7, 5), r.size - Vector2(14, 10.0 + foot_h))
	var fs := max_fs
	var lines := _wrap(font, body, inner.size.x, fs)
	while fs > 10 and float(lines.size()) * fs * 1.32 > inner.size.y:
		fs -= 1
		lines = _wrap(font, body, inner.size.x, fs)
	var y := inner.position.y + fs
	for ln in lines:
		draw_string(font, Vector2(inner.position.x, y), ln, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, fs, Color(0.93, 0.93, 0.97))
		y += fs * 1.32
	if footer != "":
		draw_string(font, Vector2(inner.position.x, r.end.y - 6.0), footer, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, 12, Color(0.78, 0.8, 0.92, 0.9))


## Greedy word wrap (paragraphs split on newlines) into lines no wider than `width`.
func _wrap(font: Font, text: String, width: float, fs: int) -> PackedStringArray:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for w in para.split(" "):
			var test := (line + " " + w).strip_edges()
			if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and line != "":
				out.append(line)
				line = w
			else:
				line = test
		out.append(line)
	return out


func _corners(shape: String, col: Color, s: Vector2, small: bool) -> void:
	var k := 14.0
	var sc := 0.55 if small else 1.0
	match shape:
		"square":
			pass
		"leaf":
			for c in [Vector2(0, 0), Vector2(s.x, 0), Vector2(0, s.y), Vector2(s.x, s.y)]:
				draw_circle(c, 4.0 * sc, col)
		"diamond":
			for c in [Vector2(0, 0), Vector2(s.x, 0), Vector2(0, s.y), Vector2(s.x, s.y)]:
				_shape_icon(c, 7.0 * sc, "diamond", col)
		"hexagon":
			for c in [Vector2(0, 0), Vector2(s.x, 0), Vector2(0, s.y), Vector2(s.x, s.y)]:
				_shape_icon(c, 8.0 * sc, "hexagon", col)
			draw_line(Vector2(k, 3), Vector2(s.x - k, 3), Color(col.r, col.g, col.b, 0.5), 1.0)
		"star":
			for c in [Vector2(0, 0), Vector2(s.x, 0), Vector2(0, s.y), Vector2(s.x, s.y)]:
				_shape_icon(c, 10.0 * sc, "star", col)
		"crown":
			for c in [Vector2(0, 0), Vector2(s.x, 0), Vector2(0, s.y), Vector2(s.x, s.y)]:
				_shape_icon(c, 11.0 * sc, "crown", col)
			if not small:
				_shape_icon(Vector2(s.x * 0.5, 0), 11.0, "crown", col)


## Draws the rarity's shape icon (same shapes as the frame corners).
func _shape_icon(c: Vector2, r: float, shape: String, col: Color) -> void:
	var pts := PackedVector2Array()
	match shape:
		"square":
			draw_rect(Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), col, true)
			return
		"leaf":
			draw_circle(c, r * 0.8, col)
			draw_line(c + Vector2(0, r), c + Vector2(0, -r), Color(0.1, 0.2, 0.1), 1.5)
			return
		"diamond":
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		"hexagon":
			for i in 6:
				var a := TAU * i / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
		"star":
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0
				var rr := r if i % 2 == 0 else r * 0.45
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
		"crown":
			pts = PackedVector2Array([c + Vector2(-r, r * 0.7), c + Vector2(-r, -r * 0.4), c + Vector2(-r * 0.45, r * 0.1), c + Vector2(0, -r), c + Vector2(r * 0.45, r * 0.1),
				c + Vector2(r, -r * 0.4), c + Vector2(r, r * 0.7)])
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)


func _spark(c: Vector2, r: float, col: Color) -> void:
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, 2.0)
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, 2.0)
	draw_line(c + Vector2(-r * 0.6, -r * 0.6), c + Vector2(r * 0.6, r * 0.6), col, 1.0)
	draw_line(c + Vector2(r * 0.6, -r * 0.6), c + Vector2(-r * 0.6, r * 0.6), col, 1.0)


## Shows the real model of weapon `w` in the picture window (rendered once, then kept); the glyph is shown until it is ready.
func set_weapon(w: Dictionary) -> void:
	weapon_id = String(w["id"])
	icon_tex = WeaponIcons.texture_for(w)
	if icon_tex == null and WeaponIcons.inst != null and not WeaponIcons.inst.icon_ready.is_connected(_on_icon_ready):
		WeaponIcons.inst.icon_ready.connect(_on_icon_ready)


func _on_icon_ready(id: String) -> void:
	if id == weapon_id:
		icon_tex = WeaponIcons._cache.get(id)
		queue_redraw()
