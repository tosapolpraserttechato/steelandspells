extends SceneTree
## Cuts the chosen picture of each weapon out of a Perchance screenshot (two pictures side by side) into asset_refs/weapons_real/<weapon id>.jpg (1024 x 1024, RGB).
## Entries: [weapon id, screenshot file, side ("L", "R" or "ALL" for a screenshot that already holds one picture)]. Run:
##   godot --headless --path game --script res://tools/crop_weapon_refs.gd
const SHOTS := "C:/Users/Nalinee/.claude/projects/C--Users-Nalinee-OneDrive-Desktop-3d-games/2881e86a-cb3a-4015-b3f0-ad3283f9bf74/tool-results/mcp-claude-in-chrome-blob-"
const OUT := "C:/Users/Nalinee/OneDrive/Desktop/3d games/asset_refs/weapons_real/"
const LIST := [
	["ember_staff", "1793168186992-i2z2bv.png", "ALL"],
	["frost_staff", "1793168282278-mezgfj.png", "PR"],
	["storm_staff", "1793168332197-iavd4a.png", "PR"],
	["nature_staff", "1793168381657-y1fg3h.jpg", "R"],
	["bone_staff", "1793168429665-y3bmep.jpg", "R"],
	["trident_staff", "1793168477206-zztahv.jpg", "L"],
	["arcane_wand", "1793168525682-0i5aun.jpg", "R"],
	["venom_wand", "1793168595310-g6o9fx.jpg", "R"],
	["hand_crossbow", "1793168666675-1n5dsx.jpg", "L"],
	["chrono_orb", "1793168713400-usvy49.jpg", "R"],
	["star_orb", "1793168763956-lntgn9.jpg", "L"],
	["twin_daggers", "1793168813001-hecssm.jpg", "R"],
]


func _init() -> void:
	for e in LIST:
		var img := Image.load_from_file(SHOTS + String(e[1]))
		if img == null:
			print("MISSING ", e[0])
			continue
		var r := Rect2i(0, 0, img.get_width(), img.get_height())
		match String(e[2]):
			"L": r = Rect2i(306, 87, 451, 450)
			"R": r = Rect2i(765, 87, 450, 450)
			"PL": r = Rect2i(0, 0, 563, 563)                       # a saved pair of two 563 px pictures
			"PR": r = Rect2i(572, 0, 563, 563)
		var out := Image.create(r.size.x, r.size.y, false, img.get_format())
		out.blit_rect(img, r, Vector2i.ZERO)
		out.convert(Image.FORMAT_RGB8)
		out.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
		out.save_jpg(OUT + String(e[0]) + ".jpg", 0.93)
		print("CROP ", e[0], " ", r)
	quit()
