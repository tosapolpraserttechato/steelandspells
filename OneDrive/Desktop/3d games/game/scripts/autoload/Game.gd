extends Node
## Global game state: the player's profile (saved), the current run (level, XP, cards, rerolls, potions) and the level-up logic.
## One Match at a time; Match.gd tells this node about kills, crates and missions through add_xp().

signal xp_changed(xp: int, need: int, level: int)
signal leveled_up(level: int)
signal cards_offered(offer: Array)                 # [{id, stack, rarity}] (3 cards, 4 with Fate Weaver)
signal card_picked(card_id: String, stack: int)
signal rerolls_changed(n: int)
signal inventory_changed()
signal equipment_changed()
signal quest_skill_changed()
signal potions_changed()
signal skills_unlocked(ids: Array)

const MAX_LEVEL := 100
const SLOTS := ["weapon", "helmet", "chestplate", "shield", "leggings", "boots"]
const SAVE_PATH := "user://profile.json"

# ----- what the player picked in the menu
var selected_class := "druid"
var last_map := ""                                 # the map played last, left out of the next lobby vote when possible
var map_id := "flora_forest"
var game_mode := "domination"
var bots_per_team := 5

# ----- profile (saved between matches)
var inventory: Array = []                          # item dicts (weapons, armor pieces, runes)
var equipped: Dictionary = {}                      # slot -> item uid ("" = nothing)
var chosen_skills: Dictionary = {}                 # class id -> [3 skill ids]
var unlocked_skills: Dictionary = {}               # skill id -> true
var quest_skill: String = ""                       # owned quest skill id
var records: Array = []                            # the last matches: {map, mode, winner, won, rows: [{name, cls, team, kills, deaths, captures, you}]}
var career: Dictionary = {"matches": 0, "wins": 0, "kills": 0, "deaths": 0, "captures": 0, "best_streak": 0, "best_kd": 0.0}
var _next_uid := 1


## Kills per death, the way a leaderboard counts: no deaths yet means the kills themselves.
static func kd(kills: int, deaths: int) -> float:
	return float(kills) / float(maxi(1, deaths))


## Called when a match ends: stores every fighter's kills and deaths (the leaderboard reads them) and adds yours to the career totals.
func record_match(m: Node, winner: String) -> void:
	var rows: Array = []
	var me: Combatant = null
	for c in m.combatants:
		if not is_instance_valid(c) or (c is Bot and (c as Bot).life_left >= 0.0):
			continue
		var is_you: bool = c == m.player
		if is_you:
			me = c
		rows.append({"name": c.display_name, "cls": c.class_id, "team": c.team, "kills": c.kills, "deaths": c.deaths, "captures": c.captures, "best_streak": c.best_streak, "you": is_you})
	var won: bool = me != null and winner == me.team
	records.append({"map": m.map_id, "mode": m.mode, "winner": winner, "won": won, "score": [m.score["red"], m.score["blue"]], "rows": rows})
	while records.size() > 40:
		records.pop_front()
	if me != null:
		career["matches"] = int(career["matches"]) + 1
		career["wins"] = int(career["wins"]) + (1 if won else 0)
		career["kills"] = int(career["kills"]) + me.kills
		career["deaths"] = int(career["deaths"]) + me.deaths
		career["captures"] = int(career["captures"]) + me.captures
		career["best_streak"] = maxi(int(career["best_streak"]), me.best_streak)
		career["best_kd"] = maxf(float(career["best_kd"]), kd(me.kills, me.deaths))
		win_streak = win_streak + 1 if won else 0
		last_class_gain = add_class_xp(me.class_id, class_xp_reward(won, me.kills, me.captures))
		last_class_gain.append(class_xp_reward(won, me.kills, me.captures))
		last_class_id = me.class_id
		last_gold_gain = gold_reward(won, me.kills, me.captures, win_streak)
		gold += last_gold_gain
		award_match_crates(won, me.kills, me.captures)
	save_profile()

