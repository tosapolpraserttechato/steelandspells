class_name LootCrateNode
extends Node3D
## A loot crate spot (from the map's loot_crate markers). The crate model is part of the map; this adds the glow, the rarity and the interaction.
## Press G next to it to open: the crate-open screen reveals what was rolled (item type, which item, old or brand new, skin and modifier).

signal opened(crate: LootCrateNode, result: Dictionary)

var rarity := "common"
var gold := false
var respawn_seconds := 90.0
var is_open := false
var match_ref: Match = null
var _beam: Node3D
var _timer := 0.0


func setup(is_gold: bool, respawn: float, bonus: float = 0.0) -> void:
	gold = is_gold
	respawn_seconds = respawn
	_roll_new(bonus)


func _roll_new(bonus: float = 0.0) -> void:
	rarity = Loot.roll_crate_rarity(bonus, gold)
	is_open = false
	if _beam != null:
		_beam.queue_free()
	_beam = Fx.crate_beam("legendary" if gold else rarity, 7.0 if gold else 5.0)
	add_child(_beam)
	if gold:
		var t := Fx.particles({"tex": "star", "amount": 14, "life": 1.6, "shape": "sphere", "radius": 0.8, "vel": [0.2, 0.8], "size": [0.14, 0.3],
			"colors": [Color(1, 0.85, 0.3, 0), Color(1, 0.9, 0.4, 1), Color(1, 0.8, 0.2, 0)]})
		t.position = Vector3(0, 1.0, 0)
		_beam.add_child(t)


func can_interact(_p: Node) -> bool:
	return not is_open


func prompt_text() -> String:
	return "Press G to open the %s crate" % ("GOLD" if gold else Data.rarity(rarity)["name"].to_upper())


func interact(player: Node) -> void:
	if is_open:
		return
	is_open = true
	if _beam != null:
		_beam.visible = false
	var result := Loot.roll_crate(("legendary" if gold and Data.rarity_index(rarity) < 3 else rarity), gold, float(player.stats.add_sum("crate_gear_bonus")))
	result["crate_rarity"] = rarity
	_timer = respawn_seconds
	opened.emit(self, result)


func _process(delta: float) -> void:
	if is_open:
		_timer -= delta
		if _timer <= 0.0:
			var bonus := 0.0
			if match_ref != null and match_ref.player != null:
				bonus = float(match_ref.player.stats.add_sum("crate_rarity_bonus"))
			_roll_new(bonus)
