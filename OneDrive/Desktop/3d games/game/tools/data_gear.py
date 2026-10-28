"""Gear data: 55 weapons (no guns, no skins of their own), 50 armor sets of 5 pieces, runes, crate modifiers, potions, items.

Everything here is a first proposal; the owner can rename or retune it. make_data.py writes it to game/data/*.json.
Mods use the same stat ids as the classes and cards: {"stat": {"add": x}} or {"stat": {"mult": x}}.
"""
RARITIES = ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
FACTOR = {"common": 1.0, "uncommon": 1.35, "rare": 1.8, "epic": 2.4, "legendary": 3.2, "mythic": 4.2}

# --------------------------------------------------------------------------------------------- weapons
# fire: "melee" (arc in front), "projectile" (speed in m/s), "thrown" (arcing). rate = attacks per second.
ARCH = {
    "sword":    {"fire": "melee", "dmg": 55, "rate": 1.7, "range": 3.2, "arc": 100},
    "heavy":    {"fire": "melee", "dmg": 95, "rate": 0.9, "range": 3.6, "arc": 120},
    "axe":      {"fire": "melee", "dmg": 70, "rate": 1.3, "range": 3.0, "arc": 110},
    "mace":     {"fire": "melee", "dmg": 75, "rate": 1.2, "range": 2.9, "arc": 90, "stun": 0.15},
    "polearm":  {"fire": "melee", "dmg": 62, "rate": 1.3, "range": 4.8, "arc": 50},
    "scythe":   {"fire": "melee", "dmg": 72, "rate": 1.1, "range": 4.2, "arc": 170},
    "dagger":   {"fire": "melee", "dmg": 30, "rate": 3.2, "range": 2.3, "arc": 80},
    "claws":    {"fire": "melee", "dmg": 26, "rate": 3.6, "range": 2.2, "arc": 90},
    "whip":     {"fire": "melee", "dmg": 40, "rate": 1.8, "range": 6.5, "arc": 40},
    "bow":      {"fire": "projectile", "dmg": 62, "rate": 1.1, "range": 90, "speed": 70, "charge": 0.6, "ammo": 24},
    "crossbow": {"fire": "projectile", "dmg": 75, "rate": 0.9, "range": 85, "speed": 90, "charge": 0.0, "ammo": 18},
    "thrown":   {"fire": "thrown", "dmg": 48, "rate": 1.6, "range": 40, "speed": 38, "ammo": 14},
    "staff":    {"fire": "projectile", "dmg": 36, "rate": 1.6, "range": 70, "speed": 55, "mana": 9},
    "wand":     {"fire": "projectile", "dmg": 17, "rate": 5.0, "range": 55, "speed": 70, "mana": 4},
    "orb":      {"fire": "projectile", "dmg": 55, "rate": 1.1, "range": 45, "speed": 28, "mana": 12, "radius": 3.0},
    "tome":     {"fire": "projectile", "dmg": 14, "rate": 2.2, "range": 40, "speed": 50, "mana": 7, "count": 3, "spread": 7},
    "enchblade": {"fire": "melee", "dmg": 60, "rate": 1.6, "range": 3.4, "arc": 100, "mana": 5},
    "gauntlet": {"fire": "melee", "dmg": 34, "rate": 2.6, "range": 2.4, "arc": 90, "mana": 4, "shockwave": 4.0},
    "spiritbow": {"fire": "projectile", "dmg": 48, "rate": 1.3, "range": 90, "speed": 75, "charge": 0.4, "mana": 8},
}

