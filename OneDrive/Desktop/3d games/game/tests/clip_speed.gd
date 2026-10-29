extends SceneTree
## How fast the ground slides under the planted foot in a locomotion clip, in world metres per second (so it can be compared with how fast the fighter really moves).
##   godot --headless --path game --script res://tests/clip_speed.gd -- [druid arcanist ...]
const CLIPS := ["Run", "Sprint", "Walk"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var classes: Array = OS.get_cmdline_user_args()
	if classes.is_empty():
		classes = ["druid", "arcanist", "time_mage", "flame_lord"]
	var cfgs := {}
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json")):
		cfgs[c["id"]] = c
	for cls in classes:
		var root: Node3D = (load("res://models/classes/class_%s.glb" % cls) as PackedScene).instantiate()
		get_root().add_child(root)
		await process_frame
		var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		var size: float = float(cfgs[cls]["stats"]["size"])
		var fl := skel.find_bone("DEF-foot.L")
		var fr := skel.find_bone("DEF-foot.R")
		var hip := skel.find_bone("DEF-hips")
		var feet_bones := [skel.find_bone("DEF-foot.L"), skel.find_bone("DEF-foot.R"), skel.find_bone("DEF-toe.L"), skel.find_bone("DEF-toe.R")]
		var lat_axis: Vector3 = skel.get_bone_global_rest(skel.find_bone("DEF-thigh.R")).origin - skel.get_bone_global_rest(skel.find_bone("DEF-thigh.L")).origin
		lat_axis.y = 0.0
		lat_axis = lat_axis.normalized()
		var rest_sep: float = absf((skel.get_bone_global_rest(fr).origin - skel.get_bone_global_rest(fl).origin).dot(lat_axis))
		ap.play("Idle")
		ap.pause()
		ap.seek(0.0, true)
		await process_frame
		var idle_low := 1e9
		for b in feet_bones:
			idle_low = minf(idle_low, skel.get_bone_global_pose(b).origin.y)
		for clip in CLIPS:
			var len := ap.get_animation(clip).length
			var n := 48
			var rel: Array = []
			var ys: Array = []
			var lows: Array = []
			var min_sep := 1e9
			ap.play(clip)
			ap.pause()
			for i in n + 1:
				ap.seek(len * float(i) / float(n), true)
				await process_frame
				var h := skel.get_bone_global_pose(hip).origin
				var l := skel.get_bone_global_pose(fl).origin - h
				var r := skel.get_bone_global_pose(fr).origin - h
				rel.append([Vector2(l.x, l.z), Vector2(r.x, r.z)])
				ys.append([skel.get_bone_global_pose(fl).origin.y, skel.get_bone_global_pose(fr).origin.y])
				var low := 1e9
				for b in feet_bones:
					low = minf(low, skel.get_bone_global_pose(b).origin.y)
				lows.append(low - idle_low)
				min_sep = minf(min_sep, absf((skel.get_bone_global_pose(fr).origin - skel.get_bone_global_pose(fl).origin).dot(lat_axis)))
			# the planted foot: for each foot the frames where it is lowest; its horizontal speed relative to the hips is the ground speed the clip assumes
			var speeds: Array = []
			for f in 2:
				var ymin := 1e9
				for i in n + 1:
					ymin = minf(ymin, float(ys[i][f]))
				for i in n:
					if float(ys[i][f]) < ymin + 0.06 and float(ys[i + 1][f]) < ymin + 0.06:
						speeds.append((rel[i + 1][f] - rel[i][f]).length() / (len / float(n)))
			speeds.sort()
			var med: float = float(speeds[speeds.size() / 2]) if not speeds.is_empty() else 0.0
			var swing := 0.0
			for i in n + 1:
				swing = maxf(swing, absf(rel[i][0].y - rel[i][1].y))
			var lift_min := 1e9
			var lift_avg := 0.0
			for v in lows:
				lift_min = minf(lift_min, float(v))
				lift_avg += float(v) / float(lows.size())
			print("CLIPLIFT ", cls, " ", clip, " lowest foot vs standing: best ", snappedf(lift_min * size, 0.01), " m, average ", snappedf(lift_avg * size, 0.01), " m (positive = above the ground)")
			print("CLIPSEP ", cls, " ", clip, " closest the feet get sideways ", snappedf(min_sep * size, 0.01), " m (standing: ", snappedf(rest_sep * size, 0.01), " m)")
			print("CLIPSPEED ", cls, " ", clip, " length ", snappedf(len, 0.01), " s  planted-foot speed ", snappedf(med * size, 0.1), " m/s (size ", size, ")  foot spread ", snappedf(swing * size, 0.01), " m  steps/s ", snappedf(2.0 / len, 0.01))
		root.queue_free()
	quit()
