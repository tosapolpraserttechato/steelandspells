extends Node
## Loads every JSON file written by tools/make_data.py and offers lookups. Read-only game data.

var rarities: Array = []                  # [{id, name, color, shape, weight, glow, factor}] common .. mythic
var rarity_ids: Array = []
var _rarity_by_id: Dictionary = {}
var statuses: Dictionary = {}             # id -> status dict
var classes: Dictionary = {}              # id -> class dict
## Classes that stay in the data files but are not in the game (GM Ravn was removed on request).
const REMOVED_CLASSES := ["gm_ravn"]
var class_order: Array = []
var skills: Dictionary = {}               # id -> skill dict
var cards: Array = []
var card_by_id: Dictionary = {}
var card_weights: Dictionary = {}         # rarity id -> weight
var quest_skills: Array = []
var quest_by_id: Dictionary = {}
var weapons: Dictionary = {}
var weapon_order: Array = []
var armor_sets: Dictionary = {}
var armor_order: Array = []
var runes: Dictionary = {}
var rune_order: Array = []
var modifiers: Dictionary = {}            # {"weapon": {rarity: [[name, mods, desc], ...]}, "armor": {...}}
var auras: Dictionary = {}
var skins: Array = []
var armor_looks: Dictionary = {}             # set id -> look {style, c1, c2, glow, weapon} read by ArmorKit; data/armor_looks.json
var weapon_skins: Array = []                 # 10 skins pasted over a brand-new weapon (data/skins.json), some rarer than others
var armor_skins: Array = []                  # 10 skins for brand-new armor
var potions: Dictionary = {}
var items: Dictionary = {}
var maps: Dictionary = {}
var map_order: Array = []


func _ready() -> void:
	rarities = _read("rarities")
	for r in rarities:
		rarity_ids.append(r["id"])
		_rarity_by_id[r["id"]] = r
	for s in _read("statuses"):
		statuses[s["id"]] = s
	for c in _read("classes"):
		if String(c["id"]) in REMOVED_CLASSES:
			continue
		classes[c["id"]] = c
		class_order.append(c["id"])
	for s in _read("skills"):
		skills[s["id"]] = s
	var card_file: Dictionary = _read("cards")
	cards = card_file["cards"]
	card_weights = card_file["offer_weight"]
	for c in cards:
		card_by_id[c["id"]] = c
	quest_skills = _read("quest_skills")
	for q in quest_skills:
		quest_by_id[q["id"]] = q
	for w in _read("weapons"):
		weapons[w["id"]] = w
		weapon_order.append(w["id"])
	for a in _read("armor_sets"):
		armor_sets[a["id"]] = a
		armor_order.append(a["id"])
	for w in _read("weapons_ext"):
		weapons[w["id"]] = w
		weapon_order.append(w["id"])
	for a in _read("armor_sets_ext"):
		armor_sets[a["id"]] = a
		armor_order.append(a["id"])
	armor_looks = _read("armor_looks")
	var skin_file: Dictionary = _read("skins")
	weapon_skins = skin_file["weapon"]
	armor_skins = skin_file["armor"]
	for r in _read("runes"):
		runes[r["id"]] = r
		rune_order.append(r["id"])
	var mod_file: Dictionary = _read("modifiers")
	modifiers = mod_file["modifiers"]
	auras = mod_file["auras"]
	skins = mod_file["skins"]
	for p in _read("potions"):
		potions[p["id"]] = p
	for i in _read("items"):
		items[i["id"]] = i
	for m in _read("maps"):
		maps[m["id"]] = m
		map_order.append(m["id"])


func _read(file_name: String) -> Variant:
	var path := "res://data/%s.json" % file_name
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Data: cannot open " + path)
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Data: bad JSON in " + path)
		return []
	return parsed


# ---------------------------------------------------------------- rarity helpers

func rarity(id: String) -> Dictionary:
	return _rarity_by_id.get(id, _rarity_by_id["common"])


func rarity_color(id: String) -> Color:
	var c: Array = rarity(id)["color"]
	return Color(c[0], c[1], c[2])


func rarity_index(id: String) -> int:
	return rarity_ids.find(id)


func rarity_factor(id: String) -> float:
	return float(rarity(id)["factor"])


func color_of(a: Array) -> Color:
	return Color(a[0], a[1], a[2])


## All skills of a class in unlock order (10 regular skills), without signature and ultimate.
func class_skills(class_id: String) -> Array:
	var out: Array = []
	for sid in classes[class_id]["skills"]:
		out.append(skills[sid])
	return out


# ---------------------------------------------------------------- skins

## The skin (a dictionary from skins.json) with this name, "" gives {}. Items store the skin by its name.
func skin_def(skin_name: String, kind: String = "weapon") -> Dictionary:
	if skin_name == "":
		return {}
	for s in (weapon_skins if kind == "weapon" else armor_skins):
		if String(s["name"]).to_lower() == skin_name.to_lower():
			return s
	return {}


## Rolls a skin name. Common skins are far more likely than mythic ones; a better crate leans toward the rarer skins.
func roll_skin(crate_rarity: String, kind: String = "weapon") -> String:
	var list: Array = weapon_skins if kind == "weapon" else armor_skins
	var lean := 0.55 * float(rarity_index(crate_rarity))
	var weights: Array = []
	var total := 0.0
	for s in list:
		var w := float(s["weight"]) * (1.0 + lean * float(rarity_index(String(s["tier"]))))
		weights.append(w)
		total += w
	var r := randf() * total
	for i in list.size():
		r -= float(weights[i])
		if r <= 0.0:
			return String(list[i]["name"])
	return String(list[list.size() - 1]["name"])


## The rarity tier a skin is worth (for the colour it is shown in).
func skin_tier(skin_name: String, kind: String = "weapon") -> String:
	var d := skin_def(skin_name, kind)
	return String(d.get("tier", "common"))