# id, name, family, magic, tweaks, element/status on hit, description
_W = [
    # ---- non-magic (27)
    ("longsword", "Longsword", "sword", False, {}, None, "A straight, honest blade."),
    ("claymore", "Claymore", "heavy", False, {}, None, "A two-handed sword that hits very hard."),
    ("rapier", "Rapier", "sword", False, {"dmg": 40, "rate": 2.6, "range": 3.4, "arc": 40}, None, "A quick thrusting blade."),
    ("scimitar", "Scimitar", "sword", False, {"dmg": 50, "rate": 2.0, "arc": 120}, ("bleed", 3, 0.2), "A curved blade that cuts deep."),
    ("katana", "Katana", "sword", False, {"dmg": 58, "rate": 1.9, "crit": 0.1}, ("bleed", 3, 0.15), "A folded-steel blade with a sharp edge."),
    ("battle_axe", "Battle Axe", "axe", False, {}, None, "A broad axe for war."),
    ("greataxe", "Greataxe", "heavy", False, {"dmg": 105, "rate": 0.8, "arc": 150}, None, "A huge axe that sweeps a wide arc."),
    ("hatchet", "Hatchet", "axe", False, {"dmg": 45, "rate": 2.2, "range": 2.6}, None, "A light, fast axe."),
    ("war_hammer", "War Hammer", "mace", False, {"dmg": 82}, None, "Crushes armour and stuns."),
    ("flanged_mace", "Flanged Mace", "mace", False, {"dmg": 68, "rate": 1.4}, ("vulnerable", 3, 0.2), "A mace with metal flanges."),
    ("morning_star", "Morning Star", "mace", False, {"dmg": 78, "rate": 1.1}, ("bleed", 4, 0.3), "A spiked ball on a chain."),
    ("boar_spear", "Boar Spear", "polearm", False, {}, None, "A long spear that keeps enemies away."),
    ("halberd", "Halberd", "polearm", False, {"dmg": 72, "rate": 1.1, "range": 5.0, "arc": 70}, None, "Axe blade on a pole."),
    ("glaive", "Glaive", "polearm", False, {"dmg": 66, "rate": 1.4, "arc": 80}, None, "A curved blade on a long shaft."),
    ("harvest_scythe", "Harvest Scythe", "scythe", False, {}, ("weaken", 3, 0.25), "A farmer's tool turned weapon."),
    ("twin_daggers", "Twin Daggers", "dagger", False, {"dmg": 28, "rate": 3.8, "crit": 0.1}, None, "Two quick blades for the back of an enemy."),
    ("kukri", "Kukri", "dagger", False, {"dmg": 34, "rate": 3.0}, ("bleed", 3, 0.25), "A bent knife that bites."),
    ("tiger_claws", "Tiger Claws", "claws", False, {}, ("bleed", 3, 0.3), "Steel claws for a close, fast fight."),
    ("wayfarers_bow", "Wayfarer's Bow", "bow", False, {}, None, "A plain bow for long walks."),
    ("hunters_recurve", "Hunter's Recurve", "bow", False, {"dmg": 70, "charge": 0.7, "speed": 80}, None, "Powerful and a little slow."),
    ("gilded_longbow", "Gilded Longbow", "bow", False, {"dmg": 80, "rate": 0.9, "range": 110, "charge": 0.8, "speed": 90}, None, "A tall bow with gold inlay."),
    ("rangers_shortbow", "Ranger's Shortbow", "bow", False, {"dmg": 44, "rate": 1.8, "charge": 0.3, "range": 70}, None, "Quick and light."),
    ("hand_crossbow", "Hand Crossbow", "crossbow", False, {"dmg": 52, "rate": 1.5, "ammo": 24, "range": 60}, None, "A small crossbow you can shoot one-handed."),
    ("heavy_crossbow", "Heavy Crossbow", "crossbow", False, {"dmg": 105, "rate": 0.5, "range": 110, "ammo": 10}, None, "Slow, very strong."),
    ("throwing_axes", "Throwing Axes", "thrown", False, {}, ("bleed", 3, 0.25), "A bundle of axes made for throwing."),
    ("javelins", "Javelins", "thrown", False, {"dmg": 60, "rate": 1.2, "range": 55, "speed": 50}, None, "Long throwing spears."),
    ("chain_whip", "Chain Whip", "whip", False, {}, ("slow", 2, 0.2), "A whip made of links that reaches far."),
    # ---- magic (28)
    ("ember_staff", "Ember Staff", "staff", True, {}, ("burn", 3, 0.3), "Flame bolts."),
    ("frost_staff", "Frost Staff", "staff", True, {}, ("chill", 3, 0.3), "Ice bolts that chill."),
    ("storm_staff", "Storm Staff", "staff", True, {"speed": 80}, ("shock", 3, 0.3), "Fast lightning bolts."),
    ("nature_staff", "Nature Staff", "staff", True, {}, ("poison", 3, 0.2), "Thorn bolts and leaves."),
    ("bone_staff", "Bone Staff", "staff", True, {"dmg": 40}, ("weaken", 3, 0.2), "Grave bolts that weaken."),
    ("trident_staff", "Trident Staff", "staff", True, {"dmg": 38, "speed": 60}, ("slow", 2, 0.25), "A water trident that casts tide bolts."),
    ("chess_staff", "Grandmaster's Staff", "staff", True, {"dmg": 40}, ("marked", 3, 0.15), "A staff topped with a king piece."),
    ("arcane_wand", "Arcane Wand", "wand", True, {}, None, "Quick arcane sparks."),
    ("venom_wand", "Venom Wand", "wand", True, {}, ("poison", 3, 0.3), "Poison darts."),
    ("shadow_wand", "Shadow Wand", "wand", True, {"dmg": 19}, ("weaken", 2, 0.2), "Dark bolts."),
    ("crystal_orb", "Crystal Orb", "orb", True, {}, None, "A slow, big sphere of arcane force."),
    ("chrono_orb", "Chrono Orb", "orb", True, {"rate": 1.2, "speed": 34}, ("slow", 2, 0.4), "An orb that slows time around it."),
    ("star_orb", "Star Orb", "orb", True, {"dmg": 60}, None, "A sphere of starlight."),
    ("void_orb", "Void Orb", "orb", True, {"dmg": 62, "radius": 3.6}, ("vulnerable", 3, 0.3), "A hole of nothing."),
    ("ember_orb", "Ember Orb", "orb", True, {"dmg": 58}, ("burn", 3, 0.4), "A rolling ball of fire."),
    ("embers_spellbook", "Spellbook of Embers", "tome", True, {}, ("burn", 2, 0.3), "Pages of fire."),
    ("tome_of_frost", "Tome of Frost", "tome", True, {}, ("chill", 2, 0.3), "Pages of ice."),
    ("grimoire_of_shadows", "Grimoire of Shadows", "tome", True, {}, ("weaken", 2, 0.25), "Pages of dark."),
    ("codex_of_stars", "Codex of Stars", "tome", True, {"dmg": 16}, None, "Pages of starlight."),
    ("book_of_thorns", "Book of Thorns", "tome", True, {}, ("bleed", 3, 0.3), "Pages that throw thorns."),
    ("flameblade", "Flameblade", "enchblade", True, {}, ("burn", 3, 0.4), "A sword wrapped in flame."),
    ("frostbrand", "Frostbrand", "enchblade", True, {}, ("chill", 3, 0.4), "A blade of ice."),
    ("stormcaller", "Stormcaller", "enchblade", True, {}, ("shock", 3, 0.35), "A blade that crackles."),
    ("thunder_gauntlet", "Thunder Gauntlet", "gauntlet", True, {}, ("shock", 3, 0.3), "A glove that punches with thunder."),
    ("stone_fist", "Stone Fist", "gauntlet", True, {"dmg": 40, "rate": 2.2}, ("stun", 0.4, 0.2), "A fist of rock."),
    ("moonlight_bow", "Moonlight Bow", "spiritbow", True, {}, None, "A bow that makes its own arrows of light."),
    ("wisp_bow", "Wisp Bow", "spiritbow", True, {"rate": 1.6, "dmg": 40}, ("marked", 3, 0.2), "Wisps fly to the target."),
    ("phoenix_bow", "Phoenix Bow", "spiritbow", True, {"dmg": 56}, ("burn", 3, 0.35), "Fire feathers."),
]
WEAPONS = []
for _id, _name, _fam, _magic, _tw, _st, _desc in _W:
    w = {"id": _id, "name": _name, "family": _fam, "magic": _magic, "desc": _desc, **ARCH[_fam], **_tw}
    if _st:
        w["on_hit"] = {"id": _st[0], "dur": _st[1], "p": _st[2]}
    WEAPONS.append(w)
