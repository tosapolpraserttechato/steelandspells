class_name Util
extends RefCounted
## Small helpers.


## Runs `f` after `delay` seconds, but only if `owner` still exists (a lambda that captured a freed object would raise an error).
static func after(owner: Node, delay: float, f: Callable) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var wr: WeakRef = weakref(owner)
	owner.get_tree().create_timer(delay).timeout.connect(func() -> void:
		if wr.get_ref() != null:
			f.call())
