extends Node
## Stitches single reference pictures (one tile cut out of a saved Google Images screenshot) into one labelled sheet, 4 per row:
##   godot --path game res://tests/armor_picks_sheet.tscn --resolution 640x360
## Every picture is a Meshy AI "Free ... 3D Models" concept image: the same clean full-body look on white. [label, file id, column of the three tiles (0 left, 1 middle, 2 right)]
const BASE := "C:/Users/Nalinee/.claude/projects/C--Users-Nalinee-OneDrive-Desktop-3d-games/2881e86a-cb3a-4015-b3f0-ad3283f9bf74/tool-results/mcp-Claude_Browser-blob-%s.png"
const PICKS := [
	["PLATE: helmet", "1793148344018-pgg3g3", 0], ["PLATE: chestplate", "1793148344019-ys2g76", 0], ["PLATE: shield", "1793148344019-0dbyvj", 1], ["PLATE: greaves", "1793148354895-a20s04", 0],
	["PLATE: boots (weak)", "1793148354896-a0ol9o", 1],
]
const CELL := Vector2(290, 400)
var _frames := 0
var _vp: SubViewport

func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(CELL.x) * 4 + 20, int(CELL.y) * 4 + 60)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.size = Vector2(_vp.size)
	_vp.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.position = Vector2(8, 8)
	_vp.add_child(grid)
	for p in PICKS:
		var cell := VBoxContainer.new()
		var l := Label.new()
		l.text = p[0]
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		cell.add_child(l)
		var img := Image.load_from_file(BASE % p[1])
		if img != null:
			var at := AtlasTexture.new()
			at.atlas = ImageTexture.create_from_image(img)
			at.region = Rect2(float(p[2]) * 192.0, 0.0, 184.0, 264.0)
			var tr := TextureRect.new()
			tr.texture = at
			tr.custom_minimum_size = Vector2(276, 396)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cell.add_child(tr)
		grid.add_child(cell)

func _process(_d: float) -> void:
	_frames += 1
	if _frames == 6:
		_vp.get_texture().get_image().save_png("res://shots/armor_plate_pieces.png")
		print("PICKS saved")
		get_tree().quit()
