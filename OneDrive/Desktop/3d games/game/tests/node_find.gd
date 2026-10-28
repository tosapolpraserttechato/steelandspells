extends SceneTree
## Prints the nodes of a map's GLB whose name contains a word.  godot --headless --script res://tests/node_find.gd -- desert_tomb door
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var root: Node3D = (load("res://maps/%s/%s.glb" % [a[0], a[0]]) as PackedScene).instantiate()
	for c in root.get_children():
		if String(c.name).contains(a[1]):
			var p := (c as Node3D).global_position if c is Node3D else Vector3.ZERO
			var box := ""
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				box = str((c as MeshInstance3D).mesh.get_aabb().size.snapped(Vector3(0.1, 0.1, 0.1)))
			print("NODE ", c.name, " ", c.get_class(), " at ", p.snapped(Vector3(0.1, 0.1, 0.1)), " size ", box)
	quit()