assert len(WEAPONS) == 55 and sum(1 for w in WEAPONS if w["magic"]) == 28, (len(WEAPONS), sum(1 for w in WEAPONS if w["magic"]))

# --------------------------------------------------------------------------------------------- armor
SLOTS = ["helmet", "chestplate", "shield", "leggings", "boots"]
# passive per slot at common strength; rarity factor multiplies it. Several flavours per slot so sets differ.
NONMAGIC_PASSIVES = {
    "helmet":     [("Keen Eye", "crit_chance", "add", 0.025), ("Far Sight", "sight", "mult", 0.05), ("Hard Skull", "headshot_resist", "add", 0.08), ("Clear Mind", "slow_resist", "add", 0.06)],
    "chestplate": [("Sturdy", "max_health", "mult", 0.06), ("Plated", "armor", "add", 0.06), ("Second Skin", "health_regen", "add", 0.5), ("Bulwark", "knockback_resist", "add", 0.1)],
    "shield":     [("Guard", "armor", "add", 0.05), ("Deflect", "projectile_resist", "add", 0.06), ("Ward", "spell_res", "add", 0.05), ("Bash", "block_stun", "add", 0.1)],
    "leggings":   [("Fleet", "move_speed", "mult", 0.025), ("Spring", "jump_height", "mult", 0.06), ("Endurance", "stamina", "mult", 0.08), ("Steady", "slide_distance", "mult", 0.08)],
    "boots":      [("Light Step", "move_speed", "mult", 0.02), ("Sprint Boots", "sprint_speed", "mult", 0.06), ("Grip", "slow_resist", "add", 0.08), ("Quiet Step", "sound", "mult", -0.1)],
}
MAGIC_PASSIVES = {
    "helmet":     [("Focus", "spell_damage", "mult", 0.03), ("Third Eye", "sight", "mult", 0.05), ("Crown of Mana", "mana", "mult", 0.06), ("Insight", "meter_gain", "mult", 0.06)],
    "chestplate": [("Mana Weave", "mana", "mult", 0.08), ("Warded Robe", "spell_res", "add", 0.06), ("Flow", "mana_regen", "mult", 0.08), ("Bright Heart", "max_health", "mult", 0.04)],
    "shield":     [("Rune Ward", "spell_res", "add", 0.07), ("Spell Mirror", "reflect", "add", 0.05), ("Barrier Charm", "shield_strength", "mult", 0.1), ("Glow", "aoe_radius", "mult", 0.04)],
    "leggings":   [("Quick Casting", "cast_speed", "mult", 0.04), ("Skill Flow", "cooldown_reduction", "add", 0.03), ("Light Weave", "move_speed", "mult", 0.02), ("Gale", "jump_height", "mult", 0.05)],
    "boots":      [("Ley Steps", "cooldown_reduction", "add", 0.02), ("Air Walker", "jump_height", "mult", 0.06), ("Swift Soles", "sprint_speed", "mult", 0.06), ("Silent Weave", "sound", "mult", -0.1)],
}
# (name, magic, rarity, theme tag used for the set bonus)
_SETS = [
    ("Squire's Plate", False, "common", "guard"), ("Knight's Bastion", False, "uncommon", "guard"), ("Ranger's Leathers", False, "common", "swift"),
    ("Pathfinder's Mail", False, "uncommon", "swift"), ("Dwarven Forgeplate", False, "rare", "fire"), ("Pirate Captain's Regalia", False, "epic", "pirate"),
    ("Corsair's Leather", False, "rare", "pirate"), ("Desert Nomad Wraps", False, "common", "desert"), ("Sandstalker Leathers", False, "uncommon", "desert"),
    ("Tomb Guardian's Bronze", False, "rare", "desert"), ("Mountain Warden's Furs", False, "uncommon", "frost"), ("Iceplate Bastion", False, "epic", "frost"),
    ("Gravewarden's Mail", False, "rare", "grave"), ("Foreman's Gear", False, "common", "gear"), ("Clockwork Brigandine", False, "epic", "gear"),
    ("Swamp Hunter's Hides", False, "uncommon", "venom"), ("Mangrove Scale", False, "rare", "venom"), ("Sea Wolf Chainmail", False, "rare", "tide"),
    ("Coral Shell Armor", False, "epic", "tide"), ("Forgemaster's Plate", False, "legendary", "fire"), ("Obsidian Lamellar", False, "legendary", "fire"),
    ("Skyguard Scale", False, "epic", "storm"), ("Windrider's Leather", False, "uncommon", "storm"), ("Gladiator's Harness", False, "legendary", "guard"),
    ("Chessmaster's Formal Plate", False, "mythic", "chess"),
    ("Verdant Robes", True, "common", "nature"), ("Tide Regalia", True, "uncommon", "tide"), ("Emberweave", True, "uncommon", "fire"),
    ("Rimecloth", True, "uncommon", "frost"), ("Stormweave", True, "rare", "storm"), ("Mirage Shroud", True, "rare", "desert"),
    ("Shroud Robes", True, "rare", "grave"), ("Prism Vestments", True, "epic", "arcane"), ("Alchemist Garb", True, "common", "venom"),
    ("Chrono Vestments", True, "epic", "gear"), ("Moonsilk", True, "epic", "moon"), ("Grandmaster's Suit", True, "mythic", "chess"),
    ("Sun Priest Vestments", True, "rare", "moon"), ("Starweaver Robes", True, "legendary", "moon"), ("Voidwalker Raiment", True, "legendary", "arcane"),
    ("Runesmith Robes", True, "common", "arcane"), ("Spiritcaller Mantle", True, "uncommon", "grave"), ("Witchwood Robes", True, "rare", "venom"),
    ("Dreamweaver Silks", True, "epic", "moon"), ("Seer's Regalia", True, "uncommon", "arcane"), ("Phoenix Plumage", True, "legendary", "fire"),
    ("Frostbound Vestments", True, "rare", "frost"), ("Stormcaller Mantle", True, "legendary", "storm"), ("Shadowdancer Veils", True, "mythic", "grave"),
    ("Crystal Mail", True, "epic", "arcane"),
]
assert len(_SETS) == 50 and sum(1 for s in _SETS if s[1]) == 25
SET_BONUS = {
    "guard": {"desc": "Thorns: attackers take 15% of the damage they deal.", "mods": {"armor": {"add": 0.12}, "max_health": {"mult": 0.12}}, "reflect": 0.15},
    "swift": {"desc": "Windstep: much faster, and sprinting is faster still.", "mods": {"move_speed": {"mult": 0.1}, "sprint_speed": {"mult": 0.2}}},
    "fire": {"desc": "Hearthfire: your hits burn and you resist burning.", "mods": {"spell_damage": {"mult": 0.1}}, "on_hit": {"id": "burn", "dur": 3, "p": 0.2}, "resist": {"burn": 0.6}},
    "pirate": {"desc": "Sea Legs: slide farther and gain a barrier when hit below half health.", "mods": {"slide_distance": {"mult": 0.3}}, "low_health_barrier": 40},
    "desert": {"desc": "Mirage: a chance to flicker out of sight when hit.", "mods": {"crit_chance": {"add": 0.08}, "move_speed": {"mult": 0.05}}, "dodge": 0.1},
    "frost": {"desc": "Rime: attackers are chilled and you resist chill.", "mods": {"armor": {"add": 0.1}}, "aura": {"radius": 4, "sts": [{"id": "chill", "dur": 2, "n": 1}]}, "resist": {"chill": 0.6}},
    "grave": {"desc": "Grave Hunger: heal a little on every kill.", "mods": {"max_health": {"mult": 0.1}}, "heal_on_kill": 25},
    "gear": {"desc": "Overdrive: cooldowns run 12% faster.", "mods": {"cooldown_reduction": {"add": 0.12}}},
    "venom": {"desc": "Toxic Aura: hits poison and you resist poison.", "mods": {"weapon_damage": {"mult": 0.08}}, "on_hit": {"id": "poison", "dur": 4, "p": 0.25}, "resist": {"poison": 0.6}},
    "tide": {"desc": "Riptide: move faster and resist slows.", "mods": {"move_speed": {"mult": 0.06}, "slow_resist": {"add": 0.35}}},
    "storm": {"desc": "Static Cloak: attackers are shocked.", "mods": {"move_speed": {"mult": 0.05}}, "aura": {"radius": 3, "sts": [{"id": "shock", "dur": 2, "n": 1}]}, "resist": {"shock": 0.6}},
    "nature": {"desc": "Overgrowth: regenerate health and resist roots.", "mods": {"health_regen": {"add": 3.0}}, "resist": {"root": 0.6}},
    "arcane": {"desc": "Arcane Surge: skills cost 15% less mana.", "mods": {"spell_damage": {"mult": 0.12}, "mana_cost": {"mult": -0.15}}},
    "moon": {"desc": "Moonlit: regenerate mana and take less magic damage.", "mods": {"mana_regen": {"mult": 0.3}, "spell_res": {"add": 0.15}}},
    "chess": {"desc": "Grandmaster's Plan: skills hit 10% harder, ultimate charges 15% faster.", "mods": {"skill_damage": {"mult": 0.1}, "ultimate_charge": {"mult": 0.15}}},
}
PIECE_NAMES = {False: ["Helm", "Cuirass", "Shield", "Greaves", "Boots"], True: ["Hood", "Robe", "Ward", "Leggings", "Sandals"]}
ARMOR_SETS = []
for i, (name, magic, rarity, tag) in enumerate(_SETS):
    pieces = []
    table = MAGIC_PASSIVES if magic else NONMAGIC_PASSIVES
    for j, slot in enumerate(SLOTS):
        pname, stat, kind, base = table[slot][(i + j) % 4]
        value = round(base * FACTOR[rarity], 4)
        pieces.append({"slot": slot, "name": f"{name} {PIECE_NAMES[magic][j]}", "passive": {"name": pname, "mods": {stat: {kind: value}}}})
    sid = "set_%02d_%s" % (i + 1, "".join(ch if ch.isalnum() else "_" for ch in name.lower()).strip("_"))
    sid = sid.replace("__", "_")
    ARMOR_SETS.append({"id": sid, "name": name, "magic": magic, "rarity": rarity, "theme": tag, "pieces": pieces, "set_bonus": SET_BONUS[tag]})