# ----- the current run (reset at the start of a match)
var level := 1
var xp := 0
var cards_owned: Dictionary = {}                   # card id -> stack
var rerolls := 0
var pending_offers := 0                            # level-ups waiting for a card choice
var current_offer: Array = []
var potions: Dictionary = {}                       # potion id -> count
var _levels_since_extra := 0


func _ready() -> void:
	randomize()
	load_profile()
	if unlocked_skills.is_empty():
		_unlock_defaults()
	for cid in Data.class_order:
		apply_class_unlocks(cid)
	give_starter_crates()
	if not gold_gift:
		gold_gift = true
		gold += 400                                  # a purse to start with
	if OS.get_environment("FAKE_CRATES") != "":
		for kind in CRATE_KINDS:
			for rr in Data.rarity_ids:
				crates[crate_key(kind, rr)] = 1
	if OS.get_environment("FAKE_RECORDS") != "":
		_fake_records()


## For screenshots of the leaderboard (run with NO_SAVE=1 FAKE_RECORDS=1): a few made-up matches.
func _fake_records() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var names := ["Aldric", "Brynn", "Cael", "Dara", "Eryn", "Fenn", "Garo", "Hale"]
	records.clear()
	career = {"matches": 0, "wins": 0, "kills": 0, "deaths": 0, "captures": 0, "best_streak": 0, "best_kd": 0.0}
	for i in 9:
		var rows: Array = []
		var yk := rng.randi_range(4, 16)
		var yd := rng.randi_range(2, 11)
		var cls: String = Data.class_order[rng.randi() % Data.class_order.size()]
		rows.append({"name": "You", "cls": cls, "team": "red", "kills": yk, "deaths": yd, "captures": rng.randi_range(0, 2), "best_streak": rng.randi_range(1, 6), "you": true})
		for n in names:
			rows.append({"name": n, "cls": Data.class_order[rng.randi() % Data.class_order.size()], "team": "red" if rng.randf() < 0.5 else "blue", "kills": rng.randi_range(1, 14),
				"deaths": rng.randi_range(1, 12), "captures": 0, "best_streak": 2, "you": false})
		var won := rng.randf() < 0.5
		records.append({"map": ["flora_forest", "pirate_cove", "frozen_peaks"][i % 3], "mode": ["domination", "tdm", "ctf"][i % 3], "winner": "red" if won else "blue", "won": won, "score": [rng.randi_range(0, 3), rng.randi_range(0, 3)], "rows": rows})
		career["matches"] = int(career["matches"]) + 1
		career["wins"] = int(career["wins"]) + (1 if won else 0)
		career["kills"] = int(career["kills"]) + yk
		career["deaths"] = int(career["deaths"]) + yd
		career["best_kd"] = maxf(float(career["best_kd"]), kd(yk, yd))
		career["best_streak"] = maxi(int(career["best_streak"]), 4)


# ================================================================= profile

func _unlock_defaults() -> void:
	for cid in Data.class_order:
		var list: Array = Data.classes[cid]["skills"]
		for i in mini(3, list.size()):
			unlocked_skills[list[i]] = true


func new_uid() -> String:
	_next_uid += 1
	return "i%d_%d" % [Time.get_ticks_msec(), _next_uid]


