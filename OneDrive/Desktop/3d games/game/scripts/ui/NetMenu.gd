class_name NetMenu
extends Control
## LAN game screen. HOST: starts listening, shows the address friends type, lists who joined and starts the match (the map vote opens first).
## JOIN: type the host's address and connect; the match starts when the host starts it. Both machines need the same game files.

signal closed()
signal start_pressed()

var _ip: LineEdit
var _status: Label
var _players: Label
var _addr: Label
var _start: Button
var _host_btn: Button
var _join_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.9)
	UiKit.full_rect(dim)
	add_child(dim)
	var panel := UiKit.panel(Color(0.06, 0.07, 0.12, 0.98), UiKit.GOLD_DARK, 10)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -270
	panel.offset_bottom = 270
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UiKit.label("LAN GAME", 34, UiKit.GOLD))
	v.add_child(UiKit.label("Play with friends on the same network. One of you hosts, the others join. Bots fill the rest of the teams.", 14, UiKit.DIM))
	v.add_child(HSeparator.new())
	_host_btn = UiKit.button("HOST A GAME", func() -> void: _host(), 22, Vector2(300, 46))
	v.add_child(_host_btn)
	_addr = UiKit.label("", 15, Color(0.75, 0.95, 0.8))
	_addr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_addr)
	_players = UiKit.label("", 15, Color.WHITE)
	v.add_child(_players)
	_start = UiKit.button("START THE MATCH  (vote the map)", func() -> void: start_pressed.emit(), 20, Vector2(380, 46))
	_start.visible = false
	v.add_child(_start)
	v.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UiKit.label("Host address:", 16, UiKit.TEXT))
	_ip = LineEdit.new()
	_ip.text = "127.0.0.1"
	_ip.placeholder_text = "for example 192.168.1.20"
	_ip.custom_minimum_size = Vector2(240, 38)
	_ip.add_theme_font_size_override("font_size", 18)
	row.add_child(_ip)
	_join_btn = UiKit.button("JOIN", func() -> void: _join(), 20, Vector2(110, 40))
	row.add_child(_join_btn)
	_status = UiKit.label("", 15, Color(1.0, 0.9, 0.6))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	v.add_child(UiKit.button("BACK", func() -> void: _close(), 18, Vector2(160, 40)))
	Net.peers_changed.connect(_refresh)
	_refresh()


func _host() -> void:
	Net.host_game()
	_refresh()


func _join() -> void:
	Net.join_game(_ip.text.strip_edges())
	_refresh()


func _close() -> void:
	if Net.active:
		Net.stop()
	closed.emit()


func _refresh() -> void:
	if not is_inside_tree():
		return
	_status.text = Net.status
	_host_btn.disabled = Net.active
	_join_btn.disabled = Net.active
	_ip.editable = not Net.active
	_start.visible = Net.is_host
	if Net.is_host:
		var addrs := Net.local_addresses()
		_addr.text = "Friends join with this address: %s   (port %d)" % [", ".join(addrs) if not addrs.is_empty() else "see your network settings", Net.PORT]
		var names := ["You (host)"]
		for id in Net.peers:
			names.append("%s  (%s)" % [String(Net.peers[id].get("name", "player")), String(Net.peers[id].get("class", "")).replace("_", " ")])
		_players.text = "In the lobby:  " + ",  ".join(names)
	else:
		_addr.text = ""
		_players.text = ""
