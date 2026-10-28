class_name Lobby
extends Control
## The lobby: four maps picked at random, everyone in the match votes for one, and the map with the most votes is played (a tie is broken by chance).
## You vote with a click; the other players (the bots) vote at random moments while the clock runs down. "Start now" ends the vote early once you have voted.

signal confirmed(map_id: String)
signal back_pressed()

const VOTE_TIME := 20.0
const CARD_SIZE := Vector2(268, 372)

var maps: Array = []                      # the four map ids on offer
var votes: Dictionary = {}                # voter id -> map id
var voters: Array = []                    # [{id, name, team, at (seconds when a bot votes), map}]
var phase := "voting"                     # voting -> result
var _t := 0.0
var _result_t := 0.0
var _winner := ""
var _tie := false
var _cards: Dictionary = {}               # map id -> {panel, dots, count, button, bar}
var _timer_label: Label
var _count_label: Label
var _status_label: Label
var _clock: UiKit.Bar
var _start_btn: Button
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	UiKit.full_rect(self)
	_rng.randomize()
	var back := MainMenu.Backdrop.new()
	UiKit.full_rect(back)
	add_child(back)
	maps = _pick_maps()
	_make_voters()
	var root := VBoxContainer.new()
	UiKit.full_rect(root)
	root.offset_left = 44
	root.offset_right = -44
	root.offset_top = 22
	root.offset_bottom = -22
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.add_child(_header())
	_clock = UiKit.Bar.new()
	_clock.custom_minimum_size = Vector2(0, 10)
	_clock.color = Color(0.95, 0.75, 0.25)
	_clock.show_text = false
	root.add_child(_clock)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	for id in maps:
		row.add_child(_card(String(id)))
	root.add_child(_footer())
	_refresh()


## Four different maps whose files exist, chosen at random (never only the one you just played if others are available).
func _pick_maps() -> Array:
	var pool: Array = []
	for id in Data.map_order:
		if ResourceLoader.exists("res://maps/%s/%s.glb" % [id, id]):
			pool.append(id)
	if pool.size() > 4 and Game.last_map != "":
		pool.erase(Game.last_map)
	pool.shuffle()
	return pool.slice(0, mini(4, pool.size()))


func _make_voters() -> void:
	voters.clear()
	voters.append({"id": "you", "name": "You", "team": "you", "at": -1.0, "map": ""})
	for i in Game.bots_per_team:
		voters.append({"id": "ally%d" % i, "name": "Ally %d" % (i + 1), "team": "ally", "at": _rng.randf_range(1.0, VOTE_TIME - 4.0), "map": ""})
	for i in Game.bots_per_team + 1:
		voters.append({"id": "foe%d" % i, "name": "Foe %d" % (i + 1), "team": "foe", "at": _rng.randf_range(1.0, VOTE_TIME - 4.0), "map": ""})