func save_profile() -> void:
	if OS.get_environment("NO_SAVE") != "":              # test runs must not change the player's real profile
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"inventory": inventory, "equipped": equipped, "chosen_skills": chosen_skills, "unlocked_skills": unlocked_skills,
		"quest_skill": quest_skill, "selected_class": selected_class, "next_uid": _next_uid, "records": records, "career": career, "crates": crates, "gift_given": gift_given, "win_streak": win_streak, "class_xp": class_xp, "gold": gold, "gold_gift": gold_gift}))


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	inventory = d.get("inventory", [])
	equipped = d.get("equipped", {})
	equipped.erase("weapon")                           # older saves had one weapon for every class: each class now starts with its own
	chosen_skills = d.get("chosen_skills", {})
	unlocked_skills = d.get("unlocked_skills", {})
	quest_skill = d.get("quest_skill", "")
	selected_class = d.get("selected_class", "druid")
	if not Data.classes.has(selected_class):
		selected_class = "druid"                     # the class was removed from the game
	_next_uid = int(d.get("next_uid", 1))
	records = d.get("records", [])
	var cs: Variant = d.get("crates", {})
	if typeof(cs) == TYPE_DICTIONARY:
		crates = cs
	gift_given = bool(d.get("gift_given", false))
	win_streak = int(d.get("win_streak", 0))
	gold = int(d.get("gold", 0))
	gold_gift = bool(d.get("gold_gift", false))
	var cx: Variant = d.get("class_xp", {})
	if typeof(cx) == TYPE_DICTIONARY:
		class_xp = cx
	var cr: Variant = d.get("career", {})
	if typeof(cr) == TYPE_DICTIONARY:
		for k in cr:
			career[k] = cr[k]


func item_by_uid(uid: String) -> Dictionary:
	for it in inventory:
		if it["uid"] == uid:
			return it
	return {}


## Armor is shared by every class; a weapon is remembered per class ("weapon:druid"), so each hero holds its own weapon until you give it another one.
func _slot_key(slot: String, class_id: String = "") -> String:
	if slot == "weapon":
		return "weapon:" + (class_id if class_id != "" else selected_class)
	return slot


func equipped_item(slot: String, class_id: String = "") -> Dictionary:
	var uid: String = equipped.get(_slot_key(slot, class_id), "")
	return item_by_uid(uid) if uid != "" else {}


## The armor the player wears, for CharacterModel.dress: [slot -> set id, slot -> skin name (brand-new pieces only), slot -> true for an old, worn piece].
func worn_armor() -> Array:
	var pieces := {}
	var skins := {}
	var worn := {}
	for slot in ["helmet", "chestplate", "shield", "leggings", "boots"]:
		var it := equipped_item(slot)
		if it.is_empty() or not it.has("set"):
			continue
		pieces[slot] = it["set"]
		if it.get("new", false) and it.has("skin"):
			skins[slot] = it["skin"]
		elif not it.get("new", false):
			worn[slot] = true
	return [pieces, skins, worn]


func equip(item: Dictionary) -> void:
	var slot: String = "weapon" if item["kind"] == "weapon" else String(item["slot"])
	equipped[_slot_key(slot)] = item["uid"]
	equipment_changed.emit()
	save_profile()


func unequip(slot: String) -> void:
	equipped.erase(_slot_key(slot))
	equipment_changed.emit()
	save_profile()


func add_item(item: Dictionary) -> void:
	if not item.has("uid"):
		item["uid"] = new_uid()
	inventory.append(item)
	inventory_changed.emit()
	save_profile()


func remove_item(uid: String) -> void:
	for i in inventory.size():
		if inventory[i]["uid"] == uid:
			inventory.remove_at(i)
			break
	for s in equipped.keys():
		if equipped[s] == uid:
			equipped.erase(s)
	inventory_changed.emit()
	equipment_changed.emit()
	save_profile()


func skills_for(class_id: String) -> Array:
	var s: Array = chosen_skills.get(class_id, [])
	if s.size() < 3:
		s = Data.classes[class_id]["skills"].slice(0, 3)
		chosen_skills[class_id] = s
	return s


func set_chosen_skill(class_id: String, slot: int, skill_id: String) -> void:
	var s: Array = skills_for(class_id).duplicate()
	s[slot] = skill_id
	chosen_skills[class_id] = s
	save_profile()


# ================================================================= the run

func new_run() -> void:
	level = 1
	xp = 0
	cards_owned = {}
	rerolls = 0
	pending_offers = 0
	current_offer = []
	_levels_since_extra = 0
	potions = {"potion_health": 2, "potion_mana": 1}
	xp_changed.emit(xp, xp_for_next(), level)
	potions_changed.emit()


