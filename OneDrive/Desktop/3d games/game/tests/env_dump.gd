extends SceneTree
func _init() -> void:
	var maps = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps.json"))
	var arr: Array = maps if maps is Array else maps.values()
	for m in arr:
		print("ENV ", m.get("id", "?"), " ", JSON.stringify(m.get("env", {})))
	quit()
