extends SceneTree
func _init() -> void:
	for p in ["res://models/weapons/bev/med_Claymore.glb", "res://models/weapons/bev/cz_Longsword.glb"]:
		var r = load(p)
		print(p, " -> ", r)
		if r is PackedScene:
			var n: Node = r.instantiate()
			var cnt := 0
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				cnt += 1
				print("  mesh ", mi.name, " aabb ", (mi as MeshInstance3D).get_aabb(), " visible ", mi.visible)
			print("  meshes ", cnt)
	quit()