func xp_for_next(l: int = -1) -> int:
	var lv := level if l < 0 else l
	return int(30 + 8 * lv + 0.2 * lv * lv)


func add_xp(amount: float, from_crate: bool = false) -> void:
	if level >= MAX_LEVEL:
		return
	var mult := 1.0 + stat_add("xp_gain", true)
	if from_crate:
		mult += stat_add("crate_xp", true)
	xp += int(round(amount * mult))
	while level < MAX_LEVEL and xp >= xp_for_next():
		xp -= xp_for_next()
		level += 1
		pending_offers += 1
		_levels_since_extra += 1
		var every := int(stat_value("extra_card_every"))
		if every > 0 and _levels_since_extra >= every:
			_levels_since_extra = 0
			pending_offers += 1
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_for_next(), level)
	if pending_offers > 0 and current_offer.is_empty():
		open_offer()


func _unlock_class_skill() -> void:
	var list: Array = Data.classes[selected_class]["skills"]
	var idx := level / 10 - 1                       # level 10 -> 4th skill? skills 1-3 are free; 10,20,30.. unlock 4..10 (levels above 70 repeat)
	var newly: Array = []
	var k := 3 + (level / 10) - 1
	if k < list.size() and not unlocked_skills.has(list[k]):
		unlocked_skills[list[k]] = true
		newly.append(list[k])
	if not newly.is_empty():
		skills_unlocked.emit(newly)
		save_profile()


# ================================================================= cards

func cards_per_offer() -> int:
	return maxi(3, int(stat_value("cards_offered")))


## Rolls an offer: each card shows the rarity of its NEXT copy (new cards: their base rarity); rarity chances follow the weights.
func roll_offer() -> Array:
	var by_rarity: Dictionary = {}
	for c in Data.cards:
		var have: int = int(cards_owned.get(c["id"], 0))
		if have >= int(c["max_stack"]):
			continue
		var r: String = c["rarity_by_stack"][have]
		if not by_rarity.has(r):
			by_rarity[r] = []
		by_rarity[r].append({"id": c["id"], "stack": have + 1, "rarity": r})
	var offer: Array = []
	var bonus := stat_add("crate_rarity_bonus", true) * 0.0
	for _i in cards_per_offer():
		var total := 0.0
		for r in by_rarity:
			if by_rarity[r].size() > 0:
				total += float(Data.card_weights.get(r, 1))
		if total <= 0.0:
			break
		var roll := randf() * total
		var pick_r := ""
		for r in by_rarity:
			if by_rarity[r].size() == 0:
				continue
			roll -= float(Data.card_weights.get(r, 1))
			pick_r = r
			if roll <= 0.0:
				break
		var pool: Array = by_rarity[pick_r]
		var idx := randi() % pool.size()
		offer.append(pool[idx])
		pool.remove_at(idx)
	return offer


func open_offer() -> void:
	if pending_offers <= 0:
		return
	current_offer = roll_offer()
	cards_offered.emit(current_offer)


func reroll_offer() -> bool:
	if rerolls <= 0 or current_offer.is_empty():
		return false
	rerolls -= 1
	rerolls_changed.emit(rerolls)
	current_offer = roll_offer()
	cards_offered.emit(current_offer)
	return true


func add_rerolls(n: int) -> void:
	rerolls += n
	rerolls_changed.emit(rerolls)


func pick_card(card_id: String) -> void:
	if current_offer.is_empty():
		return
	var stack: int = int(cards_owned.get(card_id, 0)) + 1
	cards_owned[card_id] = stack
	pending_offers -= 1
	current_offer = []
	card_picked.emit(card_id, stack)
	if pending_offers > 0:
		open_offer()