func _header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	left.add_child(UiKit.label("LOBBY", 38, UiKit.GOLD))
	left.add_child(UiKit.label("Vote for the battleground. The map with the most votes is played.", 15, Color(0.85, 0.82, 0.95)))
	h.add_child(left)
	_count_label = UiKit.label("", 16, UiKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_count_label)
	_timer_label = UiKit.label("0:20", 44, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_timer_label.custom_minimum_size = Vector2(110, 0)
	h.add_child(_timer_label)
	return h


func _footer() -> Control:
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 14)
	f.add_child(UiKit.button("Back", func() -> void: back_pressed.emit(), 20, Vector2(130, 46)))
	_status_label = UiKit.label("", 18, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	f.add_child(_status_label)
	f.add_child(UiKit.button("Surprise me", func() -> void: vote(_rng.randi() % maps.size()), 18, Vector2(150, 46)))
	_start_btn = UiKit.button("START NOW", func() -> void: _finish_vote(), 22, Vector2(200, 46))
	f.add_child(_start_btn)
	return f


func _card(id: String) -> Control:
	var md: Dictionary = Data.maps[id]
	var p := UiKit.panel(Color(0.06, 0.07, 0.12, 0.94), UiKit.GOLD_DARK, 8)
	p.custom_minimum_size = CARD_SIZE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(240, 136)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tp := "res://ui/maps/%s.png" % id
	if ResourceLoader.exists(tp):
		thumb.texture = load(tp)
	thumb.clip_contents = true
	v.add_child(thumb)
	v.add_child(UiKit.label(String(md["title"]), 24, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var sz: Array = md.get("size_m", [0, 0])
	var info := UiKit.label("%d x %d m  |  %s  |  %s" % [sz[0], sz[1], md.get("mechanic", "?"), md.get("hazard", "?")], 12, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(240, 30)
	v.add_child(info)
	v.add_child(UiKit.label(("+ %s" % md.get("buffed_class", "?")) if String(md.get("buffed_class", "")) != "" else "neutral board", 13, Color(0.55, 1.0, 0.65), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label(("- %s" % md.get("debuffed_class", "?")) if String(md.get("debuffed_class", "")) != "" else "no debuffs", 13, Color(1.0, 0.6, 0.55), HORIZONTAL_ALIGNMENT_CENTER))
	var dots := HFlowContainer.new()
	dots.add_theme_constant_override("h_separation", 4)
	dots.add_theme_constant_override("v_separation", 4)
	dots.custom_minimum_size = Vector2(240, 44)
	dots.alignment = FlowContainer.ALIGNMENT_CENTER
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(dots)
	var count := UiKit.label("0 votes", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(count)
	var idx := maps.find(id)
	var btn := UiKit.button("VOTE", func() -> void: vote(idx), 20, Vector2(240, 42))
	v.add_child(btn)
	_cards[id] = {"panel": p, "dots": dots, "count": count, "button": btn}
	return p


## You vote for the map at `index` (clicking another card moves your vote).
func vote(index: int) -> void:
	if phase != "voting" or index < 0 or index >= maps.size():
		return
	_cast("you", String(maps[index]))


func _cast(voter_id: String, map_id: String) -> void:
	votes[voter_id] = map_id
	for vt in voters:
		if vt["id"] == voter_id:
			vt["map"] = map_id
	_refresh()


func _refresh() -> void:
	var counts := {}
	for id in maps:
		counts[id] = 0
	for vid in votes:
		counts[votes[vid]] = int(counts.get(votes[vid], 0)) + 1
	for id in maps:
		var c: Dictionary = _cards[id]
		var n: int = counts[id]
		(c["count"] as Label).text = "%d vote%s" % [n, "" if n == 1 else "s"]
		var mine: bool = votes.get("you", "") == id
		var panel := c["panel"] as UiKit.FantasyPanel
		panel.border = UiKit.GOLD if mine else UiKit.GOLD_DARK
		panel.queue_redraw()
		(c["button"] as Button).text = "YOUR VOTE" if mine else "VOTE"
		# one dot per voter: gold = you, blue = allies, red = foes
		var dots := c["dots"] as HFlowContainer
		for ch in dots.get_children():
			ch.queue_free()
		for vt in voters:
			if vt["map"] == id:
				dots.add_child(_dot(String(vt["team"]), String(vt["name"])))
	_count_label.text = "%d of %d players have voted" % [votes.size(), voters.size()]
	_start_btn.disabled = phase != "voting" or not votes.has("you")
	if phase == "voting":
		_status_label.text = "Click a map to vote" if not votes.has("you") else "Vote cast. Others are still choosing..."


func _dot(team: String, who: String) -> Control:
	var d := Control.new()
	d.custom_minimum_size = Vector2(18, 18)
	d.tooltip_text = who
	var col := Color(1.0, 0.85, 0.35) if team == "you" else (Color(0.4, 0.65, 1.0) if team == "ally" else Color(1.0, 0.4, 0.4))
	d.draw.connect(func() -> void:
		d.draw_circle(Vector2(9, 9), 8.0, Color(0, 0, 0, 0.8))
		d.draw_circle(Vector2(9, 9), 6.5, col)
		d.draw_circle(Vector2(7, 7), 2.0, Color(1, 1, 1, 0.5)))
	return d


func _process(delta: float) -> void:
	if phase == "voting":
		_t += delta
		for vt in voters:
			if vt["at"] >= 0.0 and vt["map"] == "" and _t >= float(vt["at"]):
				_cast(String(vt["id"]), String(maps[_rng.randi() % maps.size()]))
		var left := maxf(0.0, VOTE_TIME - _t)
		_timer_label.text = "0:%02d" % int(ceilf(left))
		_clock.set_value(left / VOTE_TIME)
		if left <= 0.0 or (votes.size() >= voters.size() and _t > 2.0):
			_finish_vote()
	elif phase == "result":
		_result_t += delta
		var k := clampf(_result_t / 0.4, 0.0, 1.0)
		for id in maps:
			var panel := _cards[id]["panel"] as Control
			panel.pivot_offset = panel.size * 0.5
			if id == _winner:
				panel.scale = Vector2.ONE * (1.0 + 0.06 * k)
				panel.modulate = Color.WHITE.lerp(Color(1.3, 1.2, 0.9), 0.5 + 0.5 * sin(_result_t * 8.0))
			else:
				panel.modulate = Color(1, 1, 1, 1.0 - 0.65 * k)
		if _result_t > 2.4:
			phase = "done"
			confirmed.emit(_winner)


## Counts the votes and picks the winner; a tie goes to chance.
func _finish_vote() -> void:
	if phase != "voting":
		return
	for vt in voters:
		if vt["map"] == "" and vt["id"] != "you":
			votes[vt["id"]] = String(maps[_rng.randi() % maps.size()])
			vt["map"] = votes[vt["id"]]
	var counts := {}
	for id in maps:
		counts[id] = 0
	for vid in votes:
		counts[votes[vid]] = int(counts.get(votes[vid], 0)) + 1
	var best := -1
	var top: Array = []
	for id in maps:
		if counts[id] > best:
			best = counts[id]
			top = [id]
		elif counts[id] == best:
			top.append(id)
	_tie = top.size() > 1
	_winner = String(top[_rng.randi() % top.size()])
	phase = "result"
	_refresh()
	_start_btn.disabled = true
	for id in maps:
		(_cards[id]["button"] as Button).disabled = true
	var md: Dictionary = Data.maps[_winner]
	_status_label.text = ("A tie, decided by fate: " if _tie else "The vote is in: ") + String(md["title"])
	_timer_label.text = "GO"
