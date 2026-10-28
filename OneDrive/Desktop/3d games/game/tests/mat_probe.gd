extends SceneTree
## Prints the material settings of a map object.  godot --headless --script res://tests/mat_probe.gd -- flora_forest path_center_red
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var root: Node3D = (load("res://maps/%s/%s.glb" % [a[0], a[0]]) as PackedScene).instantiate()
	for c in root.get_children():
		if String(c.name).begins_with(a[1]) and c is MeshInstance3D:
			var m := (c as MeshInstance3D).mesh
			for s in m.get_surface_count():
				var mat := m.surface_get_material(s)
				if mat is BaseMaterial3D:
					var b := mat as BaseMaterial3D
					print("MAT ", c.name, " s", s, " ", b.resource_name, " albedo_tex ", b.albedo_texture, " normal ", b.normal_enabled, " scale ", b.normal_scale, " tex ", b.normal_texture, " rough ", b.roughness, " transp ", b.transparency, " vcol ", b.vertex_color_use_as_albedo, " uv ", b.uv1_scale)
			break
	quit()
