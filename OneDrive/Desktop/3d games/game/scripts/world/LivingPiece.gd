class_name LivingPiece
extends Node
## Chess Arena's living board: a big chess piece that slowly walks along a line (the marker's path), waits, and walks back. It is cover that moves.

var parts: Array = []
var _start: Dictionary = {}
var _delta := Vector3.ZERO


func setup(p: Array, delta: Vector3, move_seconds: float, pause_seconds: float, ping_pong: bool, phase: float) -> void:
	parts = p
	_delta = delta
	for n in parts:
		_start[n] = (n as Node3D).position
	var tw := create_tween().set_loops()
	tw.tween_interval(maxf(phase, 0.01))
	tw.tween_method(_at, 0.0, 1.0, move_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(pause_seconds)
	if ping_pong:
		tw.tween_method(_at, 1.0, 0.0, move_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(pause_seconds)
	else:
		tw.tween_callback(func() -> void: _at(0.0))


func _at(f: float) -> void:
	if OS.get_environment("TOAST_DEBUG") != "" and randf() < 0.03:
		print("LIVING ", f, " ", (parts[0] as Node3D).position)
	for n in parts:
		if is_instance_valid(n):
			(n as Node3D).position = (_start[n] as Vector3) + _delta * f
