extends SceneTree
## Lists every skill with the glyph chosen for it, so duplicate icons can be found.
func _init() -> void:
	var IA = load("res://scripts/ui/IconArt.gd")
	var skills: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	var by_glyph: Dictionary = {}
	var lines: PackedStringArray = []
	for sk in skills:
		var g: String = IA.glyph_for_skill(sk)
		var sts: Array = sk["fx"].get("sts", [])
		var st := ""
		for s in sts:
			st += String(s["id"]) + ","
		lines.append("%s|%s|%s|%s|%s|%s" % [sk["id"], sk["name"], sk["class"], sk["fx"]["t"], st, g])
		if not by_glyph.has(g):
			by_glyph[g] = []
		by_glyph[g].append(sk["name"])
	var f := FileAccess.open("res://shots/skill_glyphs.txt", FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.store_string("\n\n")
	for g in by_glyph:
		f.store_string("%s (%d): %s\n" % [g, by_glyph[g].size(), ", ".join(by_glyph[g])])
	f.close()
	print("DONE skills=", skills.size())
	quit()
