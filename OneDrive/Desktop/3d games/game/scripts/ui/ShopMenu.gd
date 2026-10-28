class_name ShopMenu
extends Control
## The shop: spend gold (earned in matches) on crates. Every kind of crate comes in the six rarities, as a single crate or in bundles that cost less per crate:
## x3 (10% off), x5 (15% off), x10 (25% off). Loot crates hold anything; weapon crates hold a weapon (brand new with a skin and a modifier, or old and worn);
## specific crates (bow, sword, axe, staff...) hold only that kind of weapon; armor and rune crates hold only those. What you buy goes to the CRATES menu to open.

signal closed()

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]

var _kind := "any"
var _gold_label: Label
var _kinds_box: VBoxContainer
var _rows: VBoxContainer
var _note: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.88)
	UiKit.full_rect(dim)
	add_child(dim)
	var panel := UiKit.panel(Color(0.06, 0.07, 0.12, 0.98), UiKit.GOLD_DARK, 10)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -330
	panel.offset_bottom = 330
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(UiKit.label("SHOP", 34, UiKit.GOLD))
	_gold_label = UiKit.label("", 26, Color(1.0, 0.88, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_gold_label)
	v.add_child(UiKit.label("Buy crates with gold. Buy more at once and each crate costs less. Open what you bought in CRATES.", 14, UiKit.DIM))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(left)
	_kinds_box = VBoxContainer.new()
	_kinds_box.add_theme_constant_override("separation", 4)
	_kinds_box.custom_minimum_size = Vector2(290, 0)
	left.add_child(_kinds_box)
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	right.add_child(_rows)
	_note = UiKit.label("", 16, Color(1.0, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_note)
	var foot := HBoxContainer.new()
	v.add_child(foot)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	foot.add_child(UiKit.button("Done", func() -> void:
		closed.emit()
		queue_free(), 22, Vector2(200, 44)))
	_build()


func _build() -> void:
	_gold_label.text = "%d gold" % Game.gold
	for c in _kinds_box.get_children():
		c.queue_free()
	for c in _rows.get_children():
		c.queue_free()
	for kind in Game.CRATE_KINDS:
		var k: String = kind
		var nm: String = {"any": "Loot crate", "weapon_new": "New weapon crate", "weapon_old": "Old weapon crate"}.get(k, String(Game.CRATE_KINDS[k]))
		var b := UiKit.tab_button(nm, k == _kind, func() -> void:
			_kind = k
			_note.text = ""
			_build(), 16, Vector2(280, 34))
		_kinds_box.add_child(b)
	_rows.add_child(UiKit.label(String(Game.CRATE_KINDS[_kind]).to_upper(), 18, UiKit.GOLD))
	for r in RARITIES:
		_rows.add_child(_rarity_row(r))


func _rarity_row(rarity: String) -> Control:
	var col := Data.rarity_color(rarity)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title := UiKit.label("%s   (you have %d)" % [String(Data.rarity(rarity)["name"]), int(Game.crates.get(Game.crate_key(_kind, rarity), 0))], 18, col.lerp(Color.WHITE, 0.3))
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for i in Game.BUNDLES.size():
		var idx := i
		var cost := Game.bundle_price(_kind, rarity, i)
		var full := Game.crate_price(_kind, rarity) * int(Game.BUNDLES[i][0])
		var label := "%s\n%d gold" % [String(Game.BUNDLES[i][2]), cost]
		if cost < full:
			label += "  (save %d)" % (full - cost)
		var btn := UiKit.button(label, func() -> void:
			if Game.buy_crates(_kind, rarity, idx):
				_note.text = "Bought %d %s crate%s." % [int(Game.BUNDLES[idx][0]), String(Data.rarity(rarity)["name"]).to_lower(), "" if int(Game.BUNDLES[idx][0]) == 1 else "s"]
				Sfx.play("coin")
			else:
				_note.text = "Not enough gold."
			_build(), 14, Vector2(150, 50))
		btn.disabled = Game.gold < cost
		row.add_child(btn)
	return box