# --------------------------------------------------------------------------------------------- runes (30)
# effect: stat mods or a trigger. Rarer runes are stronger or stranger.
_R = [
    ("Rune of Haste", "common", {"move_speed": {"mult": 0.02}}, "+2% move speed"),
    ("Rune of Grit", "common", {"max_health": {"mult": 0.03}}, "+3% max health"),
    ("Rune of Edge", "common", {"weapon_damage": {"mult": 0.03}}, "+3% weapon damage"),
    ("Rune of Focus", "common", {"spell_damage": {"mult": 0.03}}, "+3% spell damage"),
    ("Rune of Swift Hands", "common", {"reload_speed": {"mult": 0.05}}, "+5% reload and draw speed"),
    ("Rune of Ward", "uncommon", {"armor": {"add": 0.04}}, "+4% armor"),
    ("Rune of Flow", "uncommon", {"mana_regen": {"mult": 0.1}}, "+10% mana regeneration"),
    ("Rune of the Hawk", "uncommon", {"crit_chance": {"add": 0.04}}, "+4% crit chance"),
    ("Rune of Bounty", "uncommon", {"xp_gain": {"mult": 0.06}}, "+6% XP from kills"),
    ("Rune of Mending", "uncommon", {"health_regen": {"add": 1.0}}, "Regenerate 1 health per second"),
    ("Rune of Frost Trail", "rare", {}, "Your skill 2 leaves a frost patch", {"trigger": "skill_2", "zone": {"radius": 2.5, "dur": 3, "sts": [{"id": "chill", "dur": 2}]}}),
    ("Rune of Leeching", "rare", {}, "Heal 3% of the damage you deal", {"lifesteal": 0.03}),
    ("Rune of Thorns", "rare", {"reflect": {"add": 0.06}}, "Reflect 6% of the damage you take"),
    ("Rune of the Gale", "rare", {"jump_height": {"mult": 0.1}, "move_speed": {"mult": 0.02}}, "+10% jump height"),
    ("Rune of Echoes", "rare", {"cooldown_reduction": {"add": 0.05}}, "-5% skill cooldowns"),
    ("Rune of Venom", "epic", {}, "10% chance to poison on hit", {"on_hit": {"id": "poison", "dur": 4, "p": 0.1}}),
    ("Rune of Embers", "epic", {}, "10% chance to burn on hit", {"on_hit": {"id": "burn", "dur": 3, "p": 0.1}}),
    ("Rune of the Hunt", "epic", {}, "Heal 20 on a kill", {"heal_on_kill": 20}),
    ("Rune of Barrier", "epic", {}, "Gain a barrier when you drop below 30% health (once per 40 s)", {"low_health_barrier": 50}),
    ("Rune of Momentum", "epic", {"move_speed": {"mult": 0.04}, "sprint_speed": {"mult": 0.1}}, "+4% speed and +10% sprint speed"),
    ("Rune of Storms", "legendary", {}, "Hits have 12% chance to shock the target and a nearby enemy", {"on_hit": {"id": "shock", "dur": 3, "p": 0.12}, "chain": 1}),
    ("Rune of the Phoenix", "legendary", {}, "Once per match, survive a killing blow with 30% health", {"second_life": 0.3}),
    ("Rune of the Reaper", "legendary", {}, "Kills reset your skill 1 cooldown", {"kill_reset": "skill_1"}),
    ("Rune of Ruin", "legendary", {"weapon_damage": {"mult": 0.08}, "spell_damage": {"mult": 0.08}}, "+8% weapon and spell damage"),
    ("Rune of the Titan", "legendary", {"max_health": {"mult": 0.1}, "knockback_resist": {"add": 0.3}}, "+10% health, hard to push"),
    ("Rune of Time", "mythic", {"cooldown_reduction": {"add": 0.1}}, "-10% cooldowns and your ultimate charges 20% faster", {"ultimate_charge": {"mult": 0.2}}),
    ("Rune of the Void", "mythic", {}, "Hits have 8% chance to vanish the target for 2 seconds", {"on_hit": {"id": "stun", "dur": 2, "p": 0.08}}),
    ("Rune of Dawn", "mythic", {"crit_chance": {"add": 0.1}}, "+10% crit chance and crits heal 10"),
    ("Rune of Dusk", "mythic", {"damage_dealt": {"mult": 0.1}}, "+10% damage while no enemy sees you"),
    ("Rune of Kings", "mythic", {"xp_gain": {"mult": 0.2}, "max_health": {"mult": 0.08}}, "+20% XP and +8% health"),
]
RUNES = []
for i, r in enumerate(_R, 1):
    name, rarity, mods, desc = r[:4]
    d = {"id": "rune_%02d" % i, "name": name, "rarity": rarity, "mods": mods, "desc": desc}
    if len(r) > 4:
        d["trigger"] = r[4]
    RUNES.append(d)
