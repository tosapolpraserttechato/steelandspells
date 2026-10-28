extends Node
## Finds, for every weapon family, a way to hold the weapon (small offset and pitch change) so that it does not go through any class's body in the idle pose.
## The body is a set of capsules along the skeleton (spine, head, legs, left arm, cloth bones); the weapon is a line of points along its long axis.
##   godot --headless --path game res://tests/hold_fit.tscn
const OFFSETS := [-0.08, -0.04, 0.0, 0.04, 0.08]
const PITCH_DELTAS := [-10.0, 0.0, 10.0, 20.0, 30.0]
const WANT := 0.035                # clearance (m) that counts as clean

var _classes: Array = []


func _ready() -> void:
	for cls in Data.class_order:
		_classes.append(_load_class(cls))
	var fams := {}
	for w in Data.weapons.values():
		if not fams.has(w["family"]):
			fams[w["family"]] = w
	var report: PackedStringArray = []
	for fam in fams:
		var info := Weapons.visual_for(fams[fam])
		var base_pitch: float = float(info.get("pitch", 40.0))
		var length: float = float(info["length"])
		var grip: float = float(info["grip"])
		var cur := _worst(info, Vector3(info.get("offset", Vector3.ZERO)), base_pitch, length, grip)
		var best_score := -999.0
		var best := {}
		for gm in [1.0, 0.75, 0.5]:
			for dx in OFFSETS:
				for dy in OFFSETS:
					for dz in OFFSETS:
						for dp in PITCH_DELTAS:
							var off := Vector3(dx, dy, dz) + Vector3(info.get("offset", Vector3.ZERO))
							var c := _worst(info, off, base_pitch + dp, length, grip * gm)
							var score := minf(c, WANT) - 0.6 * Vector3(dx, dy, dz).length() - 0.0007 * absf(dp) - 0.05 * (1.0 - gm)
							if score > best_score:
								best_score = score
								best = {"offset": off, "pitch": base_pitch + dp, "clear": c, "grip": grip * gm}
		report.append("%s: now %.3f m clear -> best offset %s pitch %.0f grip %.2f (was %.2f) (clear %.3f)" % [fam, cur, best["offset"], best["pitch"], best["grip"], grip, best["clear"]])
		print("FIT ", report[report.size() - 1])
	var f := FileAccess.open("res://shots/hold_fit.txt", FileAccess.WRITE)
	f.store_string("\n".join(report))
	f.close()
	get_tree().quit()


## Clearance of the weapon from the body: the smallest (distance - body radius) over every point of the weapon and every class (negative = through the body).
func _worst(info: Dictionary, offset: Vector3, pitch: float, length: float, grip: float) -> float:
	var tilt := Basis(Vector3(1, 0, 0), deg_to_rad(180.0 + pitch))
	var roll := Basis(Vector3(0, 1, 0), deg_to_rad(float(info.get("roll", 0.0))))
	var hb := tilt * roll
	var worst := 99.0
	var pts: Array = []
	for i in 13:
		var s := lerpf(-grip * length, (1.0 - grip) * length, float(i) / 12.0)
		if absf(s) > 0.1:                 # the part in the fist does not count
			pts.append(offset + hb * Vector3(0, s, 0))
	for cd in _classes:
		var hand: Transform3D = cd["hand"]
		for p in pts:
			var wp: Vector3 = hand * p
			for cap in cd["caps"]:
				var d := _seg_dist(wp, cap[0], cap[1]) - float(cap[2]) - 0.02
				worst = minf(worst, d)
	return worst


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _load_class(cls: String) -> Dictionary:
	var root: Node3D = (load("res://models/classes/class_%s.glb" % cls) as PackedScene).instantiate()
	add_child(root)
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play("Idle")
	ap.seek(0.0, true)
	ap.pause()
	var pos := func(n: String) -> Vector3:
		var i := skel.find_bone(n)
		return skel.get_bone_global_pose(i).origin if i >= 0 else Vector3.ZERO
	var caps: Array = []
	var chain := ["DEF-hips", "DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-head"]
	var radii := [0.15, 0.14, 0.14, 0.14, 0.06, 0.1]
	for i in chain.size() - 1:
		caps.append([pos.call(chain[i]), pos.call(chain[i + 1]), radii[i]])
	var head: Vector3 = pos.call("DEF-head")
	caps.append([head, head + Vector3(0, 0.18, 0), 0.1])
	for side in ["L", "R"]:
		caps.append([pos.call("DEF-thigh." + side), pos.call("DEF-shin." + side), 0.095])
		caps.append([pos.call("DEF-shin." + side), pos.call("DEF-foot." + side), 0.06])
	caps.append([pos.call("DEF-upper_arm.L"), pos.call("DEF-forearm.L"), 0.055])
	caps.append([pos.call("DEF-forearm.L"), pos.call("DEF-hand.L"), 0.05])
	# the holding (right) arm: only the upper arm counts, the hand holds the weapon
	caps.append([pos.call("DEF-shoulder.R"), pos.call("DEF-upper_arm.R"), 0.06])
	var hand_i := skel.find_bone("DEF-hand.R")
	var hand_t := skel.get_bone_global_pose(hand_i)
	root.queue_free()
	return {"hand": hand_t, "caps": caps}
