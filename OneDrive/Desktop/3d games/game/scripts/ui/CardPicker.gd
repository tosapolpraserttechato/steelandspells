class_name CardPicker
extends Control
## The level-up screen: exactly 3 big cards (4 with Fate Weaver). Press 1/2/3 to pick, T to reroll, Tab to hide the cards and look at the fight
## (Tab again shows them). The match keeps running underneath, so the cards sit in the lower middle and leave the centre of the screen free.

signal picked(card_id: String)

var offer: Array = []
var shown := true
var _row: HBoxContainer
var _title: Label
var _hint: Label
var _reroll: Button
var _tab: Label                      # the small tab left when the cards are hidden
var _widgets: Array = []
var _holder: Control


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_holder)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -520
	box.offset_right = 520
	box.offset_top = -590
	box.offset_bottom = -135
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	_holder.add_child(box)
	_title = UiKit.label("LEVEL UP!  Choose a card", 28, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 22)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_row)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 18)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bottom)
	_hint = UiKit.label("Press 1 / 2 / 3 to pick     Tab: hide", 17, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	bottom.add_child(_hint)
	_reroll = UiKit.button("Reroll (T)", func() -> void: Game.reroll_offer(), 16, Vector2(130, 34))
	bottom.add_child(_reroll)
	_tab = UiKit.label("Tab: show cards  (%d waiting)", 18, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_tab.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tab.anchor_left = 0.5
	_tab.anchor_right = 0.5
	_tab.anchor_top = 1.0
	_tab.anchor_bottom = 1.0
	_tab.offset_left = -150
	_tab.offset_right = 150
	_tab.offset_top = -70
	_tab.offset_bottom = -40
	_tab.visible = false
	add_child(_tab)
	visible = false
	Game.cards_offered.connect(show_offer)
	Game.rerolls_changed.connect(func(_n: int) -> void: _refresh_reroll())


func show_offer(o: Array) -> void:
	offer = o
	for w in _widgets:
		w.queue_free()
	_widgets.clear()
	var i := 0
	for entry in offer:
		i += 1
		var card: Dictionary = Data.card_by_id[entry["id"]]
		var w := RarityFrame.new()
		w.custom_minimum_size = Vector2(232, 338)
		var stack: int = int(entry["stack"])
		w.set_data(String(entry["rarity"]), String(card["name"]), String(card["category"]).capitalize(), String(card["effect_by_stack"][stack - 1]),
			"Upgrade: stack %d of 6" % stack if stack > 1 else "New card")
		w.set_art(IconArt.glyph_for_card(card), String(card["category"]))
		w.badge = "Stack %d/6" % stack if stack > 1 else ""
		w.hotkey = str(i)
		w.gui_input.connect(_on_card_input.bind(String(entry["id"])))
		_row.add_child(w)
		_widgets.append(w)
	visible = true
	shown = true
	_holder.visible = true
	_tab.visible = false
	_refresh_reroll()
	_hint.text = "Press 1 / 2 / 3 to pick     Tab: hide"


func _refresh_reroll() -> void:
	if _reroll != null:
		_reroll.text = "Reroll (T): %d" % Game.rerolls
		_reroll.disabled = Game.rerolls <= 0
	if _tab != null:
		_tab.text = "Tab: show cards  (%d waiting)" % maxi(Game.pending_offers, 1)


func _on_card_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick(id)


func _pick(id: String) -> void:
	Game.pick_card(id)
	picked.emit(id)
	if Game.current_offer.is_empty():
		visible = false
	_refresh_reroll()


func _unhandled_input(event: InputEvent) -> void:
	if not visible and Game.pending_offers <= 0:
		return
	if event.is_action_pressed("card_toggle"):
		shown = not shown
		_holder.visible = shown
		_tab.visible = not shown
		visible = true
		get_viewport().set_input_as_handled()
		return
	if not shown or offer.is_empty():
		return
	for i in 4:
		if event.is_action_pressed("card_%d" % (i + 1)) and i < offer.size():
			_pick(String(offer[i]["id"]))
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("card_reroll"):
		Game.reroll_offer()
		get_viewport().set_input_as_handled()
