class_name Armory
extends Control
## The armory: pick the class, the 3 skills, the weapon, the 5 armor pieces (with set progress like "3/5"), socket runes, manage the bag.
## Open from the menu before a match, or with I during one. Every item shows its rarity by colour, frame shape, icon and written name.

signal closed(start_match: bool)

const SLOT_ORDER := ["weapon", "helmet", "chestplate", "shield", "leggings", "boots"]
const SLOT_LABEL := {"weapon": "Weapon", "helmet": "Helmet", "chestplate": "Chestplate", "shield": "Shield", "leggings": "Leggings", "boots": "Boots"}

var in_match := false
var _class_id := "druid"
var _preview: ModelPreview
var _class_info: VBoxContainer
var _slot_widgets: Dictionary = {}
var _skill_row: HBoxContainer
var _set_box: VBoxContainer
var _grid: GridContainer
var _detail: VBoxContainer
var _filter := "all"
var _selected_uid := ""
var _filter_buttons: HBoxContainer
var _buff_label: Label
var _popup: PopupPanel
var _focus_slot := ""


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.05, 0.97)
	UiKit.full_rect(back)
	add_child(back)
	var margin := MarginContainer.new()
	UiKit.full_rect(margin)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 18)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	body.add_child(_left_panel())
	body.add_child(_center_panel())
	body.add_child(_right_panel())
	_popup = PopupPanel.new()
	add_child(_popup)
	_class_id = Game.selected_class
	Game.inventory_changed.connect(refresh)
	Game.equipment_changed.connect(refresh)
	set_class(_class_id)


