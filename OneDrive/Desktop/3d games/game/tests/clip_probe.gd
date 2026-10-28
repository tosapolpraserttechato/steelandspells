extends Node3D
func _ready() -> void:
	var m := CharacterModel.new()
	add_child(m)
	m.setup("druid", 1.0, "red", "", true)
	await get_tree().process_frame
	for clip in ["MeleeC", "MeleeA", "MeleeB", "Attack", "MeleeCombo", "Hook", "Throw", "CastShoot"]:
		m.anim.play(clip)
		for f in [0.1, 0.4, 0.8, 1.2]:
			m.anim.seek(f, true)
			await get_tree().process_frame
			var hips := m.skeleton.find_bone("DEF-hips")
			var p: Vector3 = m.skeleton.get_bone_global_pose(hips).origin
			print("PROBE ", clip, " t=", f, " hips=", p)
	get_tree().quit()
