extends SceneTree
## The model in its rest pose with a ball on every important bone, to see whether the skeleton fits the body.  godot --path game --script res://tests/skel_overlay.gd -- necromancer
var _t := 0.0
var _out := "skel"


func _init() -> void:
	var cls: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "necromancer"
	_out = "skel_" + cls
	var root := get_root()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 1.0)
	e.ambient_light_energy = 1.0
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 20, 0)
	root.add_child(sun)
	var model: Node3D = (load("res://models/classes/class_%s.glb" % cls) as PackedScene).instantiate()
	root.add_child(model)
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	skel.reset_bone_poses()
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	ap.stop()
	var cols := {"arm": Color(1, 0.2, 0.2), "hand": Color(1, 0.6, 0.1), "thigh": Color(0.2, 0.5, 1), "shin": Color(0.2, 0.9, 1), "foot": Color(0.3, 1, 0.4), "spine": Color(1, 1, 0.2), "head": Color(1, 0.3, 1), "hips": Color(1, 1, 1)}
	for i in skel.get_bone_count():
		var nm := skel.get_bone_name(i)
		var key := ""
		if nm.contains("upper_arm") or nm.contains("forearm"):
			key = "arm"
		elif nm.contains("hand"):
			key = "hand"
		elif nm.contains("thigh"):
			key = "thigh"
		elif nm.contains("shin"):
			key = "shin"
		elif nm.contains("foot"):
			key = "foot"
		elif nm.contains("spine"):
			key = "spine"
		elif nm == "DEF-head":
			key = "head"
		elif nm == "DEF-hips":
			key = "hips"
		if key == "":
			continue
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.04
		sm.height = 0.08
		ball.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cols[key]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		ball.material_override = mat
		ball.position = skel.global_transform * skel.get_bone_global_rest(i).origin
		root.add_child(ball)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 0.95, 3.2)
	cam.fov = 40


func _process(delta: float) -> bool:
	_t += delta
	if _t > 1.2:
		get_root().get_texture().get_image().save_png("res://shots/%s.png" % _out)
		quit()
	return false
