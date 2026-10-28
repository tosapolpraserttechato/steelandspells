extends SceneTree
## Prints how far apart the feet are over a clip (is the stride really in the animation?).  godot --headless --script res://tests/foot_probe.gd -- druid Run
func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cls: String = args[0] if args.size() > 0 else "druid"
	var clip: String = args[1] if args.size() > 1 else "Run"
	var root: Node3D = (load("res://models/classes/class_%s.glb" % cls) as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	print("CLIPS ", ap.get_animation_list())
	var fl := skel.find_bone("DEF-foot.L")
	var fr := skel.find_bone("DEF-foot.R")
	ap.play(clip)
	ap.pause()
	var len := ap.get_animation(clip).length
	var out := []
	for i in 12:
		ap.seek(len * float(i) / 12.0, true)
		await process_frame
		var a := skel.get_bone_global_pose(fl).origin
		var b := skel.get_bone_global_pose(fr).origin
		out.append("%.2f/%.2f" % [a.z - b.z, a.y - b.y])
	print("FEET ", cls, " ", clip, " len ", snappedf(len, 0.01), " dz/dy ", " ".join(out))
	quit()
