extends Node
## Root of the game: the main menu, the armory and the running match.
## Command line (after --): autostart=<map_id> class=<class_id> shot=<png path> shot_after=<seconds> quit_after=<seconds> script=<events>
## are for automated tests and screenshots.

var ui: CanvasLayer
var menu: MainMenu
var armory: Armory
var lobby: Lobby
var netmenu: NetMenu
var current_match: Match
var _args := {}
var _t := 0.0
var _net_wait := 0                           # test: start the hosted match once this many players have joined


func _ready() -> void:
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if _args.has("class"):
		Game.selected_class = String(_args["class"])
	Net.start_requested.connect(_on_net_start)
	Net.lost.connect(_on_net_lost)
	if _args.has("autostart"):
		Game.map_id = String(_args["autostart"])
		if _args.has("mode"):
			Game.game_mode = String(_args["mode"])
		if _args.has("bots"):
			Game.bots_per_team = int(_args["bots"])
		start_match()
	else:
		show_menu()
		if _args.get("screen", "") == "armory":
			open_armory()
		elif _args.get("screen", "") == "lobby":
			open_lobby()
		elif _args.get("screen", "") == "shop":
			var sh := ShopMenu.new()
			sh._kind = String(_args.get("kind", "any"))
			menu.add_child(sh)
		elif _args.get("screen", "") == "crates":
			var cm := CratesMenu.new()
			menu.add_child(cm)
			if _args.has("open"):
				cm._open(String(_args["open"]).replace("|", ":"))
		elif _args.get("screen", "") == "leaderboard":
			var lb := LeaderboardMenu.new()
			lb._tab = int(_args.get("tab", "0"))
			menu.add_child(lb)
		elif _args.get("screen", "") == "settings":
			var sm := SettingsMenu.new()
			sm.start_tab = int(_args.get("tab", "0"))
			menu.add_child(sm)
		elif _args.get("screen", "") == "net":
			open_net_menu()
		# test helpers for LAN games: net=host [map=<id>] [expect=<players>]   or   net=join [ip=<address>]
		if _args.get("net", "") == "host":
			Net.host_game()
			Game.map_id = String(_args.get("map", "flora_forest"))
			if _args.has("bots"):
				Game.bots_per_team = int(_args["bots"])
			_net_wait = int(_args.get("expect", "1"))
		elif _args.get("net", "") == "join":
			Net.join_game(String(_args.get("ip", "127.0.0.1")))
	_parse_script()


func show_menu() -> void:
	Net.detach()
	if Net.is_client:
		Net.stop()                                           # leaving a joined game
	if netmenu != null:
		netmenu.queue_free()
		netmenu = null
	if current_match != null:
		current_match.queue_free()
		current_match = null
	if armory != null:
		armory.queue_free()
		armory = null
	if menu != null:
		menu.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu = MainMenu.new()
	ui.add_child(menu)
	menu.play_pressed.connect(open_lobby)
	menu.armory_pressed.connect(open_armory)
	menu.net_pressed.connect(open_net_menu)


## LAN game: host or join. The host's START opens the map vote and then the match begins on every machine.
func open_net_menu() -> void:
	if netmenu != null:
		return
	netmenu = NetMenu.new()
	ui.add_child(netmenu)
	netmenu.closed.connect(func() -> void:
		netmenu.queue_free()
		netmenu = null)
	netmenu.start_pressed.connect(func() -> void:
		netmenu.visible = false
		open_lobby()
		lobby.back_pressed.connect(func() -> void:
			if netmenu != null:
				netmenu.visible = true
				menu.visible = false))


func _on_net_start() -> void:
	for n in [netmenu, lobby, armory]:
		if n != null:
			n.queue_free()
	netmenu = null
	lobby = null
	armory = null
	start_match()


func _on_net_lost(reason: String) -> void:
	print("NET lost: ", reason)
	show_menu()


func open_armory() -> void:
	menu.visible = false
	armory = Armory.new()
	ui.add_child(armory)
	armory.closed.connect(func(start: bool) -> void:
		armory.queue_free()
		armory = null
		menu.visible = true
		menu.refresh_class()
		if start:
			start_match())


## The lobby: vote the map from four random ones, then the match starts on the winner.
func open_lobby() -> void:
	if lobby != null:
		return
	menu.visible = false
	lobby = Lobby.new()
	ui.add_child(lobby)
	lobby.back_pressed.connect(func() -> void:
		lobby.queue_free()
		lobby = null
		menu.visible = true)
	lobby.confirmed.connect(func(map_id: String) -> void:
		lobby.queue_free()
		lobby = null
		Game.map_id = map_id
		start_match())