assert len(RUNES) == 30

# --------------------------------------------------------------------------------------------- crate modifiers
# Strength follows the crate rarity. Weapons and armor each have a pool per rarity; mythic ones also get a unique aura.
MODIFIERS = {
    "weapon": {
        "common": [("Swift", {"fire_rate": {"mult": 0.02}}, "+2% attack speed"), ("Sharpened", {"weapon_damage": {"mult": 0.02}}, "+2% damage"), ("Nimble", {"move_speed": {"mult": 0.02}}, "+2% move speed")],
        "uncommon": [("Keen", {"crit_chance": {"add": 0.03}}, "+3% crit chance"), ("Balanced", {"fire_rate": {"mult": 0.04}}, "+4% attack speed"), ("Heavy", {"weapon_damage": {"mult": 0.04}}, "+4% damage")],
        "rare": [("Vampiric", {"lifesteal": {"add": 0.03}}, "Heal 3% of damage dealt"), ("Piercing", {"armor_pierce": {"add": 0.1}}, "Ignore 10% armor"), ("Quickdraw", {"reload_speed": {"mult": 0.12}}, "+12% reload and draw speed")],
        "epic": [("Burning", {"_on_hit": {"id": "burn", "dur": 3, "p": 0.2}}, "20% chance to burn"), ("Frozen", {"_on_hit": {"id": "chill", "dur": 3, "p": 0.2}}, "20% chance to chill"), ("Venomous", {"_on_hit": {"id": "poison", "dur": 4, "p": 0.2}}, "20% chance to poison")],
        "legendary": [("Executioner", {"damage_vs_low": {"add": 0.25}}, "+25% damage to enemies under 30% health"), ("Stormtouched", {"_on_hit": {"id": "shock", "dur": 3, "p": 0.25}}, "25% chance to shock"), ("Soulbound", {"heal_on_kill": {"add": 20}}, "Heal 20 on kill")],
        "mythic": [("Dragonfire", {"_on_hit": {"id": "burn", "dur": 4, "p": 0.5}, "weapon_damage": {"mult": 0.1}}, "Fire damage: 50% to burn, +10% damage"), ("Starfall", {"_on_hit": {"id": "marked", "dur": 4, "p": 0.3}, "crit_chance": {"add": 0.1}}, "Stars mark enemies, +10% crit"), ("Void Edge", {"_on_hit": {"id": "vulnerable", "dur": 4, "p": 0.5}, "weapon_damage": {"mult": 0.1}}, "Hits tear reality: 50% to make the target vulnerable")],
    },
    "armor": {
        "common": [("Light", {"move_speed": {"mult": 0.02}}, "+2% move speed"), ("Padded", {"max_health": {"mult": 0.02}}, "+2% max health"), ("Snug", {"armor": {"add": 0.02}}, "+2% armor")],
        "uncommon": [("Sturdy", {"max_health": {"mult": 0.03}}, "+3% max health"), ("Springy", {"jump_height": {"mult": 0.06}}, "+6% jump height"), ("Calm", {"mana_regen": {"mult": 0.08}}, "+8% mana regeneration")],
        "rare": [("Reinforced", {"armor": {"add": 0.04}}, "+4% armor"), ("Lively", {"health_regen": {"add": 1.0}}, "Regenerate 1 health per second"), ("Spellproof", {"spell_res": {"add": 0.05}}, "+5% spell resistance")],
        "epic": [("Fireproof", {"_resist": {"burn": 0.4}}, "Resist burning by 40%"), ("Frostproof", {"_resist": {"chill": 0.4, "freeze": 0.3}}, "Resist chill by 40%"), ("Venomproof", {"_resist": {"poison": 0.4}}, "Resist poison by 40%")],
        "legendary": [("Thorny", {"reflect": {"add": 0.12}}, "Reflect 12% of damage"), ("Stalwart", {"knockback_resist": {"add": 0.35}, "max_health": {"mult": 0.05}}, "Hard to push, +5% health"), ("Bright", {"cooldown_reduction": {"add": 0.05}}, "-5% cooldowns")],
        "mythic": [("Flame Nova", {"_when_hit": {"nova": {"radius": 5, "dmg": 40, "sts": [{"id": "burn", "dur": 3}]}, "cooldown": 12}}, "A fire nova bursts when you are hit (every 12 s)"), ("Aurora", {"_when_hit": {"barrier": 60, "cooldown": 25}, "mana_regen": {"mult": 0.2}}, "A barrier shields you when hit (every 25 s)"), ("Grave Mantle", {"heal_on_kill": {"add": 30}, "max_health": {"mult": 0.08}}, "Heal 30 on kill, +8% health")],
    },
}
# each mythic modifier has its own aura; legendary modified gear gets the shared gold aura
AURAS = {"legendary": {"id": "gold", "name": "Gold Aura", "color": [1.0, 0.8, 0.25]},
         "Dragonfire": {"id": "flames", "name": "Flames", "color": [1.0, 0.4, 0.1]}, "Starfall": {"id": "stars", "name": "Stars", "color": [0.7, 0.8, 1.0]},
         "Void Edge": {"id": "void", "name": "Void", "color": [0.45, 0.2, 0.7]}, "Flame Nova": {"id": "embers", "name": "Embers", "color": [1.0, 0.5, 0.2]},
         "Aurora": {"id": "aurora", "name": "Aurora", "color": [0.4, 1.0, 0.8]}, "Grave Mantle": {"id": "mist", "name": "Grave Mist", "color": [0.5, 0.9, 0.6]}}
