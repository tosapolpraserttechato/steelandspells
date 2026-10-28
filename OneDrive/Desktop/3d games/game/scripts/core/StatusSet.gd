class_name StatusSet
extends Node
## The status effects on one combatant: burn, chill, poison, shock, stun, slow, root, bleed, haste, barrier...
## Data lives in Data.statuses. This node ticks them, answers "can I move / cast", and tells the UI and effects what changed.

signal changed()                                   # any status added, removed or restacked
signal status_added(id: String)
signal status_removed(id: String)

var owner_c: Node = null                           # the Combatant
var active: Dictionary = {}                        # id -> {stacks, time, total, source}
var _tick_acc := 0.0
var absorb_left := 0.0                             # barrier hit points
var resists: Dictionary = {}                       # status id -> 0..1 chance to ignore / duration cut


func setup(c: Node) -> void:
	owner_c = c


func has(id: String) -> bool:
	return active.has(id)


func stacks(id: String) -> int:
	return int(active[id]["stacks"]) if active.has(id) else 0


func time_left(id: String) -> float:
	return float(active[id]["time"]) if active.has(id) else 0.0


func has_flag(flag: String) -> bool:
	for id in active:
		var d: Dictionary = Data.statuses[id]
		if d.has("flags") and flag in d["flags"]:
			return true
	return false


## Apply a status. `dur` <= 0 uses the default duration. Harmful ones respect resists, cleanse shield and duration cuts.
func apply(id: String, dur: float = -1.0, n: int = 1, source: Node = null, strength: float = 1.0) -> bool:
	if not Data.statuses.has(id) or owner_c == null or owner_c.dead:
		return false
	var d: Dictionary = Data.statuses[id]
	if d["harmful"]:
		if has_flag("immune_debuffs"):
			return false
		if d.get("magic_only", false) and not owner_c.is_magic():
			return false                           # non-magic gear and classes ignore Silence
		var res: float = float(resists.get(id, 0.0))
		if res > 0.0 and randf() < res * 0.5:
			return false
	var length: float = dur if dur > 0.0 else float(d["duration"])
	if d["harmful"]:
		length *= maxf(0.1, 1.0 + owner_c.stats.mult_sum("status_duration_taken"))
		length *= (1.0 - 0.5 * float(resists.get(id, 0.0)))
	var maxs: int = int(d.get("max_stacks", 1))
	var was := active.has(id)
	if was:
		var e: Dictionary = active[id]
		e["stacks"] = mini(maxs, int(e["stacks"]) + n)
		e["time"] = maxf(float(e["time"]), length)
		e["total"] = maxf(float(e["total"]), length)
		if source != null:
			e["source"] = source
	else:
		active[id] = {"stacks": mini(maxs, n), "time": length, "total": length, "source": source}
	if id == "barrier":
		absorb_left = float(d.get("absorb", 60.0)) * strength * (1.0 + owner_c.stats.mult_sum("shield_strength"))
	_react_to_stacks(id, source)
	if not was:
		status_added.emit(id)
	changed.emit()
	return true


func _react_to_stacks(id: String, source: Node) -> void:
	var d: Dictionary = Data.statuses[id]
	if d.has("freeze_at") and active.has(id) and int(active[id]["stacks"]) >= int(d["freeze_at"]):
		remove("chill")
		apply("freeze", -1.0, 1, source)
	if d.has("stun_at") and active.has(id) and int(active[id]["stacks"]) >= int(d["stun_at"]):
		remove("shock")
		apply("stun", -1.0, 1, source)


func remove(id: String) -> void:
	if active.erase(id):
		if id == "barrier":
			absorb_left = 0.0
		status_removed.emit(id)
		changed.emit()


func cleanse() -> void:
	for id in active.keys():
		if Data.statuses[id]["harmful"]:
			remove(id)


func clear_all() -> void:
	for id in active.keys():
		remove(id)


## Damage the barrier takes first; returns what is left for health.
func absorb(amount: float) -> float:
	if absorb_left <= 0.0 or not active.has("barrier"):
		return amount
	var take := minf(absorb_left, amount)
	absorb_left -= take
	if absorb_left <= 0.01:
		remove("barrier")
	return amount - take


# ---------------------------------------------------------------- modifiers read by movement and combat

func move_mult() -> float:
	var m := 1.0
	for id in active:
		var d: Dictionary = Data.statuses[id]
		if d.has("speed_per_stack"):
			var per: float = float(d["speed_per_stack"])
			if per < 0.0:
				per *= (1.0 - clampf(owner_c.stats.fraction("slow_resist", 0.9), 0.0, 0.9))
			m += per * int(active[id]["stacks"])
	return maxf(0.0, m)


func damage_taken_mult() -> float:
	var m := 1.0
	for id in active:
		m += float(Data.statuses[id].get("damage_taken", 0.0))
	return m


func damage_dealt_mult() -> float:
	var m := 1.0
	for id in active:
		m += float(Data.statuses[id].get("damage_dealt", 0.0))
	return maxf(0.0, m)


func heal_taken_mult() -> float:
	var m := 1.0
	for id in active:
		m += float(Data.statuses[id].get("heal_taken", 0.0)) * int(active[id]["stacks"])
	return maxf(0.0, m)


func can_move() -> bool:
	return not has_flag("root")


func can_cast() -> bool:
	return not has_flag("no_skills")


func can_attack() -> bool:
	return not has_flag("no_fire")


# ---------------------------------------------------------------- ticking

func _process(delta: float) -> void:
	if owner_c == null or active.is_empty():
		return
	var expired: Array = []
	_tick_acc += delta
	var tick := _tick_acc >= 1.0
	if tick:
		_tick_acc -= 1.0
	for id in active:
		var e: Dictionary = active[id]
		e["time"] = float(e["time"]) - delta
		var d: Dictionary = Data.statuses[id]
		if tick:
			var n: int = int(e["stacks"])
			if d.has("dps"):
				var dps: float = float(d["dps"]) * n
				if d.has("dps_moving_mult") and owner_c.velocity.length() > 1.0:
					dps *= float(d["dps_moving_mult"])
				owner_c.take_damage(dps, e.get("source"), {"dot": id, "no_status": true, "color": d["color"]})
			if d.has("hps"):
				owner_c.heal(float(d["hps"]) * n, null)
		if float(e["time"]) <= 0.0:
			expired.append(id)
	for id in expired:
		remove(id)