func start_match() -> void:
	Net.host_begin_match()                                   # (does nothing unless this machine hosts a LAN game)
	Game.last_map = Game.map_id
	if netmenu != null:
		netmenu.queue_free()
		netmenu = null
	if menu != null:
		menu.queue_free()
		menu = null
	if current_match != null:
		current_match.queue_free()
	current_match = Match.new()
	current_match.name = "Match"
	add_child(current_match)
	current_match.start(Game.map_id, Game.selected_class)


var _script: Array = []
var _script_i := 0


func _parse_script() -> void:
	# script=<seconds>:<action>[,<seconds>:<action>...]   actions: any input action name, or xp:N, status:ID, crate:RARITY, loot:N, armory, pause, tp:x,y,z
	if not _args.has("script"):
		return
	for item in String(_args["script"]).split(","):
		var kv := item.split(":", true, 1)
		if kv.size() == 2:
			_script.append([float(kv[0]), kv[1]])
	_script.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func _run_script() -> void:
	while _script_i < _script.size() and _t >= float(_script[_script_i][0]):
		var action: String = _script[_script_i][1]
		_script_i += 1
		if action == "dump" and menu != null:
			menu.debug_dump()
			continue
		if action == "lobby":
			open_lobby()
			continue
		if action.begins_with("vote:") and lobby != null:
			lobby.vote(int(action.substr(5)))
			continue
		if action == "startnow" and lobby != null:
			lobby._finish_vote()
			continue
		if action.begins_with("loot:"):
			for i in int(action.substr(5)):
				Game.add_item(Loot.make_gear(["weapon", "armor", "shield"][randi() % 3], Data.rarity_ids[randi() % 6]))
				Game.add_item(Loot.make_rune(Data.rarity_ids[randi() % 6]))
			continue
		var m := current_match
		if m == null:
			continue
		var p := m.player
		if action.begins_with("xp:"):
			Game.add_xp(float(action.substr(3)))
		elif action.begins_with("status:"):
			p.statuses.apply(action.substr(7), 8.0, 2, p)
		elif action.begins_with("crate:"):
			var r := Loot.roll_crate(action.substr(6))
			r["crate_rarity"] = action.substr(6)
			m.hud.show_crate_open(null, r)
		elif action.begins_with("loot:"):
			for i in int(action.substr(5)):
				Game.add_item(Loot.make_gear(["weapon", "armor", "shield"][randi() % 3], Data.rarity_ids[randi() % 6]))
				Game.add_item(Loot.make_rune(Data.rarity_ids[randi() % 6]))
		elif action == "mission":
			m.quests.offer_mission(null)
		elif action.begins_with("quest:"):
			m.quests.offer_quest(null, action.substr(6))
		elif action == "accept":
			m.quests.accept()
		elif action == "castall":
			_cast_all(p)
		elif action.begins_with("endmatch"):
			m._end(action.substr(9) if action.length() > 9 else "red")
		elif action == "armory":
			m.hud.open_armory()
		elif action == "pause":
			m.hud.open_pause()
		elif action == "dump":
			if menu != null:
				menu.debug_dump()
		elif action.begins_with("class:"):
			pass
		elif action.begins_with("hold:"):
			Input.action_press(action.substr(5))
		elif action.begins_with("release:"):
			Input.action_release(action.substr(8))
		elif action.begins_with("weapon:"):
			var item := Loot.make_gear("weapon", "rare")
			item["id"] = action.substr(7)
			Game.add_item(item)
			Game.equip(item)
		elif action == "speed":
			print("SPEED ", snappedf(Vector3(p.velocity.x, 0, p.velocity.z).length(), 0.01), " sprinting ", p.sprinting, " stamina ", snappedf(p.stamina, 0.1), " y ", snappedf(p.global_position.y, 0.1), " vy ", snappedf(p.velocity.y, 0.1), " x ", snappedf(p.global_position.x, 0.1), " z ", snappedf(p.global_position.z, 0.1), " clip ", p.model.anim.current_animation, " anim_speed ", snappedf(p.model.anim.speed_scale, 0.01), " ground_off ", snappedf(p.model._ground_off, 0.001))
		elif action.begins_with("tp:"):
			var q := action.substr(3).replace("|", ",").split(",")           # tp:x|y|z (the script itself is split at commas)
			p.global_position = Vector3(float(q[0]), float(q[1]), float(q[2]))
		elif action.begins_with("edge:"):
			# stand near the map edge (0 = +x, 90 = +z, 180 = -x, 270 = -z) looking outwards, for checking the borders
			var a := deg_to_rad(float(action.substr(5)))
			var dir := Vector3(roundf(cos(a)), 0, roundf(sin(a)))
			var half := m.map_size * 0.5
			var pos := Vector3(dir.x * (half.x - 14.0), 6.0, dir.z * (half.y - 14.0))
			p.global_position = pos
			p.velocity = Vector3.ZERO
			p.yaw = atan2(-dir.x, -dir.z)
			p.pitch = 0.12
		elif action == "climbtest":
			# freeze the player in the climbing pose (as on a ladder, moving up) to look at it
			p.set_physics_process(false)
			p.model.play_state("climb", true)
			p.model.climb_vy = float(_args.get("climb_vy", "1.5"))
			p.model.rotation_degrees.y = float(_args.get("turn", "0"))         # turn=90 shows the pose from the side
			p.yaw = 0.0
			p.pitch = -0.05
			p.arm.spring_length = 2.6
			p.cam.position = Vector3(0.0, 0.0, 0.0)
			p.cam_rig.rotation = Vector3(-0.05, 0.0, 0.0)
		elif action == "tracks":
			var ca: Animation = p.model.anim.get_animation(String(_args.get("clip", "Climb")))
			var names := []
			for t in ca.get_track_count():
				var nm2 := String(ca.track_get_path(t))
				if "upper_arm" in nm2 or "thigh" in nm2:
					names.append("%s type %d keys %d" % [nm2, ca.track_get_type(t), ca.track_get_key_count(t)])
			print("TRACKS ", ca.length, " ", names)
			var skd := p.model.skeleton
			var uai := skd.find_bone("DEF-upper_arm.L")
			var idle: Animation = p.model.anim.get_animation("Idle")
			for t in idle.get_track_count():
				if String(idle.track_get_path(t)).ends_with("DEF-upper_arm.L") and idle.track_get_type(t) == Animation.TYPE_ROTATION_3D:
					print("TRACKQ idle key0 ", idle.track_get_key_value(t, 0), " rest ", skd.get_bone_rest(uai).basis.get_rotation_quaternion(), " pose ", skd.get_bone_pose_rotation(uai))
		elif action == "blends":
			# the fade time of some pairs of clips, and any clip that has no kind in CharacterModel.KIND
			var an := p.model.anim
			var missing: Array = []
			for n in an.get_animation_list():
				if not CharacterModel.KIND.has(n):
					missing.append(n)
			var line := "BLENDS clips %d without a kind %s |" % [an.get_animation_list().size(), str(missing)]
			for pair in [["Idle", "Run"], ["Run", "Sprint"], ["Sprint", "Idle"], ["Run", "MeleeA"], ["MeleeA", "Run"], ["MeleeA", "MeleeB"], ["Run", "HitChest"], ["Idle", "Death"], ["Death", "Revive"],
					["JumpStart", "JumpLoop"], ["JumpLoop", "JumpLand"], ["JumpLand", "Run"], ["Run", "SlideStart"], ["SlideStart", "SlideLoop"], ["SlideLoop", "SlideExit"], ["Idle", "Consume"], ["CastIdle", "CastShoot"]]:
				line += " %s>%s %.2f" % [pair[0], pair[1], an.get_blend_time(pair[0], pair[1])]
			print(line)
		elif action.begins_with("tpnear:"):
			# LAN test: stand `offset` metres along z from the other human player (the host's player for a client, the first joined player for the host), at their height
			var other: Combatant = null
			for oc in m.combatants:
				if oc != p and (oc is RemotePlayer or (oc is NetPuppet and oc.display_name == "Host")):
					other = oc
					break
			if other != null:
				p.global_position = other.global_position + Vector3(0, 0.5, float(action.substr(7)))
				p.velocity = Vector3.ZERO
				p.yaw = 0.0
				p.pitch = -0.1
		elif action.begins_with("tpcrate:"):
			# stand next to the Nth loot crate of the map, facing it; tpcrate:N|distance
			var cq := action.substr(8).split("|")
			if m.crates.size() > 0:
				var cr: Node3D = m.crates[int(cq[0]) % m.crates.size()]
				var cd := float(cq[1]) if cq.size() > 1 else 2.0
				p.global_position = cr.global_position + Vector3(0, 0.6, cd)
				p.velocity = Vector3.ZERO
				p.yaw = 0.0
				p.pitch = 0.1
		elif action.begins_with("perch:"):
			# stand in front of the Nth sniper perch (a pad's distance away, on the floor) looking up at it, for pictures; perch:N|distance
			var pq := action.substr(6).split("|")
			var plist: Array = m.get_meta("perch_list", [])
			if plist.size() > 0:
				var pe: Dictionary = plist[int(pq[0]) % plist.size()]
				var pd: Vector2 = pe["dir"]
				var pdist := float(pq[1]) if pq.size() > 1 else 12.0
				var ppos: Vector3 = pe["pos"]
				p.global_position = Vector3(ppos.x - pd.x * pdist, float(pe["floor"]) + 2.0, ppos.z - pd.y * pdist)
				p.velocity = Vector3.ZERO
				p.yaw = atan2(-pd.x, -pd.y)
				p.pitch = 0.45
				# a free camera looking at the perch from the front and a little to the side, at its own height
				var pc := Camera3D.new()
				m.add_child(pc)
				var pa := Vector3(-pd.y, 0, pd.x)
				pc.global_position = ppos + Vector3(-pd.x * pdist, 1.2, -pd.y * pdist) + pa * pdist * 0.55
				pc.look_at(ppos + Vector3(0, 0.6, 0) + Vector3(pd.x, 0, pd.y) * 0.5)
				pc.fov = 62.0
				pc.current = true
		elif action.begins_with("yaw:"):
			p.yaw = deg_to_rad(float(action.substr(4)))
		elif action.begins_with("pitch:"):
			p.pitch = deg_to_rad(float(action.substr(6)))
		elif action.begins_with("kill_me"):
			p.take_damage(9999.0, null, {"dot": "test"})
		elif InputMap.has_action(action):
			var ev := InputEventAction.new()
			ev.action = action
			ev.pressed = true
			Input.parse_input_event(ev)
			Input.action_press(action)
			get_tree().create_timer(0.15).timeout.connect(func() -> void:
				Input.action_release(action)
				var up := InputEventAction.new()
				up.action = action
				up.pressed = false
				Input.parse_input_event(up))


