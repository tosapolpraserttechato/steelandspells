extends SceneTree
func _init() -> void:
	var packed: PackedScene = load("res://models/classes/class_druid.glb")
	var root := packed.instantiate()
	var sk: Skeleton3D = null
	for n in root.find_children("*", "Skeleton3D", true, false):
		sk = n
	var i := sk.find_bone("DEF-hand.R")
	var pose := sk.get_bone_global_rest(i)
	print("HAND basis x=", pose.basis.x, " y=", pose.basis.y, " z=", pose.basis.z, " origin=", pose.origin)
	var j := sk.find_bone("DEF-forearm.R")
	print("FOREARM origin=", sk.get_bone_global_rest(j).origin)
	for path in ["res://models/weapons/cz/Magic staff.fbx", "res://models/weapons/med/Sword_2.fbx", "res://models/weapons/med/Bow_Wooden.fbx", "res://models/weapons/rpg/Book1_Closed.fbx", "res://models/weapons/rpg/Crystal1.fbx", "res://models/weapons/kay/staff_A.gltf", "res://models/weapons/cz/Longsword.fbx", "res://models/weapons/med/Dagger.fbx"]:
		var w: Node3D = (load(path) as PackedScene).instantiate()
		var box := AABB()
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			box = box.merge((mi as MeshInstance3D).get_aabb() * (mi as MeshInstance3D).transform)
		print("WEAPON ", path.get_file(), " aabb pos=", box.position, " size=", box.size)
	quit()
