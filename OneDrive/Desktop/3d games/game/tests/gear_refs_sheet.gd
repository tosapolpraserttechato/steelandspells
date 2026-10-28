extends Node
## A contact sheet of the generated reference pictures whose file name starts with a prefix:
##   godot --path game res://tests/gear_refs_sheet.tscn --resolution 640x360 -- prefix=set_01 cols=5 out=gear_refs_set01
var _frames := 0
var _vp: SubViewport
var _out := "gear_refs"

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = String(args.get("out", "gear_refs"))
	var cols := int(args.get("cols", "5"))
	var cell := float(args.get("cell", "300"))
	var dir := ProjectSettings.globalize_path("res://").path_join("../asset_refs/" + String(args.get("dir", "gear")))
	var files: Array = []
	var only := String(args.get("only", ""))                                  # a comma list of exact file names (without extension) overrides the prefix
	for f in DirAccess.get_files_at(dir):
		var base: String = String(f).get_basename()
		if (f.ends_with(".jpg") or f.ends_with(".png")) and ((only != "" and base in only.split(",")) or (only == "" and f.begins_with(String(args.get("prefix", ""))))):
			files.append(f)
	files.sort()
	var rows := int(ceil(float(files.size()) / float(cols)))
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(cols * (cell + 6)) + 16, int(rows * (cell + 30)) + 16)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13)
	bg.size = Vector2(_vp.size)
	_vp.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.position = Vector2(8, 8)
	grid.add_theme_constant_override("h_separation", 6)
	_vp.add_child(grid)
	for f in files:
		var v := VBoxContainer.new()
		var l := Label.new()
		l.text = String(f).get_basename().replace("set_", "").replace("__", "  ")
		l.add_theme_font_size_override("font_size", 13)
		v.add_child(l)
		var img := Image.load_from_file(dir.path_join(f))
		if img != null:
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.custom_minimum_size = Vector2(cell, cell)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			v.add_child(tr)
		grid.add_child(v)

func _process(_d: float) -> void:
	_frames += 1
	if _frames == 6:
		_vp.get_texture().get_image().save_png("res://shots/%s.png" % _out)
		print("REFS saved ", _out)
		get_tree().quit()