var _cast_ids: Array = []
var _cast_timer := 0.0
var _cast_player: Player


func _cast_all(p: Player) -> void:
	_cast_player = p
	_cast_ids = Data.skills.keys()
	_cast_timer = 0.0
	print("CASTALL start ", _cast_ids.size())


func _cast_step(delta: float) -> void:
	if _cast_ids.is_empty() or _cast_player == null or not is_instance_valid(_cast_player):
		return
	_cast_timer -= delta
	if _cast_timer > 0.0:
		return
	_cast_timer = 0.35
	var id: String = _cast_ids.pop_front()
	var p := _cast_player
	p.mana = p.max_mana()
	p.cooldowns["s1"] = 0.0
	p.casting_lock = 0.0
	p.health = p.max_health()
	p.set_meta("force_skill", Data.skills[id])
	var enemy := p.nearest_enemy(100.0)
	if enemy != null:
		p.aim_point = enemy.chest_position()
		p.aim_dir = (p.aim_point - p.chest_position()).normalized()
	var ok := SkillRunner.use(p, "s1")
	if _cast_ids.is_empty():
		print("CASTALL done")


func _process(delta: float) -> void:
	_t += delta
	if _net_wait > 0 and Net.peers.size() >= _net_wait and _t > 1.0:
		_net_wait = 0
		start_match()
	_run_script()
	_cast_step(delta)
	if _args.has("shot") and _t > float(_args.get("shot_after", "6")) and not _args.has("_shot_done"):
		_args["_shot_done"] = true
		var img := get_viewport().get_texture().get_image()
		img.save_png(String(_args["shot"]))
		print("SHOT saved ", _args["shot"])
		if not _args.has("keep"):
			get_tree().quit()
	if _args.has("fps") and int(_t) % 3 == 0 and not _args.has("_fps_%d" % int(_t)):
		_args["_fps_%d" % int(_t)] = true
		print("FPS ", Engine.get_frames_per_second(), " t=", int(_t), " draws ", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), " objects ",
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), " tris ", int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			" physics_ms ", snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1), " process_ms ", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1))
	if _args.has("quit_after") and _t > float(_args["quit_after"]):
		if current_match != null:
			var lines: Array = []
			for c in current_match.combatants:
				lines.append("%s(%s,%s,%s) k%d d%d hp%d" % [c.display_name, c.team, c.class_id, String(c.weapon.get("id", "-")), c.kills, c.deaths, int(c.health)])
			print("RESULT score ", current_match.score, " | ", " ; ".join(lines))
		get_tree().quit()
