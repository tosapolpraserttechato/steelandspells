class_name Stats
extends RefCounted
## Base numbers plus modifier sources (class passive, cards, armor, runes, weapon modifiers, buffs) -> final values.
## A modifier is {"stat": {"add": x, "mult": y}}. value = (base + sum add) * (1 + sum mult).
## Sources are keyed, so a card source can be replaced whenever the stack changes.

var base: Dictionary = {}
var _sources: Dictionary = {}     # key -> {stat: {add, mult}} (already scaled by strength)
var _cache: Dictionary = {}


func set_base(stat: String, value: float) -> void:
	base[stat] = value
	_cache.clear()


func set_source(key: String, mods: Dictionary, strength: float = 1.0) -> void:
	var scaled := {}
	for stat in mods:
		var m: Variant = mods[stat]
		if typeof(m) == TYPE_DICTIONARY and (m.has("add") or m.has("mult")):
			scaled[stat] = {"add": float(m.get("add", 0.0)) * strength, "mult": float(m.get("mult", 0.0)) * strength}
		else:
			scaled[stat] = {"value": m}          # non-numeric payloads (triggers) are kept as they are
	_sources[key] = scaled
	_cache.clear()


func remove_source(key: String) -> void:
	if _sources.erase(key):
		_cache.clear()


func clear_sources_with_prefix(prefix: String) -> void:
	for k in _sources.keys():
		if String(k).begins_with(prefix):
			_sources.erase(k)
	_cache.clear()


func has_source(key: String) -> bool:
	return _sources.has(key)


func add_sum(stat: String) -> float:
	var t := 0.0
	for k in _sources:
		var m: Variant = _sources[k].get(stat)
		if m != null and m.has("add"):
			t += m["add"]
	return t


func mult_sum(stat: String) -> float:
	var t := 0.0
	for k in _sources:
		var m: Variant = _sources[k].get(stat)
		if m != null and m.has("mult"):
			t += m["mult"]
	return t


## Final value of a stat. `fallback_base` is used when no base was set (for stats that are only modifiers, base 0).
func value(stat: String, fallback_base: float = 0.0) -> float:
	if _cache.has(stat):
		return _cache[stat]
	var b: float = base.get(stat, fallback_base)
	var v := (b + add_sum(stat)) * (1.0 + mult_sum(stat))
	_cache[stat] = v
	return v


## Fraction stats (crit chance, armor, resists) are base 0 and capped; use this for those.
func fraction(stat: String, cap: float = 0.9) -> float:
	return clampf(value(stat, 0.0), -1.0, cap)


## Payloads of trigger-style modifiers (e.g. "on_hit": {...}) from every source.
func payloads(stat: String) -> Array:
	var out: Array = []
	for k in _sources:
		var m: Variant = _sources[k].get(stat)
		if m != null and m.has("value"):
			out.append(m["value"])
	return out
