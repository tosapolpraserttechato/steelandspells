extends SceneTree

# godot --headless --path game --script res://tests/inspect_map.gd -- desert_tomb
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if args.size() > 0 else "desert_tomb"
	var packed: PackedScene = load("res://maps/%s/%s.glb" % [name, name])
	var root := packed.instantiate()
	var counts := {}
	var examples := {}
	var stack: Array = [root]
	var total := 0
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		total += 1
		var key := n.get_class()
		counts[key] = counts.get(key, 0) + 1
		if not examples.has(key) or examples[key].size() < 4:
			if not examples.has(key):
				examples[key] = []
			examples[key].append(n.name)
		for c in n.get_children():
			stack.append(c)
	print("TOTAL ", total)
	print("COUNTS ", counts)
	print("EXAMPLES ", examples)
	print("ROOT children ", root.get_child_count(), " first: ", root.get_child(0).name if root.get_child_count() > 0 else "")
	for c in root.get_children().slice(0, 12):
		var extra := ""
		if c.has_meta("extras"):
			extra = str(c.get_meta("extras"))
		print("  ", c.name, " ", c.get_class(), " ", (c as Node3D).position if c is Node3D else "", " ", extra)
	# markers
	for c in root.get_children():
		if c.name.begins_with("capture_A") or c.name.begins_with("team_red_spawn_1") or c.name == "bounds":
			print("MARKER ", c.name, " ", c.get_class(), " pos ", (c as Node3D).position, " meta ", c.get_meta_list())
			if c.has_meta("extras"):
				print("   extras ", c.get_meta("extras"))
	quit()
