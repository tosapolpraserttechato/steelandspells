extends Node
## Rolls every crate kind in every rarity many times and checks that nothing errors or hangs: godot --path game res://tests/roll_test.tscn
func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var bad := 0
	var kinds: Array = ["any", "weapon_new", "weapon_old", "armor", "runes"] + Loot.FAMILY_CRATES.keys()
	for kind in kinds:
		for r in Data.rarity_ids:
			for i in 300:
				var roll: Dictionary
				match kind:
					"any": roll = Loot.roll_crate(r)
					"weapon_new": roll = Loot.roll_weapon_crate(r, true)
					"weapon_old": roll = Loot.roll_weapon_crate(r, false)
					_: roll = Loot.roll_typed_crate(r, kind)
				if not roll.has("steps") or not roll.has("type"):
					bad += 1
					print("BAD roll ", kind, " ", r, " ", roll)
					continue
				if roll.has("item"):
					var it: Dictionary = roll["item"]
					var lines := Loot.describe(it)
					var nm := Loot.item_name(it)
					Loot.item_mods(it)
					if it["kind"] == "weapon" and not Data.weapons.has(it["id"]):
						bad += 1
						print("BAD weapon id ", it)
					if it["kind"] == "armor" and not Data.armor_sets.has(it["set"]):
						bad += 1
						print("BAD set ", it)
	print("ROLL_TEST done bad=", bad, " ms=", Time.get_ticks_msec() - t0)
	get_tree().quit()
