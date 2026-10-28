class_name LeaderboardMenu
extends Control
## The leaderboard: your career kill/death ratio (and by class), the best fighters of all the matches played (bots too), and your recent matches.
## Every match adds its kills and deaths (Game.record_match); the ratio is kills per death.

signal closed()

const TABS := ["You", "Top fighters", "Recent matches"]

var _tab := 0
var _content: VBoxContainer
var _tab_row: HBoxContainer


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
	head.add_child(UiKit.label("LEADERBOARD", 34, UiKit.GOLD))
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
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)
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
	for c in _tab_row.get_children():
		c.queue_free()
	for i in TABS.size():
		var idx := i
		_tab_row.add_child(UiKit.tab_button(TABS[i], i == _tab, func() -> void:
			_tab = idx
			_build(), 16, Vector2(150, 36)))
	for c in _content.get_children():
		c.queue_free()
	match _tab:
		0: _build_you()
		1: _build_top()
		2: _build_recent()


func _row(cells: Array, widths: Array, color: Color, size: int = 18, bg: bool = false) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	for i in cells.size():
		var l := UiKit.label(str(cells[i]), size, color)
		l.custom_minimum_size = Vector2(float(widths[i]), 0)
		r.add_child(l)
	if bg:
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.85, 0.4, 0.14)
		pc.add_theme_stylebox_override("panel", sb)
		pc.add_child(r)
		_content.add_child(pc)
	else:
		_content.add_child(r)


func _empty() -> void:
	_content.add_child(UiKit.label("Nothing here yet. Play a match: every kill and death is counted.", 18, UiKit.DIM))


func _build_you() -> void:
	var c: Dictionary = Game.career
	if int(c["matches"]) == 0:
		_empty()
		return
	var kdv := Game.kd(int(c["kills"]), int(c["deaths"]))
	var big := HBoxContainer.new()
	big.add_theme_constant_override("separation", 40)
	_content.add_child(big)
	for e in [["K/D", "%.2f" % kdv], ["Kills", str(c["kills"])], ["Deaths", str(c["deaths"])], ["Matches", str(c["matches"])], ["Wins", str(c["wins"])]]:
		var b := VBoxContainer.new()
		b.add_child(UiKit.label(String(e[1]), 44, UiKit.GOLD if e[0] == "K/D" else UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(UiKit.label(String(e[0]), 16, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
		big.add_child(b)
	_content.add_child(UiKit.label("Best streak %d      Best match K/D %.2f      Flags captured %d      Win rate %d%%" % [int(c["best_streak"]), float(c["best_kd"]), int(c["captures"]), roundi(100.0 * float(c["wins"]) / maxf(1.0, float(c["matches"])))], 17, UiKit.TEXT))
	_content.add_child(UiKit.label(" ", 8, UiKit.DIM))
	_content.add_child(UiKit.label("BY CLASS", 18, UiKit.GOLD))
	var widths := [200, 80, 80, 80, 90]
	_row(["Class", "Matches", "Kills", "Deaths", "K/D"], widths, UiKit.GOLD, 16)
	var by: Dictionary = {}
	for rec in Game.records:
		for row in rec["rows"]:
			if row.get("you", false):
				var e: Dictionary = by.get(row["cls"], {"m": 0, "k": 0, "d": 0})
				e["m"] += 1
				e["k"] += int(row["kills"])
				e["d"] += int(row["deaths"])
				by[row["cls"]] = e
	var keys := by.keys()
	keys.sort_custom(func(a, b) -> bool: return Game.kd(by[a]["k"], by[a]["d"]) > Game.kd(by[b]["k"], by[b]["d"]))
	for k in keys:
		var e: Dictionary = by[k]
		var known: bool = Data.classes.has(k)
		_row([Data.classes[k]["name"] if known else k, e["m"], e["k"], e["d"], "%.2f" % Game.kd(e["k"], e["d"])], widths, Data.color_of(Data.classes[k]["color"]).lerp(Color.WHITE, 0.45) if known else UiKit.TEXT, 17)


func _build_top() -> void:
	if Game.records.is_empty():
		_empty()
		return
	var agg: Dictionary = {}
	for rec in Game.records:
		for row in rec["rows"]:
			var nm := String(row["name"])
			var e: Dictionary = agg.get(nm, {"m": 0, "k": 0, "d": 0, "you": false, "cls": {}})
			e["m"] += 1
			e["k"] += int(row["kills"])
			e["d"] += int(row["deaths"])
			e["you"] = e["you"] or bool(row.get("you", false))
			e["cls"][row["cls"]] = int(e["cls"].get(row["cls"], 0)) + 1
			agg[nm] = e
	var names := agg.keys()
	names.sort_custom(func(a, b) -> bool:
		var ka := Game.kd(agg[a]["k"], agg[a]["d"])
		var kb := Game.kd(agg[b]["k"], agg[b]["d"])
		return ka > kb if not is_equal_approx(ka, kb) else int(agg[a]["k"]) > int(agg[b]["k"]))
	var widths := [40, 180, 170, 80, 80, 80, 90]
	_row(["#", "Name", "Class", "Matches", "Kills", "Deaths", "K/D"], widths, UiKit.GOLD, 16)
	var rank := 0
	for nm in names:
		var e: Dictionary = agg[nm]
		if int(e["m"]) < 2 and not bool(e["you"]) and names.size() > 12:
			continue                                       # names seen in only one match only fill the list when there are few
		rank += 1
		if rank > 16:
			break
		var best_cls := ""
		var best_n := 0
		for cl in e["cls"]:
			if int(e["cls"][cl]) > best_n:
				best_n = int(e["cls"][cl])
				best_cls = cl
		var cls_name: String = Data.classes[best_cls]["name"] if Data.classes.has(best_cls) else best_cls
		_row([rank, nm, cls_name, e["m"], e["k"], e["d"], "%.2f" % Game.kd(e["k"], e["d"])], widths, UiKit.GOLD if e["you"] else UiKit.TEXT, 17, e["you"])


func _build_recent() -> void:
	if Game.records.is_empty():
		_empty()
		return
	var widths := [180, 130, 90, 110, 70, 70, 80]
	_row(["Map", "Mode", "Result", "Score", "K", "D", "K/D"], widths, UiKit.GOLD, 16)
	var shown := 0
	for i in range(Game.records.size() - 1, -1, -1):
		var rec: Dictionary = Game.records[i]
		var me: Dictionary = {}
		for row in rec["rows"]:
			if row.get("you", false):
				me = row
		if me.is_empty():
			continue
		shown += 1
		if shown > 16:
			break
		var title := String(Data.maps[rec["map"]]["title"]) if Data.maps.has(rec["map"]) else String(rec["map"])
		var mode_name: String = {"domination": "Domination", "tdm": "Deathmatch", "ctf": "Capture flag"}.get(rec["mode"], rec["mode"])
		var sc: Array = rec.get("score", [0, 0])
		var col := Color(0.55, 1.0, 0.6) if rec["won"] else (UiKit.TEXT if rec["winner"] == "draw" else Color(1.0, 0.6, 0.55))
		_row([title, mode_name, "Victory" if rec["won"] else ("Draw" if rec["winner"] == "draw" else "Defeat"), "%d - %d" % [int(sc[0]), int(sc[1])], me["kills"], me["deaths"],
			"%.2f" % Game.kd(int(me["kills"]), int(me["deaths"]))], widths, col, 17)
