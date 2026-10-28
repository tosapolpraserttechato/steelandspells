class_name ClothDamp
extends RefCounted
## The cloth bones of capes and skirts swing hard in the running clips; pulling their rotations part of the way back to the rest pose (strength 1 = untouched)
## keeps the cloth from being torn apart by the stride. Done once per animation (the animations are shared by every fighter of a class).
const RUN_CLIPS := ["Run", "Sprint"]


## Applies a class's "run_calm" entry (data/classes.json): {"cloth": 0.45, "legs": 1, "feet": legs, "arms": 1, "spine": 1}, all optional. Cloth is the strength kept of the cape / skirt bones;
## the others shorten the swing of the legs, arms and spine in the running clips. The RUN_CALM environment variable ("legs=0.2,arms=0.5,cloth=0") overrides it for tests.
static func apply(skel: Skeleton3D, player: AnimationPlayer, cfg: Dictionary) -> void:
	var env := OS.get_environment("RUN_CALM")
	if env != "":
		cfg = {}
		for kv in env.split(","):
			cfg[kv.get_slice("=", 0)] = float(kv.get_slice("=", 1))
	damp(skel, player, RUN_CLIPS, float(cfg.get("cloth", 0.45)))
	if cfg.has("hair"):
		damp(skel, player, RUN_CLIPS, float(cfg["hair"]), ["hair"])
	var legs := float(cfg.get("legs", 1.0))
	var arms := float(cfg.get("arms", 1.0))
	var spine := float(cfg.get("spine", 1.0))
	var feet := float(cfg.get("feet", legs))
	if legs < 1.0 or arms < 1.0 or spine < 1.0 or feet < 1.0:
		calm(player, RUN_CLIPS, {"DEF-thigh": legs, "DEF-shin": legs, "DEF-foot": feet, "DEF-toe": feet, "DEF-upper_arm": arms, "DEF-forearm": arms, "DEF-hand": arms, "DEF-spine": spine})


static func damp(skel: Skeleton3D, player: AnimationPlayer, clips: Array, strength: float, prefixes: Array = ["cloth_cape", "cloth_skirt"]) -> void:
	var meta := "damped_" + String(prefixes[0])
	for clip in clips:
		if not player.has_animation(clip):
			continue
		var an: Animation = player.get_animation(clip)
		if an.has_meta(meta):
			continue
		an.set_meta(meta, true)
		for t in an.get_track_count():
			if an.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := String(an.track_get_path(t)).get_slice(":", 1)
			var wanted := false
			for p in prefixes:
				wanted = wanted or bone.begins_with(String(p))
			if not wanted:
				continue
			var bi := skel.find_bone(bone)
			if bi < 0:
				continue
			var rest: Quaternion = skel.get_bone_rest(bi).basis.get_rotation_quaternion()
			for k in an.track_get_key_count(t):
				var q: Quaternion = an.track_get_key_value(t, k)
				an.track_set_key_value(t, k, rest.slerp(q, strength).normalized())


## Long robes and cloaks are glued to the legs of the mesh, so a wide stride tears them: this shortens the swing of the legs (thighs, shins, feet), the arms and the spine by
## pulling every key towards the mean pose of the clip (factor 1 = untouched, 0 = frozen in the average pose). `factors` maps a bone name prefix to its factor, for example
## {"DEF-thigh": 0.3, "DEF-upper_arm": 0.6}.
static func calm(player: AnimationPlayer, clips: Array, factors: Dictionary) -> void:
	for clip in clips:
		if not player.has_animation(clip):
			continue
		var an: Animation = player.get_animation(clip)
		if an.has_meta("calmed"):
			continue
		an.set_meta("calmed", true)
		for t in an.get_track_count():
			if an.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := String(an.track_get_path(t)).get_slice(":", 1)
			var factor := -1.0
			for prefix in factors:
				if bone.begins_with(String(prefix)):
					factor = float(factors[prefix])
			if factor < 0.0:
				continue
			var first: Quaternion = an.track_get_key_value(t, 0)
			var sum := Vector4.ZERO
			for k in an.track_get_key_count(t):
				var q: Quaternion = an.track_get_key_value(t, k)
				if q.dot(first) < 0.0:
					q = -q
				sum += Vector4(q.x, q.y, q.z, q.w)
			var m := Quaternion(sum.x, sum.y, sum.z, sum.w).normalized()
			for k in an.track_get_key_count(t):
				var q: Quaternion = an.track_get_key_value(t, k)
				if q.dot(m) < 0.0:
					q = -q
				an.track_set_key_value(t, k, m.slerp(q, factor).normalized())
