extends SceneTree
## Joins pictures into one contact sheet.  godot --headless --path game --script res://tests/montage.gd -- out=name cols=2 w=640 file1.png file2.png ...   (files are under res://shots/)
func _init() -> void:
	var out := "montage"
	var cols := 2
	var w := 640
	var files: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("cols="):
			cols = int(a.substr(5))
		elif a.begins_with("w="):
			w = int(a.substr(2))
		else:
			files.append(a)
	var h := int(w * 9.0 / 16.0)
	var rows := int(ceil(float(files.size()) / cols))
	var sheet := Image.create(cols * w, rows * h, false, Image.FORMAT_RGB8)
	for i in files.size():
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://shots/" + files[i]))
		if img == null or img.is_empty():
			continue
		img.convert(Image.FORMAT_RGB8)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/%s.png" % out))
	quit()