func _header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var title := UiKit.label("ARMORY", 34, UiKit.GOLD)
	title.add_theme_constant_override("outline_size", 6)
	h.add_child(title)
	h.add_child(UiKit.button("<", func() -> void: _step_class(-1), 22, Vector2(48, 44)))
	var plaque := UiKit.panel(Color(0.05, 0.06, 0.1, 0.95), UiKit.GOLD_DARK, 6)
	plaque.custom_minimum_size = Vector2(300, 44)
	_buff_label = UiKit.label("", 24)
	_buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plaque.add_child(_buff_label)
	h.add_child(plaque)
	h.add_child(UiKit.button(">", func() -> void: _step_class(1), 22, Vector2(48, 44)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	if in_match:
		h.add_child(UiKit.button("Back to the fight (I)", func() -> void: closed.emit(false), 20, Vector2(240, 44)))
	else:
		h.add_child(UiKit.button("Back", func() -> void: closed.emit(false), 20, Vector2(120, 44)))
		h.add_child(UiKit.button("START MATCH", func() -> void: closed.emit(true), 22, Vector2(220, 44)))
	return h


func _left_panel() -> Control:
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(270, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	_preview = ModelPreview.new()
	_preview.custom_minimum_size = Vector2(246, 270)
	v.add_child(_preview)
	_class_info = VBoxContainer.new()
	_class_info.add_theme_constant_override("separation", 2)
	v.add_child(_class_info)
	return p


func _center_panel() -> Control:
	var p := UiKit.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_heading("SKILLS", "click 1, 2 or 3 to change"))
	_skill_row = HBoxContainer.new()
	_skill_row.add_theme_constant_override("separation", 12)
	v.add_child(_skill_row)
	v.add_child(_heading("EQUIPMENT", "click a slot, right-click to remove"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	# a silhouette-like layout: weapon, helmet, shield / chestplate, leggings, boots
	for slot in ["weapon", "helmet", "shield", "chestplate", "leggings", "boots"]:
		var w := RarityFrame.new()
		w.compact = true
		w.custom_minimum_size = Vector2(166, 84)
		w.gui_input.connect(_on_slot_input.bind(slot))
		grid.add_child(w)
		_slot_widgets[slot] = w
	v.add_child(_heading("ARMOR SETS", ""))
	_set_box = VBoxContainer.new()
	_set_box.add_theme_constant_override("separation", 2)
	v.add_child(_set_box)
	return p


func _right_panel() -> Control:
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(330, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_heading("BAG", "double-click an item to equip it"))
	_filter_buttons = HBoxContainer.new()
	_filter_buttons.add_theme_constant_override("separation", 4)
	v.add_child(_filter_buttons)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 270)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	_detail.custom_minimum_size = Vector2(0, 190)
	v.add_child(_detail)
	return p


# ================================================================= class

func _step_class(d: int) -> void:
	var i: int = Data.class_order.find(_class_id)
	set_class(Data.class_order[(i + d + Data.class_order.size()) % Data.class_order.size()])


func set_class(id: String) -> void:
	_class_id = id
	Game.selected_class = id
	Game.save_profile()
	refresh()


func refresh() -> void:
	if _preview == null:
		return
	var cd: Dictionary = Data.classes[_class_id]
	var wid: String = Game.equipped_item("weapon").get("id", cd["weapon"])
	_preview.show_class(_class_id, wid)
	var col := Data.color_of(cd["color"])
	_buff_label.text = String(cd["name"]).to_upper()
	_buff_label.add_theme_color_override("font_color", col)
	_rebuild_filters()
	_fill_class_info_polished(cd)
	_fill_skills(cd)
	_fill_slots()
	_fill_sets()
	_fill_bag()
	_fill_detail()


func _fill_class_info(cd: Dictionary) -> void:
	for c in _class_info.get_children():
		c.queue_free()
	var st: Dictionary = cd["stats"]
	var head_l := UiKit.label("%s  |  %s" % [("Magic" if cd["magic"] else "Non-magic"), String(cd["home_map"]).replace("_", " ").capitalize()], 15, UiKit.DIM)
	head_l.custom_minimum_size = Vector2(246, 0)
	_class_info.add_child(head_l)
	var stats_l := UiKit.label("Health %d  Mana %d  Speed %.1f
Sight %d m  Crit %d%%" % [cd["health"], cd["mana"], st["speed"], st["sight"], int(st["crit"] * 100)], 14)
	stats_l.custom_minimum_size = Vector2(246, 0)
	_class_info.add_child(stats_l)
	var pv: Dictionary = cd["passive"]
	var l := UiKit.label("Passive: %s. %s" % [pv["name"], pv["desc"]], 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(246, 0)
	_class_info.add_child(l)
	var m: Dictionary = cd["meter"]
	var l2 := UiKit.label("Class meter: %s. %s" % [m["name"], m["desc"]], 14, Color(0.8, 0.9, 1.0))
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.custom_minimum_size = Vector2(290, 0)
	_class_info.add_child(l2)
	var buffed := ""
	for mid in Data.map_order:
		var md: Dictionary = Data.maps[mid]
		if String(md.get("buffed_class", "")).to_lower() == String(cd["name"]).to_lower():
			buffed = md["title"]
	if buffed != "":
		_class_info.add_child(UiKit.label("Buffed on %s" % buffed, 14, Color(0.5, 1.0, 0.6)))
	var ds := ""
	for mid in Data.map_order:
		var md: Dictionary = Data.maps[mid]
		if String(md.get("debuffed_class", "")).to_lower() == String(cd["name"]).to_lower():
			ds = md["title"]
	_class_info.add_child(UiKit.label("Weakened on %s" % ds if ds != "" else "Never weakened by a map", 14, Color(1.0, 0.55, 0.5) if ds != "" else Color(0.7, 1.0, 0.7)))


# ================================================================= skills

func _fill_skills(cd: Dictionary) -> void:
	for c in _skill_row.get_children():
		c.queue_free()
	var chosen: Array = Game.skills_for(_class_id)
	for i in 3:
		var sk: Dictionary = Data.skills[chosen[i]]
		var w := _skill_widget(sk, str(i + 1), false)
		w.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_pick_skill(i))
		_skill_row.add_child(w)
	var sig: Dictionary = Data.skills[cd["signature"]]
	_skill_row.add_child(_skill_widget(sig, "F", true))
	var ult: Dictionary = Data.skills[cd["ultimate"]]
	_skill_row.add_child(_skill_widget(ult, "X", false, true))
	var q := UiKit.SkillSlot.new()
	q.custom_minimum_size = Vector2(78, 78)
	q.letter = "V"
	q.frame_color = Color(0.7, 0.5, 1.0)
	if Game.quest_skill != "" and Data.quest_by_id.has(Game.quest_skill):
		var qs: Dictionary = Data.quest_by_id[Game.quest_skill]
		q.set_quest(qs)
		q.tooltip_text = "Quest skill: %s (%s)\n%s" % [qs["name"], String(qs["rarity"]).capitalize(), qs["effect"]]
	else:
		q.tooltip_text = "No quest skill yet. Finish a sage's quest to earn one."
	q.animated = true
	_skill_row.add_child(q)


func _skill_widget(sk: Dictionary, letter: String, special: bool, ult: bool = false) -> UiKit.SkillSlot:
	var w := UiKit.SkillSlot.new()
	w.custom_minimum_size = Vector2(78, 78)
	w.letter = letter
	w.set_skill(sk)
	w.special = special
	w.ult = ult
	w.animated = true
	var own: bool = sk["class"] == _class_id
	w.tooltip_text = "%s%s\n%s\nCooldown %s s, mana %s%s" % [sk["name"], "  (own class: massively buffed)" if own else "", sk["desc"], sk["cooldown"], sk["mana"],
		"\nFixed: you cannot change this one." if special or ult else "\nClick to change."]
	return w


func _pick_skill(slot: int) -> void:
	for c in _popup.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 420)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	scroll.add_child(v)
	v.add_child(UiKit.label("Choose a skill (skills of your own class are massively buffed)", 16, UiKit.GOLD))
	var chosen: Array = Game.skills_for(_class_id)
	var order: Array = [_class_id]
	for cid in Data.class_order:
		if cid != _class_id:
			order.append(cid)
	for cid in order:
		var head := UiKit.label(String(Data.classes[cid]["name"]).to_upper() + ("  (yours)" if cid == _class_id else ""), 14, Data.color_of(Data.classes[cid]["color"]))
		v.add_child(head)
		for sid in Data.classes[cid]["skills"]:
			var sk: Dictionary = Data.skills[sid]
			var unlocked: bool = Game.unlocked_skills.has(sid)
			var b := UiKit.button("%s%s  -  %s" % [sk["name"], "" if unlocked else "  (locked: level %d)" % (10 * (Data.classes[cid]["skills"].find(sid) - 2))], func() -> void:
				if not unlocked or sid in chosen:
					return
				Game.set_chosen_skill(_class_id, slot, sid)
				_popup.hide()
				refresh(), 14, Vector2(440, 40))
			b.disabled = not unlocked or sid in chosen
			b.tooltip_text = String(sk["desc"])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var ic := UiKit.SkillSlot.new()
			ic.custom_minimum_size = Vector2(44, 44)
			ic.show_name = false
			ic.set_skill(sk)
			ic.disabled = not unlocked
			ic.tooltip_text = String(sk["desc"])
			row.add_child(ic)
			row.add_child(b)
			v.add_child(row)
	_popup.add_child(scroll)
	_popup.popup_centered()


# ================================================================= equipment

func _on_slot_input(ev: InputEvent, slot: String) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		var it: Dictionary = Game.equipped_item(slot)
		if ev.button_index == MOUSE_BUTTON_RIGHT and not it.is_empty():
			Game.unequip(slot)
			return
		_focus_slot = slot
		_filter = "weapon" if slot == "weapon" else "armor"
		_selected_uid = String(it.get("uid", ""))
		refresh()


func _fill_slots() -> void:
	for slot in _slot_widgets:
		var w: RarityFrame = _slot_widgets[slot]
		var it: Dictionary = Game.equipped_item(slot)
		if it.is_empty():
			w.set_data("common", "- empty -", SLOT_LABEL[slot], "")
			w.set_art("sword" if slot == "weapon" else IconArt.glyph_for_slot(slot), "utility")
			w.rarity = "common"
			w.modulate = Color(1, 1, 1, 0.5)
		else:
			w.modulate = Color.WHITE
			var sub: String = SLOT_LABEL[slot]
			if it.get("new", false):
				sub += " | new"
			w.set_data(String(it["rarity"]), Loot.item_name(it), sub, "")
			w.set_art(IconArt.glyph_for_item(it), IconArt.category_for_item(it))
			if it["kind"] == "weapon" and Data.weapons.has(it["id"]):
				w.set_weapon(Data.weapons[it["id"]])
			w.magic_icon = _is_magic(it)
		w.selected = (it.get("uid", "-") == _selected_uid and _selected_uid != "")
		w.tooltip_text = "Right-click to unequip" if not it.is_empty() else "Pick an item from the bag"


func _fill_sets() -> void:
	for c in _set_box.get_children():
		c.queue_free()
	var counts: Dictionary = {}
	for slot in SLOT_ORDER:
		var it := Game.equipped_item(slot)
		if not it.is_empty() and it["kind"] == "armor":
			counts[it["set"]] = int(counts.get(it["set"], 0)) + 1
	if counts.is_empty():
		_set_box.add_child(UiKit.label("Wear several pieces of one set: at 5/5 the set bonus lights up.", 14, UiKit.DIM))
	for sid in counts:
		var s: Dictionary = Data.armor_sets[sid]
		var full: bool = int(counts[sid]) >= 5
		var l := UiKit.label("%s  %d/5   %s" % [s["name"], counts[sid], ("SET BONUS ACTIVE: " + String(s["set_bonus"]["desc"])) if full else "(bonus at 5/5: " + String(s["set_bonus"]["desc"]) + ")"], 14,
			Data.rarity_color(String(s["rarity"])) if full else UiKit.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(450, 0)
		_set_box.add_child(l)


func _is_magic(it: Dictionary) -> bool:
	if it["kind"] == "weapon":
		return bool(Data.weapons[it["id"]]["magic"])
	if it["kind"] == "armor":
		return bool(Data.armor_sets[it["set"]]["magic"])
	return false


# ================================================================= bag

func _fill_bag() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var items: Array = []
	for it in Game.inventory:
		match _filter:
			"weapon":
				if it["kind"] != "weapon":
					continue
			"armor":
				if it["kind"] != "armor":
					continue
			"rune":
				if it["kind"] != "rune":
					continue
		if _focus_slot != "" and _filter == "armor" and _focus_slot != "weapon" and it["kind"] == "armor" and it["slot"] != _focus_slot:
			continue
		items.append(it)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Data.rarity_index(a["rarity"]) > Data.rarity_index(b["rarity"]))
	if items.is_empty():
		_grid.add_child(UiKit.label("Nothing here yet. Open loot crates on the map!", 15, UiKit.DIM))
	for it in items:
		var w := RarityFrame.new()
		w.compact = true
		w.custom_minimum_size = Vector2(148, 78)
		var equipped := false
		for s in Game.equipped:
			if Game.equipped[s] == it["uid"]:
				equipped = true
		var sub: String = String(it["kind"]).capitalize() + (" | equipped" if equipped else "")
		w.set_data(String(it["rarity"]), Loot.item_name(it), sub, "")
		w.set_art(IconArt.glyph_for_item(it), IconArt.category_for_item(it))
		if it["kind"] == "weapon" and Data.weapons.has(it["id"]):
			w.set_weapon(Data.weapons[it["id"]])
		w.magic_icon = _is_magic(it)
		w.selected = it["uid"] == _selected_uid
		w.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.double_click and not (it["kind"] == "rune"):
					Game.equip(it)
					return
				_selected_uid = String(it["uid"])
				refresh())
		_grid.add_child(w)


func _fill_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var it: Dictionary = Game.item_by_uid(_selected_uid)
	if it.is_empty():
		_detail.add_child(UiKit.label("Select an item to see its details.", 15, UiKit.DIM))
		return
	var col := Data.rarity_color(String(it["rarity"]))
	var shape: String = RarityFrame.SHAPES[it["rarity"]]
	_detail.add_child(UiKit.label("%s   [%s %s]" % [Loot.item_name(it), String(Data.rarity(it["rarity"])["name"]).to_upper(), shape], 18, col))
	for line in Loot.describe(it):
		var l := UiKit.label(String(line), 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(290, 0)
		_detail.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail.add_child(row)
	if it["kind"] == "rune":
		var target := _socket_target()
		var b := UiKit.button("Socket into %s" % (Loot.item_name(target) if not target.is_empty() else "(select gear first)"), func() -> void: _socket(it), 14, Vector2(260, 32))
		b.disabled = target.is_empty()
		row.add_child(b)
	else:
		row.add_child(UiKit.button("Equip", func() -> void: Game.equip(it), 15, Vector2(90, 32)))
		var sockets: int = int(it.get("sockets", 0))
		var rl: Array = it.get("runes", [])
		_detail.add_child(UiKit.label("Rune sockets: %d/%d  %s" % [rl.size(), sockets, ", ".join(rl.map(func(r: String) -> String: return Data.runes[r]["name"]))], 14, Color(0.8, 0.85, 1.0)))
		if rl.size() > 0:
			row.add_child(UiKit.button("Remove runes", func() -> void:
				for r in rl:
					Game.add_item({"kind": "rune", "id": r, "rarity": Data.runes[r]["rarity"]})
				it["runes"] = []
				Game.save_profile()
				Game.equipment_changed.emit(), 14, Vector2(130, 32)))
	row.add_child(UiKit.button("Discard", func() -> void:
		Game.remove_item(String(it["uid"]))
		_selected_uid = "", 14, Vector2(90, 32)))


func _socket_target() -> Dictionary:
	# the last selected gear item that has a free socket: equipped weapon first
	for slot in SLOT_ORDER:
		var it := Game.equipped_item(slot)
		if not it.is_empty() and it.get("runes", []).size() < int(it.get("sockets", 0)):
			return it
	return {}


func _socket(rune_item: Dictionary) -> void:
	var target := _socket_target()
	if target.is_empty():
		return
	target["runes"].append(String(rune_item["id"]))
	Game.remove_item(String(rune_item["uid"]))
	Game.save_profile()
	Game.equipment_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and in_match and (event.is_action_pressed("armory") or event.is_action_pressed("menu")):
		closed.emit(false)
		get_viewport().set_input_as_handled()


# ================================================================= polish helpers

## A section heading: gold serif title, a thin gold rule and a small hint on the right.
func _heading(title: String, hint: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(UiKit.label(title, 18, UiKit.GOLD))
	var rule := ColorRect.new()
	rule.color = Color(UiKit.GOLD_DARK.r, UiKit.GOLD_DARK.g, UiKit.GOLD_DARK.b, 0.7)
	rule.custom_minimum_size = Vector2(10, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(rule)
	if hint != "":
		h.add_child(UiKit.label(hint, 12, UiKit.DIM))
	return h


func _rebuild_filters() -> void:
	for c in _filter_buttons.get_children():
		c.queue_free()
	for f in [["all", "All"], ["weapon", "Weapons"], ["armor", "Armor"], ["rune", "Runes"]]:
		var key: String = f[0]
		_filter_buttons.add_child(UiKit.tab_button(f[1], _filter == key, func() -> void:
			_filter = key
			_focus_slot = "" if key != "armor" and key != "weapon" else _focus_slot
			refresh()))


func _info_block(title: String, text: String, title_col: Color, text_col: Color = UiKit.TEXT) -> void:
	_class_info.add_child(UiKit.label(title, 12, title_col))
	var l := UiKit.label(text, 13, text_col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(240, 0)
	_class_info.add_child(l)


func _stat_chip(name: String, value: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.2)
	sb.border_color = Color(UiKit.GOLD_DARK.r, UiKit.GOLD_DARK.g, UiKit.GOLD_DARK.b, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	v.add_child(UiKit.label(value, 15, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label(name, 11, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _fill_class_info_polished(cd: Dictionary) -> void:
	for c in _class_info.get_children():
		c.queue_free()
	var st: Dictionary = cd["stats"]
	var col := Data.color_of(cd["color"])
	_class_info.add_child(UiKit.label("%s  |  %s  |  class level %d" % [("Magic" if cd["magic"] else "Non-magic"), String(cd["home_map"]).replace("_", " ").capitalize(), Game.class_level(String(cd["id"]))], 14, col.lerp(Color.WHITE, 0.4)))
	_class_info.add_child(UiKit.label("Class level: %s; a new skill opens every 10 levels" % Game.class_bonus_text(String(cd["id"])), 13, UiKit.DIM))
	var chips := GridContainer.new()
	chips.columns = 3
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	for pr in [["Health", str(cd["health"])], ["Mana", str(cd["mana"])], ["Speed", "%.1f" % st["speed"]], ["Sight", "%d m" % st["sight"]], ["Crit", "%d%%" % int(st["crit"] * 100)]]:
		chips.add_child(_stat_chip(pr[0], pr[1]))
	_class_info.add_child(chips)
	var pv: Dictionary = cd["passive"]
	_info_block("PASSIVE  " + String(pv["name"]), String(pv["desc"]), UiKit.GOLD)
	var m: Dictionary = cd["meter"]
	_info_block("CLASS METER  " + String(m["name"]), String(m["desc"]), Color(0.55, 0.85, 1.0), Color(0.85, 0.92, 1.0))
	var buffed := ""
	var weak := ""
	for mid in Data.map_order:
		var md: Dictionary = Data.maps[mid]
		if String(md.get("buffed_class", "")).to_lower() == String(cd["name"]).to_lower():
			buffed = md["title"]
		if String(md.get("debuffed_class", "")).to_lower() == String(cd["name"]).to_lower():
			weak = md["title"]
	if buffed != "":
		_class_info.add_child(UiKit.label("+ Buffed on %s" % buffed, 13, Color(0.5, 1.0, 0.6)))
	_class_info.add_child(UiKit.label(("- Weakened on %s" % weak) if weak != "" else "+ Never weakened by a map", 13, Color(1.0, 0.55, 0.5) if weak != "" else Color(0.7, 1.0, 0.7)))
