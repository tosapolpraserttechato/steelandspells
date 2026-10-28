class_name DoorNode
extends Node
## A gate that slides down into the ground to open and back up to close (Desert Tomb). Its parts (the mesh, its collision body, the glyph) move together.

var parts: Array = []
var slide := 7.3
var is_open := false
var _tween: Tween
var _base_y: Dictionary = {}


func setup(p: Array, slide_down: float, start_open: bool) -> void:
	parts = p
	slide = slide_down
	for n in parts:
		_base_y[n] = (n as Node3D).position.y
	if start_open:
		is_open = true
		_move_to(slide)


func _move_to(down: float) -> void:
	for n in parts:
		if is_instance_valid(n):
			(n as Node3D).position.y = float(_base_y[n]) - down


func toggle() -> void:
	set_open(not is_open)


func set_open(open: bool) -> void:
	if open == is_open and _tween == null:
		return
	is_open = open
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var from := (float(_base_y[parts[0]]) - (parts[0] as Node3D).position.y) if not parts.is_empty() else 0.0
	var to := slide if open else 0.0
	_tween.tween_method(_move_to, from, to, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Sfx.play("whoosh")