## Machine-readable value of one card at its current stack, as stat modifiers (see tools/data_cards.py).
func card_mods() -> Dictionary:
	var mods := {}
	for id in cards_owned:
		var c: Dictionary = Data.card_by_id[id]
		var stack: int = int(cards_owned[id])
		var v: float = float(c["per_stack"][stack - 1])
		var stat: String = c["stat"]
		var kind: String = c["kind"]
		var cur: Dictionary = mods.get(stat, {})
		if kind == "mult":
			cur["mult"] = float(cur.get("mult", 0.0)) + v
		else:                                           # "add" and "value"
			cur["add"] = float(cur.get("add", 0.0)) + v
		mods[stat] = cur
	return mods


## Sum of one stat over cards only (the player's Stats object is the full answer in a match; this is for menus and XP).
func stat_add(stat: String, mult_too: bool = false) -> float:
	var m: Dictionary = card_mods().get(stat, {})
	return float(m.get("add", 0.0)) + (float(m.get("mult", 0.0)) if mult_too else 0.0)


func stat_value(stat: String) -> float:
	var m: Dictionary = card_mods().get(stat, {})
	return float(m.get("add", 0.0))


# ================================================================= potions

func add_potion(id: String, n: int = 1) -> void:
	potions[id] = int(potions.get(id, 0)) + n
	potions_changed.emit()


func use_potion(id: String) -> bool:
	if int(potions.get(id, 0)) <= 0:
		return false
	potions[id] = int(potions[id]) - 1
	potions_changed.emit()
	return true


# ================================================================= crates you own (opened from the title screen)

const CRATE_KINDS := {
	"any": "Loot crate (anything can be inside)",
	"weapon_new": "Weapon crate: BRAND NEW (a skin and a modifier)",
	"weapon_old": "Weapon crate: OLD (a worn weapon with a small flaw)",
	"armor": "Armor crate (a piece of armor or a shield)",
	"rune": "Rune crate",
	"fam_bow": "Bow crate", "fam_sword": "Sword crate", "fam_axe": "Axe crate", "fam_hammer": "Hammer crate", "fam_spear": "Spear and scythe crate", "fam_staff": "Staff crate",
	"fam_wand": "Wand crate", "fam_orb": "Orb crate", "fam_tome": "Tome crate", "fam_dagger": "Dagger and claw crate", "fam_crossbow": "Crossbow and throwing crate",
}
var crates: Dictionary = {}                        # "<kind>:<rarity>" -> how many unopened
var last_rewards: Array = []                       # the crates the last match gave: [key, ...]
var last_odds := ""                                # the chances that roll had, as text
var last_class_gain: Array = []                    # [class level before, after, skills unlocked, xp gained] of the last match
var last_class_id := ""
var gift_given := false


func crate_key(kind: String, rarity: String) -> String:
	return "%s:%s" % [kind, rarity]


func add_crate(kind: String, rarity: String, n: int = 1) -> void:
	var k := crate_key(kind, rarity)
	crates[k] = int(crates.get(k, 0)) + n
	save_profile()


func crate_count() -> int:
	var t := 0
	for k in crates:
		t += int(crates[k])
	return t


## Opens one crate from the stock: returns the roll (for CrateOpen) or {} when there is none.
func take_crate(key: String) -> Dictionary:
	if int(crates.get(key, 0)) <= 0:
		return {}
	crates[key] = int(crates[key]) - 1
	if int(crates[key]) <= 0:
		crates.erase(key)
	var parts := key.split(":")
	var kind := String(parts[0])
	var rarity := String(parts[1])
	var roll: Dictionary
	match kind:
		"weapon_new": roll = Loot.roll_weapon_crate(rarity, true)
		"weapon_old": roll = Loot.roll_weapon_crate(rarity, false)
		"any": roll = Loot.roll_crate(rarity)
		_: roll = Loot.roll_typed_crate(rarity, kind)
	roll["crate_rarity"] = rarity
	save_profile()
	return roll


