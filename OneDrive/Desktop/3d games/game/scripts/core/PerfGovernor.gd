class_name PerfGovernor
extends Node
## Keeps the game playable on a weak computer. Every second or so it looks at the frame rate:
##  - under about 30 fps it draws the 3D picture at a smaller size (down to 55%) and stretches it to the window; the interface stays sharp; above 58 fps it grows back to full size;
##  - fighters far from the player stop casting shadows (a character is drawn twice when it casts one: once for the shadow and once for the picture);
## Off for screenshots and tests (shot= argument or NO_PERF=1) so their pictures stay clean; "Settings > auto_resolution" turns the first part off.
const MIN_SCALE := 0.55
const SHADOW_RANGE := 42.0

var m: Match
var _acc := 0.0
var _frames := 0
var _scale := 1.0
var _enabled := true


func setup(match_ref: Match) -> void:
	m = match_ref
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			_enabled = false
	if OS.get_environment("NO_PERF") != "":
		_enabled = false


func _process(delta: float) -> void:
	if not _enabled:
		return
	_acc += delta
	_frames += 1
	if _acc < 1.2:
		return
	var fps := float(_frames) / _acc
	_acc = 0.0
	_frames = 0
	var vp := get_viewport()
	if bool(Settings.v.get("auto_resolution", true)):
		if fps < 30.0 and _scale > MIN_SCALE:
			_scale = maxf(MIN_SCALE, _scale - (0.1 if fps < 18.0 else 0.06))
		elif fps > 58.0 and _scale < 1.0:
			_scale = minf(1.0, _scale + 0.05)
		if absf(_scale - vp.scaling_3d_scale) > 0.009:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = _scale
			if OS.get_environment("PERF_DEBUG") != "":
				print("PERF fps ", snappedf(fps, 0.1), " render scale ", snappedf(_scale, 0.01))
	_far_shadows()


func _exit_tree() -> void:
	if get_viewport() != null:
		get_viewport().scaling_3d_scale = 1.0


func _far_shadows() -> void:
	if m == null or m.player == null or not is_instance_valid(m.player):
		return
	var here := m.player.global_position
	for c in m.combatants:
		if not is_instance_valid(c) or c == m.player or c.model == null:
			continue
		var far := c.global_position.distance_to(here) > SHADOW_RANGE
		var want := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for mi in c.model.meshes:
			if is_instance_valid(mi) and (mi as GeometryInstance3D).cast_shadow != want:
				(mi as GeometryInstance3D).cast_shadow = want
