class_name Loot
extends RefCounted
## Loot crate rolls. Order (from the design): item type -> which item -> old or brand new -> skin + modifier (new items only).
## Result: {"type": "weapon"|"armor"|"shield"|"rune"|"reroll"|"xp", "item": {...}, "rarity": r, "reroll": n, "xp": n, "steps": [...]}
## `steps` is what the crate-open screen reveals, one beat at a time.

const NEW_CHANCE := {"common": 0.15, "uncommon": 0.30, "rare": 0.50, "epic": 0.70, "legendary": 0.90, "mythic": 1.0}
const TYPE_WEIGHTS := {"weapon": 28.0, "armor": 32.0, "shield": 10.0, "rune": 18.0, "reroll": 8.0, "xp": 4.0}
const SLOT_NAMES := ["helmet", "chestplate", "leggings", "boots"]
const OLD_DEBUFF_STATS := ["move_speed", "max_health", "weapon_damage", "armor", "cooldown_reduction", "mana_regen"]


## A random crate rarity for a crate placed on the map. `bonus` comes from Lucky Find style cards (0..0.5).
static func roll_crate_rarity(bonus: float = 0.0, gold: bool = false) -> String:
	var ids: Array = Data.rarity_ids
	var weights: Array = []
	for i in ids.size():
		var w: float = float(Data.rarity(ids[i])["weight"])
		w *= (1.0 + bonus * float(i))                 # a bonus shifts weight toward rarer tiers
		if gold and i < 3:
			w = 0.0                                    # a gold crate is at least epic
		weights.append(w)
	return ids[_pick(weights)]