## What a finished match gives: two rolls on the odds from `reward_odds` (a loot crate and a weapon crate), each can be "nothing" or a rarity from common to mythic.
## Winning, scoring (kills, flags) and a winning streak all shift the odds toward the rare crates. A weapon crate is brand new with the same chance a new item has
## in that rarity (Loot.NEW_CHANCE), otherwise old and worn. Returns the keys, also kept in `last_rewards` for the result screen (with `last_odds` as text).
func award_match_crates(won: bool, kills: int, captures: int = 0) -> Array:
	last_rewards.clear()
	var shift := reward_shift(won, kills, captures, win_streak)
	last_odds = odds_text(shift)
	var r1 := reward_roll(shift)
	if r1 != "nothing":
		add_crate("any", r1)
		last_rewards.append(crate_key("any", r1))
	var r2 := reward_roll(shift * 0.9)
	if r2 != "nothing":
		var kind := "weapon_new" if randf() < float(Loot.NEW_CHANCE[r2]) else "weapon_old"
		add_crate(kind, r2)
		last_rewards.append(crate_key(kind, r2))
	for i in int(kills / 10):                       # every ten kills: one more new-weapon crate
		var r3 := reward_roll(minf(shift + 0.2, 1.0))
		if r3 != "nothing":
			add_crate("weapon_new", r3)
			last_rewards.append(crate_key("weapon_new", r3))
	return last_rewards


## A one-time gift so the crates menu has something to open the first time.
func give_starter_crates() -> void:
	if gift_given:
		return
	gift_given = true
	add_crate("any", "rare")
	add_crate("weapon_new", "epic")
	add_crate("weapon_old", "uncommon")


# ================================================================= how good the crates a match gives are

## The chances for one crate roll at the end of a match, from the worst case (a loss without scoring: 60% common, 20% uncommon, 10% rare, 5% epic, 5% nothing)
## to the best (a win with many kills on a winning streak). `shift` goes from 0 to 1.
const REWARD_WORST := {"nothing": 5.0, "common": 60.0, "uncommon": 20.0, "rare": 10.0, "epic": 5.0, "legendary": 0.0, "mythic": 0.0}
const REWARD_BEST := {"nothing": 0.0, "common": 4.0, "uncommon": 16.0, "rare": 32.0, "epic": 40.0, "legendary": 7.0, "mythic": 1.0}
var win_streak := 0


static func reward_shift(won: bool, kills: int, captures: int, streak: int) -> float:
	return clampf((0.35 if won else 0.0) + 0.3 * minf(float(kills) / 15.0, 1.0) + 0.1 * minf(float(captures) / 3.0, 1.0) + 0.35 * minf(float(streak) / 5.0, 1.0), 0.0, 1.0)


static func reward_odds(shift: float) -> Dictionary:
	var out := {}
	var total := 0.0
	for k in REWARD_WORST:
		out[k] = lerpf(float(REWARD_WORST[k]), float(REWARD_BEST[k]), shift)
		total += float(out[k])
	for k in out:
		out[k] = float(out[k]) / total
	return out


## Rolls the odds: "nothing" or a rarity.
static func reward_roll(shift: float) -> String:
	var odds := reward_odds(shift)
	var r := randf()
	for k in odds:
		r -= float(odds[k])
		if r <= 0.0:
			return k
	return "common"


static func odds_text(shift: float) -> String:
	var odds := reward_odds(shift)
	var parts: PackedStringArray = []
	for k in odds:
		var pct := roundi(float(odds[k]) * 100.0)
		if pct > 0:
			parts.append("%d%% %s" % [pct, k])
	return ", ".join(parts)


# ================================================================= class levels (they stay between matches)

const CLASS_MAX_LEVEL := 100
var class_xp: Dictionary = {}                      # class id -> total experience earned with that class


## XP needed to go from class level `l` to the next one.
static func class_xp_cost(l: int) -> int:
	return 120 + 35 * l


