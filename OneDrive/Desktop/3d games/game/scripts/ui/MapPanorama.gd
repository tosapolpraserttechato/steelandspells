class_name MapPanorama
extends Control
## The title-screen background: the real maps, one after another, seen from a camera that turns slowly on the spot (a panorama), with their flowers, trees and
## little animals. It fades through black between maps and names each one. Built with MapLoader.ground_only (only the ground has collision) so it loads quickly.

const SHOW_SECS := 20.0
const TURN := 0.07                        # radians per second: a full turn takes about 90 seconds

## Critters.gd asks its host for the fighters to run from: there are none here.
class Stage extends Node3D:
	var combatants: Array = []

var _vp: SubViewport
var _cam: Camera3D
var _stage: Stage
var _order: Array = []
var _next := 0
var _yaw := 0.0
var _pos := Vector3.ZERO
var _cur_id := ""
var _timer := 0.0
var _bob := 0.0
var _busy := false
var _fade: ColorRect
var _caption: Label
var _caption_sub: Label


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var cont := SubViewportContainer.new()
	cont.stretch = true
	UiKit.full_rect(cont)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cont)
	_vp = SubViewport.new()                  # shares the main 3D world: the ground rays used by the flowers and animals need the real physics space
	_vp.handle_input_locally = false
	_vp.audio_listener_enable_3d = false
	cont.add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 74.0
	_cam.far = 700.0
	_vp.add_child(_cam)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	UiKit.full_rect(_fade)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_caption = UiKit.label("", 26, Color(1.0, 0.9, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
	_caption.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_caption.anchor_left = 1.0
	_caption.anchor_right = 1.0
	_caption.offset_left = -460
	_caption.offset_right = -34
	_caption.offset_top = 22
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06, 0.95))
	_caption.add_theme_constant_override("outline_size", 9)
	add_child(_caption)
	_caption_sub = UiKit.label("", 14, Color(0.85, 0.82, 0.95), HORIZONTAL_ALIGNMENT_RIGHT)
	_caption_sub.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_caption_sub.anchor_left = 1.0
	_caption_sub.anchor_right = 1.0
	_caption_sub.offset_left = -460
	_caption_sub.offset_right = -34
	_caption_sub.offset_top = 56
	_caption_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_sub.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06, 0.95))
	_caption_sub.add_theme_constant_override("outline_size", 6)
	add_child(_caption_sub)
	var keys: Array = Data.maps.keys()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while not keys.is_empty():                  # a different order every time the title screen opens
		_order.append(keys.pop_at(rng.randi() % keys.size()))
	_start.call_deferred()


func _exit_tree() -> void:
	MapLoader.ground_only = false


func _start() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _swap()


## Fade out, replace the map, fade in.
func _swap() -> void:
	_busy = true
	if _cur_id != "":
		var out := create_tween()
		out.tween_property(_fade, "color:a", 1.0, 0.7)
		out.parallel().tween_property(_caption, "modulate:a", 0.0, 0.5)
		out.parallel().tween_property(_caption_sub, "modulate:a", 0.0, 0.5)
		await out.finished
	if not is_inside_tree():
		return
	if _stage != null:
		_stage.queue_free()
		_stage = null
	var id: String = _order[_next % _order.size()]
	if _next == 0 and OS.get_environment("PANO_MAP") != "":
		id = OS.get_environment("PANO_MAP")                # for testing
	_next += 1
	_stage = Stage.new()
	_stage.name = "Stage"
	_vp.add_child(_stage)
	MapLoader.ground_only = true
	MapLoader.apply_environment(_stage, id)
	var built := MapLoader.build(_stage, id)
	MapLoader.ground_only = false
	var sz: Array = built["size"]
	var msize := Vector2(float(sz[0]), float(sz[1]))
	Decor.scatter(_stage, id, built["root"], msize)
	Border.dress(_stage, id, built["root"], msize)
	Critters.attach(_stage, id, msize, built["markers"])
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_pos = _vantage(built["markers"], built["root"], msize)
	_yaw = randf() * TAU
	_cur_id = id
	_timer = 0.0
	var md: Dictionary = Data.maps[id]
	_caption.text = String(md.get("title", id)).to_upper()
	var home := ""
	for c in Data.class_order:
		if String(Data.classes[c]["home_map"]) == id:
			home = String(Data.classes[c]["name"])
	_caption_sub.text = ("home of the %s" % home) if home != "" else "a place to fight"
	var inn := create_tween()
	inn.tween_property(self, "modulate:a", 1.0, 1.0)
	inn.parallel().tween_property(_fade, "color:a", 0.0, 1.2)
	inn.parallel().tween_property(_caption, "modulate:a", 1.0, 1.2)
	inn.parallel().tween_property(_caption_sub, "modulate:a", 1.0, 1.2)
	_busy = false


## A good place to look around from: of the capture points, spawns and some other spots, the one with the most open space around it, a few metres above the ground.
func _vantage(markers: Array, root: Node3D, msize: Vector2) -> Vector3:
	var spots: Array = [Vector3.ZERO]
	for m in markers:
		var kind := String(m.get("kind", ""))
		if kind.contains("capture") or kind == "point" or kind == "spawn":
			spots.append(m["pos"])
	for i in 8:
		spots.append(Vector3(randf_range(-0.35, 0.35) * msize.x, 0, randf_range(-0.35, 0.35) * msize.y))
	var bigs: Array = root.get_meta("big_props", [])
	var space := _vp.find_world_3d().direct_space_state
	var best := Vector3(0, 8, 0)
	var best_clear := -9999.0
	for at: Vector3 in spots:
		var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 200.0, at.z), Vector3(at.x, -80.0, at.z), 1)
		var r := space.intersect_ray(q)
		if r.is_empty():
			continue
		var gy := float(r["position"].y)
		var clear := 60.0
		for b in bigs:
			var c: Vector3 = b[0]
			clear = minf(clear, Vector2(c.x - at.x, c.z - at.z).length() - float(b[1]))
		clear = minf(clear, 0.5 * minf(msize.x, msize.y) - maxf(absf(at.x), absf(at.z)))       # and away from the map's edge
		if clear > best_clear:
			best_clear = clear
			best = Vector3(at.x, gy + 6.0, at.z)
	return best


func _process(delta: float) -> void:
	if _cur_id == "" or _cam == null:
		return
	_yaw += TURN * delta
	_bob += delta
	_cam.position = _pos + Vector3(0, sin(_bob * 0.35) * 0.5, 0)
	_cam.rotation = Vector3(-0.09 + sin(_bob * 0.21) * 0.03, -_yaw, 0)
	_timer += delta
	if not _busy and _timer > SHOW_SECS:
		_swap()
