class_name WeaponWheel
extends Control
## The weapon wheel: hold H in a match and a ring of 2D weapon sprites (the weapons in your bag) opens around the middle of the screen; move the mouse toward one and let go
## of H to take it in hand. The sprites are the same pictures the armory uses (WeaponIcons).

var items: Array = []
var _sel := -1
const RADIUS := 210.0
const SLOT := 92.0


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open() -> void:
	items.clear()
	var cur := Game.equipped_item("weapon")
	if not cur.is_empty():
		items.append(cur)
	for it in Game.inventory:
		if it["kind"] == "weapon" and (cur.is_empty() or it["uid"] != cur["uid"]) and items.size() < 10:
			items.append(it)
	_sel = 0 if not cur.is_empty() else -1
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().warp_mouse(size * 0.5)


## Closes the wheel; returns the weapon item that was picked, or {} when none.
func close() -> Dictionary:
	visible = false
	var pick: Dictionary = items[_sel] if _sel >= 0 and _sel < items.size() else {}
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return pick


func _process(_delta: float) -> void:
	if not visible:
		return
	var rel := get_viewport().get_mouse_position() - size * 0.5
	if rel.length() > 50.0 and not items.is_empty():
		var a := fposmod(atan2(rel.x, -rel.y), TAU)                    # 0 = straight up, clockwise
		_sel = int(round(a / (TAU / float(items.size())))) % items.size()
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.04, 0.55), true)
	draw_circle(c, RADIUS + 70.0, Color(0.05, 0.06, 0.12, 0.8))
	draw_arc(c, RADIUS + 70.0, 0, TAU, 64, UiKit.GOLD_DARK, 3.0, true)
	if items.is_empty():
		draw_string(UiKit.serif(), c + Vector2(-120, 0), "No weapons in the bag", HORIZONTAL_ALIGNMENT_CENTER, 240, 22, UiKit.DIM)
		return
	var n := items.size()
	for i in n:
		var a := TAU * float(i) / float(n)
		var p := c + Vector2(sin(a), -cos(a)) * RADIUS
		var it: Dictionary = items[i]
		var col := Data.rarity_color(String(it["rarity"]))
		var on := i == _sel
		draw_circle(p, SLOT * 0.5 + (8.0 if on else 0.0), col.darkened(0.6 if not on else 0.35))
		draw_arc(p, SLOT * 0.5 + (8.0 if on else 0.0), 0, TAU, 40, col, 4.0 if on else 2.0, true)
		var w: Dictionary = Data.weapons[it["id"]]
		var tex := WeaponIcons.texture_for(w)
		if tex != null:
			var s := SLOT * (1.1 if on else 0.95)
			draw_texture_rect(tex, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		if i == 0 and Game.equipped_item("weapon") == it:
			draw_string(UiKit.serif(), p + Vector2(-40, SLOT * 0.5 + 18), "in hand", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(0.7, 1.0, 0.7))
	if _sel >= 0 and _sel < n:
		var it2: Dictionary = items[_sel]
		var col2 := Data.rarity_color(String(it2["rarity"]))
		draw_string(UiKit.serif(), c + Vector2(-170, -10), Loot.item_name(it2), HORIZONTAL_ALIGNMENT_CENTER, 340, 26, col2.lerp(Color.WHITE, 0.3))
		draw_string(UiKit.serif(), c + Vector2(-170, 22), "%s  |  %s" % [String(Data.rarity(it2["rarity"])["name"]), ("Brand new: " + String(it2.get("skin", ""))) if it2.get("new", false) else "Old and worn"], HORIZONTAL_ALIGNMENT_CENTER, 340, 16, UiKit.DIM)