## The class level (0..100) for an amount of class XP, and how far into the next level it is.
static func class_level_for(xp: int) -> Array:
	var l := 0
	var left := xp
	while l < CLASS_MAX_LEVEL and left >= class_xp_cost(l):
		left -= class_xp_cost(l)
		l += 1
	return [l, left, class_xp_cost(l) if l < CLASS_MAX_LEVEL else 0]


func class_level(cls: String) -> int:
	return int(class_level_for(int(class_xp.get(cls, 0)))[0])


## What a class level is worth: +0.1% damage per level, +1% health per 10 levels, one more class skill every 10 levels.
func class_level_mods(cls: String) -> Dictionary:
	var l := class_level(cls)
	return {"weapon_damage": {"mult": 0.001 * l}, "spell_damage": {"mult": 0.001 * l}, "skill_damage": {"mult": 0.001 * l}, "max_health": {"mult": 0.01 * float(l / 10)}}


func class_bonus_text(cls: String) -> String:
	var l := class_level(cls)
	return "+%.1f%% damage, +%d%% health" % [0.1 * l, l / 10]


## Adds XP to a class; returns [old level, new level, skills unlocked].
func add_class_xp(cls: String, amount: int) -> Array:
	var before := class_level(cls)
	class_xp[cls] = int(class_xp.get(cls, 0)) + amount
	var after := class_level(cls)
	var unlocked := apply_class_unlocks(cls)
	save_profile()
	return [before, after, unlocked]


## Skills 1-3 are free; every 10 class levels opens the next one (levels 10 .. 70 open skills 4 .. 10). Returns the ones just opened.
func apply_class_unlocks(cls: String) -> Array:
	var list: Array = Data.classes[cls]["skills"]
	var newly: Array = []
	for k in range(1, class_level(cls) / 10 + 1):
		var idx := 2 + k
		if idx < list.size() and not unlocked_skills.has(list[idx]):
			unlocked_skills[list[idx]] = true
			newly.append(list[idx])
	if not newly.is_empty():
		skills_unlocked.emit(newly)
	return newly


## What a finished match is worth to the class you played.
static func class_xp_reward(won: bool, kills: int, captures: int) -> int:
	return 40 + 6 * kills + 12 * captures + (60 if won else 0)


# ================================================================= gold and the shop

var gold := 0                                      # the currency: earned in matches, spent in the shop on crates
var gold_gift := false
var last_gold_gain := 0
const PRICE_BASE := {"common": 40, "uncommon": 90, "rare": 220, "epic": 520, "legendary": 1300, "mythic": 3200}
const BUNDLES := [[1, 0.0, "x1"], [3, 0.10, "x3 (10% off)"], [5, 0.15, "x5 (15% off)"], [10, 0.25, "x10 (25% off)"]]


## The price of one crate of a kind and rarity: loot crates are the base, a worn weapon is cheaper, brand-new and specific crates cost more.
static func crate_price(kind: String, rarity: String) -> int:
	var mult := 1.0
	match kind:
		"any": mult = 1.0
		"weapon_old": mult = 0.7
		"weapon_new": mult = 1.4
		"armor": mult = 1.0
		"rune": mult = 1.1
		_: mult = 1.5
	return int(round(float(PRICE_BASE[rarity]) * mult))


static func bundle_price(kind: String, rarity: String, bundle: int) -> int:
	var b: Array = BUNDLES[bundle]
	return int(round(float(crate_price(kind, rarity)) * float(b[0]) * (1.0 - float(b[1]))))


func buy_crates(kind: String, rarity: String, bundle: int) -> bool:
	var cost := bundle_price(kind, rarity, bundle)
	if gold < cost:
		return false
	gold -= cost
	add_crate(kind, rarity, int(BUNDLES[bundle][0]))
	save_profile()
	return true


static func gold_reward(won: bool, kills: int, captures: int, streak: int) -> int:
	return 30 + 8 * kills + 15 * captures + (80 if won else 0) + 10 * mini(streak, 5)
