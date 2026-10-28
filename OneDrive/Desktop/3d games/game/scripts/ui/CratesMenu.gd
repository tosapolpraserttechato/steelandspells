class_name CratesMenu
extends Control
## The place to open the crates you own: loot crates (anything can be inside) and weapon crates, brand new (a skin and a modifier) or old and worn (a small flaw),
## each in the six rarities. Crates come from finished matches (see Game.award_match_crates). Opening one shows the same reveal as a crate on the map (CrateOpen.gd).

signal closed()

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]

var _list: VBoxContainer
var _total: Label
var _note: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.86)
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
	head.add_child(UiKit.label("CRATES", 34, UiKit.GOLD))
	_total = UiKit.label("", 18, UiKit.DIM)
	_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_total)
	v.add_child(UiKit.label("Matches give you crates. Weapon crates hold a weapon: a BRAND NEW one comes with a skin and a modifier, an OLD one has a small flaw.", 14, UiKit.DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_note = UiKit.label("", 15, Color(1.0, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
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
	for c in _list.get_children():
		c.queue_free()
	_total.text = "%d crate%s unopened" % [Game.crate_count(), "" if Game.crate_count() == 1 else "s"]
	var any := false
	for kind in Game.CRATE_KINDS:
		var header_done := false
		# rarest first
		for i in range(RARITIES.size() - 1, -1, -1):
			var key := Game.crate_key(kind, RARITIES[i])
			var n := int(Game.crates.get(key, 0))
			if n <= 0:
				continue
			if not header_done:
				header_done = true
				_list.add_child(UiKit.label(String(Game.CRATE_KINDS[kind]).to_upper(), 16, UiKit.GOLD))
			any = true
			_list.add_child(_row(key, kind, RARITIES[i], n))
	if not any:
		_list.add_child(UiKit.label("No crates yet. Finish a match to earn some.", 20, UiKit.DIM))


func _row(key: String, kind: String, rarity: String, n: int) -> Control:
	var col := Data.rarity_color(rarity)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 14)
	var box := Control.new()
	box.custom_minimum_size = Vector2(46, 40)
	box.draw.connect(func() -> void:
		box.draw_rect(Rect2(4, 8, 38, 28), col.darkened(0.45), true)
		box.draw_rect(Rect2(4, 8, 38, 28), col, false, 2.0)
		box.draw_rect(Rect2(4, 18, 38, 6), col, true)
		box.draw_rect(Rect2(19, 8, 8, 28), col.lightened(0.2), true))
	r.add_child(box)
	var kind_name: String = {"any": "Loot crate", "weapon_new": "New weapon crate", "weapon_old": "Old weapon crate"}.get(kind, String(Game.CRATE_KINDS.get(kind, kind)))
	var name_label := UiKit.label("%s  %s" % [String(Data.rarity(rarity)["name"]), kind_name], 20, col.lerp(Color.WHITE, 0.3))
	name_label.custom_minimum_size = Vector2(380, 0)
	r.add_child(name_label)
	r.add_child(UiKit.label("x %d" % n, 20, UiKit.TEXT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(sp)
	r.add_child(UiKit.button("Open", func() -> void: _open(key), 18, Vector2(130, 38)))
	return r


func _open(key: String) -> void:
	var roll := Game.take_crate(key)
	if roll.is_empty():
		return
	Sfx.play("chest")
	var c := CrateOpen.new()
	add_child(c)
	c.open_with(roll, null)
	c.closed.connect(func(_r: Dictionary) -> void:
		_note.text = ""
		_build())