# skins rolled only by brand-new crate items (weapons have no skins of their own)
SKIN_THEMES = ["Ivory", "Obsidian", "Crimson", "Azure", "Verdant", "Gilded", "Rustic", "Frostwork", "Emberglass", "Moonlit", "Sunforged", "Voidtouched"]

# --------------------------------------------------------------------------------------------- potions and items
POTIONS = [
    {"id": "potion_health", "name": "Health Potion", "desc": "Heal 60 health.", "fx": {"heal": 60}, "color": [0.9, 0.2, 0.25]},
    {"id": "potion_mana", "name": "Mana Potion", "desc": "Restore 60 mana.", "fx": {"mana": 60}, "color": [0.25, 0.4, 1.0]},
    {"id": "potion_speed", "name": "Speed Potion", "desc": "Haste for 6 seconds.", "fx": {"sts": [{"id": "haste", "dur": 6}]}, "color": [0.9, 0.9, 0.3]},
    {"id": "potion_shield", "name": "Shield Potion", "desc": "A barrier for 6 seconds.", "fx": {"sts": [{"id": "barrier", "dur": 6}]}, "color": [0.5, 0.8, 1.0]},
    {"id": "potion_cleanse", "name": "Cleanse Potion", "desc": "Remove debuffs and ignore new ones for 3 seconds.", "fx": {"cleanse": True, "sts": [{"id": "cleanse_shield", "dur": 3}]}, "color": [1.0, 1.0, 1.0]},
    {"id": "potion_rage", "name": "Rage Potion", "desc": "+25% damage for 8 seconds.", "fx": {"sts": [{"id": "empower", "dur": 8}]}, "color": [1.0, 0.45, 0.1]},
]
ITEMS = [
    {"id": "item_bomb", "name": "Throwing Bomb", "desc": "Throw a bomb: 80 damage in a small area.", "fx": {"t": "projectile", "speed": 24, "dmg": 80, "radius": 4, "life": 2.0, "arc": True}},
    {"id": "item_trap", "name": "Snare Trap", "desc": "A hidden trap that roots whoever steps on it.", "fx": {"t": "trap", "dur": 30, "radius": 3, "dmg": 10, "sts": [{"id": "root", "dur": 2.5}]}},
    {"id": "item_scroll", "name": "Scroll", "desc": "One use of a random skill from your class.", "fx": {"scroll": True}},
    {"id": "item_smoke", "name": "Smoke Bottle", "desc": "A cloud that blinds enemies and hides you.", "fx": {"t": "aoe", "at": "self", "radius": 6, "dmg": 0, "delay": 0.1, "sts": [{"id": "blind", "dur": 3}], "sts_self": [{"id": "invisible", "dur": 2}]}},
    {"id": "item_revive", "name": "Revive Token", "desc": "Come back with 50% health once.", "fx": {"revive": 0.5}},
]