static func _pick(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := randf() * total
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return weights.size() - 1


static func roll_crate(rarity: String, gold: bool = false, gear_bonus: float = 0.0) -> Dictionary:
	var steps: Array = []
	var weights: Array = []
	var types: Array = TYPE_WEIGHTS.keys()
	for t in types:
		var w: float = TYPE_WEIGHTS[t]
		if (t == "reroll" or t == "rune") and Data.rarity_index(rarity) >= 3:
			w *= 1.5
		if t in ["weapon", "armor", "shield"]:
			w *= 1.0 + gear_bonus
		weights.append(w)
	var type: String = types[_pick(weights)]
	var result := {"type": type, "rarity": rarity, "gold": gold}
	steps.append({"label": "Item type", "value": _type_label(type), "rarity": rarity})
	match type:
		"reroll":
			var n := 1 + (1 if randf() < 0.3 + 0.1 * Data.rarity_index(rarity) else 0)
			result["reroll"] = n
			steps.append({"label": "Reward", "value": "%d card reroll%s" % [n, "" if n == 1 else "s"], "rarity": rarity})
		"xp":
			var amount := int(60 + 40 * Data.rarity_index(rarity))
			result["xp"] = amount
			steps.append({"label": "Reward", "value": "%d XP" % amount, "rarity": rarity})
		"rune":
			var item := make_rune(rarity)
			result["item"] = item
			steps.append({"label": "Which rune", "value": Data.runes[item["id"]]["name"], "rarity": item["rarity"]})
		_:
			var item := make_gear(type, rarity, gold)
			result["item"] = item
			steps.append({"label": "Which item", "value": item_name(item), "rarity": item["rarity"]})
			steps.append({"label": "Condition", "value": "Brand new" if item["new"] else "Old and worn", "rarity": rarity if item["new"] else "common"})
			if item["new"]:
				steps.append(skin_step(item))
				steps.append({"label": "Modifier", "value": "%s: %s" % [item["mod"]["name"], item["mod"]["desc"]], "rarity": rarity})
			else:
				steps.append({"label": "Flaw", "value": item["debuff"]["desc"], "rarity": "common"})
	result["steps"] = steps
	return result


static func _type_label(t: String) -> String:
	match t:
		"weapon": return "Weapon"
		"armor": return "Armor piece"
		"shield": return "Shield"
		"rune": return "Rune"
		"reroll": return "Card reroll"
		"xp": return "Experience"
	return t


static func make_rune(rarity: String) -> Dictionary:
	var pool: Array = []
	for id in Data.rune_order:
		if Data.runes[id]["rarity"] == rarity:
			pool.append(id)
	if pool.is_empty():
		pool = Data.rune_order.duplicate()
	var id: String = pool[randi() % pool.size()]
	return {"kind": "rune", "id": id, "rarity": Data.runes[id]["rarity"], "uid": Game.new_uid()}


## `force_new`: -1 random (by the crate rarity), 1 always brand new, 0 always old and worn.
static func make_gear(type: String, rarity: String, gold: bool = false, force_new: int = -1, weapon_pool: Array = []) -> Dictionary:
	var item := {"uid": Game.new_uid(), "rarity": rarity, "runes": []}
	if type == "weapon":
		item["kind"] = "weapon"
		item["id"] = (weapon_pool[randi() % weapon_pool.size()] if not weapon_pool.is_empty() else Data.weapon_order[randi() % Data.weapon_order.size()])
		item["sockets"] = 1 + (1 if Data.rarity_index(rarity) >= 3 else 0) + (1 if rarity == "mythic" else 0)
	else:
		item["kind"] = "armor"
		item["slot"] = "shield" if type == "shield" else SLOT_NAMES[randi() % SLOT_NAMES.size()]
		item["set"] = Data.armor_order[randi() % Data.armor_order.size()]
		item["sockets"] = 1 + (1 if Data.rarity_index(rarity) >= 3 else 0) + (1 if rarity == "mythic" else 0)
	var new_chance: float = NEW_CHANCE[rarity] + (0.15 if gold else 0.0)
	item["new"] = (force_new == 1) if force_new >= 0 else randf() < new_chance
	if item["new"]:
		item["skin"] = Data.roll_skin(rarity, "weapon" if type == "weapon" else "armor")      # only a brand-new item gets a skin; rarer skins are rarer
		var pool: Array = Data.modifiers["weapon" if type == "weapon" else "armor"][rarity]
		var m: Array = pool[randi() % pool.size()]
		item["mod"] = {"name": m[0], "mods": m[1], "desc": m[2], "rarity": rarity}
		if rarity == "legendary":
			item["aura"] = "gold"
		elif rarity == "mythic":
			item["aura"] = String(Data.auras.get(m[0], {"id": "flames"})["id"])
	else:
		var stat: String = OLD_DEBUFF_STATS[randi() % OLD_DEBUFF_STATS.size()]
		var pct := randf_range(0.03, 0.05)
		item["debuff"] = {"stat": stat, "mult": -pct, "desc": "-%d%% %s" % [int(round(pct * 100.0)), stat.replace("_", " ")]}
	return item


static func item_name(item: Dictionary) -> String:
	match item["kind"]:
		"weapon": return Data.weapons[item["id"]]["name"]
		"rune": return Data.runes[item["id"]]["name"]
		"armor":
			var s: Dictionary = Data.armor_sets[item["set"]]
			var idx: int = Array(["helmet", "chestplate", "shield", "leggings", "boots"]).find(item["slot"])
			return s["pieces"][idx]["name"]
	return "?"


## Stat modifiers of one equipped item (its own passive, modifier or flaw, sockets). Keyed by the caller as "item:<slot>".
static func item_mods(item: Dictionary, strength: float = 1.0) -> Dictionary:
	var out := {}
	if item.is_empty():
		return out
	if item["kind"] == "armor":
		var s: Dictionary = Data.armor_sets[item["set"]]
		var idx: int = Array(["helmet", "chestplate", "shield", "leggings", "boots"]).find(item["slot"])
		_merge(out, s["pieces"][idx]["passive"]["mods"], strength)
	if item.get("new", false) and item.has("mod"):
		_merge(out, item["mod"]["mods"], 1.0)
	if item.has("debuff"):
		_merge(out, {item["debuff"]["stat"]: {"mult": item["debuff"]["mult"]}}, 1.0)
	for rid in item.get("runes", []):
		if Data.runes.has(rid):
			_merge(out, Data.runes[rid]["mods"], 1.0)
			if Data.runes[rid].has("trigger"):
				_merge(out, {"trigger_" + rid: Data.runes[rid]["trigger"]}, 1.0)
	return out


static func _merge(into: Dictionary, add: Dictionary, k: float) -> void:
	for stat in add:
		var m: Variant = add[stat]
		if typeof(m) == TYPE_DICTIONARY and (m.has("add") or m.has("mult")):
			var cur: Dictionary = into.get(stat, {"add": 0.0, "mult": 0.0})
			cur["add"] = float(cur.get("add", 0.0)) + float(m.get("add", 0.0)) * k
			cur["mult"] = float(cur.get("mult", 0.0)) + float(m.get("mult", 0.0)) * k
			into[stat] = cur
		else:
			into[stat] = m


## The shared description lines for tooltips.
static func describe(item: Dictionary) -> Array:
	var lines: Array = []
	match item["kind"]:
		"weapon":
			var w: Dictionary = Data.weapons[item["id"]]
			lines.append("%s %s" % ["Magic" if w["magic"] else "Non-magic", String(w["family"]).capitalize()])
			lines.append("Damage %d   Rate %.1f/s   Range %d m" % [w["dmg"], w["rate"], w["range"]])
			lines.append(w["desc"])
		"armor":
			var s: Dictionary = Data.armor_sets[item["set"]]
			var idx: int = Array(["helmet", "chestplate", "shield", "leggings", "boots"]).find(item["slot"])
			lines.append("%s set (%s)" % [s["name"], "magic" if s["magic"] else "non-magic"])
			lines.append("Passive: " + String(s["pieces"][idx]["passive"]["name"]))
			lines.append("Set bonus (5/5): " + String(s["set_bonus"]["desc"]))
		"rune":
			lines.append(Data.runes[item["id"]]["desc"])
	if item.get("new", false) and item.has("mod"):
		lines.append("Modifier: %s (%s)" % [item["mod"]["name"], item["mod"]["desc"]])
		lines.append("Skin: " + String(item.get("skin", "")))
	elif item.has("debuff"):
		lines.append("Worn: " + String(item["debuff"]["desc"]))
	return lines


## A crate that always holds a weapon: `is_new` = a brand-new one (with a skin and a modifier that grows with the crate's rarity) or an old, worn one (a small flaw).
static func roll_weapon_crate(rarity: String, is_new: bool) -> Dictionary:
	var item := make_gear("weapon", rarity, false, 1 if is_new else 0)
	var steps: Array = []
	steps.append({"label": "Item type", "value": "Weapon", "rarity": rarity})
	steps.append({"label": "Which item", "value": item_name(item), "rarity": item["rarity"]})
	steps.append({"label": "Condition", "value": "Brand new" if is_new else "Old and worn", "rarity": rarity if is_new else "common"})
	if is_new:
		steps.append(skin_step(item))
		steps.append({"label": "Modifier", "value": "%s: %s" % [item["mod"]["name"], item["mod"]["desc"]], "rarity": rarity})
	else:
		steps.append({"label": "Flaw", "value": item["debuff"]["desc"], "rarity": "common"})
	return {"type": "weapon", "rarity": rarity, "gold": false, "item": item, "steps": steps}


## Crates that hold one kind of thing: a family of weapons (a bow crate), armor pieces, or runes. The same reveal as any crate.
const FAMILY_CRATES := {
	"fam_bow": {"name": "Bow", "families": ["bow", "spiritbow"]},
	"fam_sword": {"name": "Sword", "families": ["sword", "enchblade", "heavy"]},
	"fam_axe": {"name": "Axe", "families": ["axe"]},
	"fam_hammer": {"name": "Hammer", "families": ["mace", "gauntlet"]},
	"fam_spear": {"name": "Spear and scythe", "families": ["polearm", "scythe"]},
	"fam_staff": {"name": "Staff", "families": ["staff"]},
	"fam_wand": {"name": "Wand", "families": ["wand"]},
	"fam_orb": {"name": "Orb", "families": ["orb"]},
	"fam_tome": {"name": "Tome", "families": ["tome"]},
	"fam_dagger": {"name": "Dagger and claw", "families": ["dagger", "claws", "whip"]},
	"fam_crossbow": {"name": "Crossbow and throwing", "families": ["crossbow", "thrown"]},
}


static func roll_typed_crate(rarity: String, kind: String) -> Dictionary:
	if FAMILY_CRATES.has(kind):
		var fams: Array = FAMILY_CRATES[kind]["families"]
		var ids: Array = []
		for wid in Data.weapon_order:
			if Data.weapons[wid]["family"] in fams:
				ids.append(wid)
		return _gear_result(make_gear("weapon", rarity, false, -1, ids), rarity, "Weapon")
	if kind == "armor":
		return _gear_result(make_gear("armor" if randf() < 0.8 else "shield", rarity), rarity, "Armor piece")
	var rune := make_rune(rarity)
	return {"type": "rune", "rarity": rarity, "gold": false, "item": rune, "steps": [
		{"label": "Item type", "value": "Rune", "rarity": rarity},
		{"label": "Which rune", "value": Data.runes[rune["id"]]["name"], "rarity": rune["rarity"]}]}


static func _gear_result(item: Dictionary, rarity: String, type_label: String) -> Dictionary:
	var steps: Array = [{"label": "Item type", "value": type_label, "rarity": rarity}, {"label": "Which item", "value": item_name(item), "rarity": item["rarity"]},
		{"label": "Condition", "value": "Brand new" if item["new"] else "Old and worn", "rarity": rarity if item["new"] else "common"}]
	if item["new"]:
		steps.append(skin_step(item))
		steps.append({"label": "Modifier", "value": "%s: %s" % [item["mod"]["name"], item["mod"]["desc"]], "rarity": rarity})
	else:
		steps.append({"label": "Flaw", "value": item["debuff"]["desc"], "rarity": "common"})
	return {"type": "weapon" if item["kind"] == "weapon" else ("shield" if item.get("slot", "") == "shield" else "armor"), "rarity": rarity, "gold": false, "item": item, "steps": steps}


## The reveal row for a skin: shown in the colour of how rare that skin is.
static func skin_step(item: Dictionary) -> Dictionary:
	return {"label": "Skin", "value": item["skin"], "rarity": Data.skin_tier(String(item["skin"]), "weapon" if item["kind"] == "weapon" else "armor")}
