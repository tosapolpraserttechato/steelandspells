extends SceneTree
## Lists, for every map, which props are used many times (to see which plants and decorations a map has).
func _base(n: String) -> String:
	var at := n.find("@")
	if at >= 0:
		n = n.substr(0, at)
	n = n.split("#")[0]
	var i := n.length()
	while i > 0 and n[i - 1] >= "0" and n[i - 1] <= "9":
		i -= 1
	if i > 0 and i < n.length() and n[i - 1] == "_":
		n = n.substr(0, i - 1)
	return n


func _init() -> void:
	for m in ["chess_arena", "clockwork_mines", "crystal_caves", "desert_tomb", "flora_forest", "frozen_peaks", "moon_sanctuary", "pirate_cove", "shadow_crypt", "sky_islands", "toxic_swamp", "underwater_ocean", "volcano_forge"]:
		var root: Node3D = (load("res://maps/%s/%s.glb" % [m, m]) as PackedScene).instantiate()
		var counts := {}
		for c in root.get_children():
			if c is MeshInstance3D:
				var n := _base(String(c.name))
				counts[n] = int(counts.get(n, 0)) + 1
		var keys := counts.keys()
		keys.sort_custom(func(a, b) -> bool: return counts[a] > counts[b])
		var out := []
		for k in keys:
			if counts[k] >= 6:
				out.append("%s:%d" % [k, counts[k]])
		print("NAMES ", m, " ", ", ".join(out))
		root.free()
	quit()
