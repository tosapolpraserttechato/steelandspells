"""Classes, skills, passives and class meters. Imported by make_data.py.

Skill effect types (fx["t"]) are interpreted by scripts/core/SkillRunner.gd:
  projectile, beam, cone, aoe, zone, sprint, teleport, leap, buff, heal, summon, wall, trap, strikes
Status applications look like {"id": "burn", "dur": 4, "n": 1, "p": 1.0} (id, duration, stacks, chance).
The class meters and the exact numbers are my proposals; the user said they will describe the meters later.
"""


def st(id_, dur=None, n=1, p=1.0, strength=None):
    d = {"id": id_, "n": n, "p": p}
    if dur is not None:
        d["dur"] = dur
    if strength is not None:
        d["strength"] = strength
    return d


SKILLS = []
CLASSES = []


def skill(cls, sid, name, slot, cd, mana, fx, desc, color, cast=0.0, tags=None, rng=45.0):
    SKILLS.append({"id": f"{cls}_{sid}", "name": name, "class": cls, "slot": slot, "cooldown": cd, "mana": mana, "cast": cast, "range": rng,
                   "fx": fx, "desc": desc, "color": color, "tags": tags or []})
    return f"{cls}_{sid}"


def add_class(cid, name, home, color, magic, health, speed, mana, weapon, passive, meter, resist, skills, signature, ultimate, blurb):
    CLASSES.append({"id": cid, "name": name, "home_map": home, "color": color, "magic": magic, "health": health, "speed": speed, "mana": mana,
                    "weapon": weapon, "passive": passive, "meter": meter, "resist": resist, "skills": skills, "signature": signature,
                    "ultimate": ultimate, "blurb": blurb})


# ------------------------------------------------------------------------------------------------ Druid
c = "druid"
s = [
    skill(c, "vine_whip", "Vine Whip", "skill", 6, 15, {"t": "projectile", "speed": 38, "dmg": 28, "radius": 0, "life": 1.2, "sts": [st("root", 1.5)], "pull": 4},
          "Lash out with a vine that damages, roots and pulls an enemy closer.", [0.3, 0.8, 0.3]),
    skill(c, "spore_cloud", "Spore Cloud", "skill", 12, 25, {"t": "zone", "at": "target", "radius": 6, "dur": 6, "tick": 1.0, "dmg": 6, "sts": [st("poison", 4), st("slow", 2)]},
          "A cloud of spores that poisons and slows everyone in it.", [0.6, 0.8, 0.3]),
    skill(c, "thorn_skin", "Thorn Skin", "skill", 16, 20, {"t": "buff", "dur": 6, "mods": {"armor": {"add": 0.25}}, "reflect": 0.35, "sts_self": [st("barrier", 6)]},
          "Grow thorns: gain armor and a barrier, and reflect part of the damage you take.", [0.4, 0.6, 0.2]),
    skill(c, "regrowth", "Regrowth", "skill", 14, 30, {"t": "heal", "amount": 40, "radius": 8, "allies": True, "regen": 6},
          "Heal yourself and nearby allies, then keep healing for a few seconds.", [0.4, 0.9, 0.4]),
    skill(c, "wild_dash", "Wild Sprint", "skill", 9, 15, {"t": "sprint", "dur": 3.0, "speed": 0.5, "dmg": 20, "sts": [st("slow", 2)]},
          "Sprint as a rush of leaves, slowing enemies you run through.", [0.5, 0.85, 0.35]),
    skill(c, "bloom", "Healing Bloom", "skill", 18, 30, {"t": "zone", "at": "target", "radius": 6, "dur": 8, "tick": 1.0, "heal": 8, "sts": []},
          "A flower that heals allies standing near it.", [0.95, 0.6, 0.8]),
]
sig = skill(c, "wild_bloom", "Wild Bloom", "signature", 14, 35, {"t": "aoe", "at": "target", "radius": 8, "dmg": 60, "delay": 0.6, "sts": [st("root", 1.5)]},
            "Giant roots burst from the ground, damaging and rooting every enemy in the area.", [0.35, 0.85, 0.3])
ult = skill(c, "forests_wrath", "Forest's Wrath", "ultimate", 0, 0, {"t": "zone", "at": "target", "radius": 12, "dur": 6, "tick": 0.75, "dmg": 28, "heal": 10, "sts": [st("root", 1.0)], "pull": 6},
            "The forest wakes: a huge area roots and tears enemies while healing your team.", [0.2, 0.8, 0.2])
add_class(c, "Druid", "flora_forest", [0.3, 0.75, 0.3], True, 115, 1.0, 120, "nature_staff",
          {"id": "druid_passive", "name": "Verdant Skin", "desc": "Regenerate health and resist slows.", "mods": {"health_regen": {"add": 1.5}, "slow_resist": {"add": 0.3}}},
          {"id": "growth", "name": "Growth", "desc": "Fills as you heal or deal damage. More growth means stronger regeneration; at full, hits root enemies.",
           "gain": {"damage_dealt": 0.25, "heal_done": 0.3}, "decay": 3.0, "mods_scaled": {"health_regen": {"add": 4.0}}, "full": {"sts_on_hit": [st("root", 0.8, p=0.35)], "mods": {"spell_damage": {"mult": 0.15}}}},
          {}, s, sig, ult, "A nature caster who roots, heals and controls the ground.")

# ------------------------------------------------------------------------------------------------ Sea King
c = "sea_king"
s = [
    skill(c, "tidal_wave", "Tidal Wave", "skill", 9, 25, {"t": "projectile", "speed": 26, "dmg": 30, "radius": 3.5, "life": 1.8, "knock": 14, "sts": [st("slow", 2)]},
          "Send a wave that knocks enemies back and slows them.", [0.2, 0.6, 0.95]),
    skill(c, "water_jet", "Water Jet", "skill", 7, 20, {"t": "beam", "range": 32, "dmg": 34, "width": 0.4, "knock": 8, "sts": []},
          "A high-pressure jet that hits instantly and pushes the target.", [0.3, 0.75, 1.0]),
    skill(c, "bubble_shield", "Bubble Shield", "skill", 16, 25, {"t": "buff", "dur": 5, "sts_self": [st("barrier", 5)], "mods": {"move_speed": {"mult": 0.05}}},
          "Wrap yourself in a bubble that absorbs damage.", [0.5, 0.85, 1.0]),
    skill(c, "riptide", "Riptide", "skill", 8, 15, {"t": "sprint", "dur": 3.0, "speed": 0.55, "dmg": 18, "sts": [st("slow", 1.5)], "trail": {"radius": 1.6, "dur": 2.5, "dmg": 0, "sts": [st("slow", 1.5)]}},
          "Sprint on a riptide, leaving slowing water behind you.", [0.2, 0.7, 0.9]),
    skill(c, "coral_spikes", "Coral Spikes", "skill", 13, 25, {"t": "zone", "at": "target", "radius": 5, "dur": 7, "tick": 0.8, "dmg": 8, "sts": [st("slow", 1.5), st("bleed", 3)]},
          "A patch of sharp coral that slows and cuts anyone in it.", [1.0, 0.5, 0.45]),
    skill(c, "healing_tide", "Healing Tide", "skill", 15, 30, {"t": "heal", "amount": 45, "radius": 9, "allies": True, "cleanse": True},
          "A calm wave that heals nearby allies and washes away debuffs.", [0.4, 0.9, 0.95]),
]
sig = skill(c, "maelstrom", "Maelstrom", "signature", 15, 35, {"t": "aoe", "at": "self", "radius": 9, "dmg": 55, "delay": 0.3, "pull": 9, "sts": [st("slow", 2.5)]},
            "A whirlpool pulls every nearby enemy toward you and hurts them.", [0.15, 0.55, 0.9])
ult = skill(c, "tsunami", "Tsunami", "ultimate", 0, 0, {"t": "cone", "range": 30, "angle": 70, "dmg": 190, "knock": 26, "sts": [st("slow", 3), st("stun", 0.8)]},
            "A towering wave smashes through everything in front of you.", [0.1, 0.5, 1.0])
add_class(c, "Sea King", "underwater_ocean", [0.15, 0.6, 0.9], True, 125, 1.0, 120, "trident_staff",
          {"id": "sea_king_passive", "name": "Tidebound", "desc": "Move faster and take less damage from slows.", "mods": {"move_speed": {"mult": 0.04}, "slow_resist": {"add": 0.2}, "max_health": {"mult": 0.05}}},
          {"id": "tide", "name": "Tide", "desc": "Rises as you take or deal damage. High tide boosts movement and knockback; at full, skills splash twice.",
           "gain": {"damage_dealt": 0.2, "damage_taken": 0.25}, "decay": 3.5, "mods_scaled": {"move_speed": {"mult": 0.18}}, "full": {"mods": {"aoe_radius": {"mult": 0.2}}}},
          {"burn": 0.25}, s, sig, ult, "A water lord who pushes, pulls and soaks the battlefield.")

# ------------------------------------------------------------------------------------------------ Flame Lord
c = "flame_lord"
s = [
    skill(c, "fireball", "Fireball", "skill", 6, 25, {"t": "projectile", "speed": 34, "dmg": 45, "radius": 3.5, "life": 2.5, "sts": [st("burn", 4)]},
          "A fireball that explodes on impact and sets enemies on fire.", [1.0, 0.45, 0.1]),
    skill(c, "flame_cone", "Flame Breath", "skill", 8, 25, {"t": "cone", "range": 11, "angle": 55, "dmg": 50, "sts": [st("burn", 4, 2)]},
          "A short burst of flame in front of you.", [1.0, 0.55, 0.1]),
    skill(c, "fire_dash", "Fire Sprint", "skill", 9, 15, {"t": "sprint", "dur": 3.0, "speed": 0.5, "dmg": 25, "sts": [st("burn", 3)], "trail": {"radius": 2.0, "dur": 3, "dmg": 6, "fire": True, "sts": [st("burn", 2)]}},
          "Sprint leaving a trail of fire.", [1.0, 0.4, 0.1]),
    skill(c, "ember_shield", "Ember Shield", "skill", 16, 25, {"t": "buff", "dur": 6, "sts_self": [st("barrier", 6)], "reflect": 0.3, "mods": {"armor": {"add": 0.1}}},
          "Wrap yourself in embers: a barrier that burns attackers.", [1.0, 0.6, 0.2]),
    skill(c, "magma_pool", "Magma Pool", "skill", 13, 30, {"t": "zone", "at": "target", "radius": 5, "dur": 7, "tick": 0.8, "dmg": 10, "sts": [st("burn", 3)]},
          "A pool of molten rock that burns anyone standing in it.", [1.0, 0.35, 0.05]),
    skill(c, "heat_wave", "Heat Wave", "skill", 14, 30, {"t": "aoe", "at": "self", "radius": 7, "dmg": 30, "delay": 0.2, "sts": [st("burn", 3), st("blind", 1.5)]},
          "A wave of heat that scorches and blinds nearby enemies.", [1.0, 0.7, 0.3]),
]
sig = skill(c, "inferno_ring", "Inferno Ring", "signature", 15, 35, {"t": "aoe", "at": "self", "radius": 8, "dmg": 70, "delay": 0.4, "sts": [st("burn", 5, 2)]},
            "A ring of fire erupts around you and sets everything it touches alight.", [1.0, 0.4, 0.05])
ult = skill(c, "supernova", "Supernova", "ultimate", 0, 0, {"t": "aoe", "at": "target", "radius": 14, "dmg": 210, "delay": 1.4, "sts": [st("burn", 6, 3)], "knock": 10},
            "A marked area detonates in a huge fiery blast.", [1.0, 0.55, 0.1])
add_class(c, "Flame Lord", "volcano_forge", [1.0, 0.4, 0.1], True, 120, 1.0, 120, "fire_staff",
          {"id": "flame_lord_passive", "name": "Heart of Fire", "desc": "Hits have a chance to burn. Resist burning.", "mods": {"spell_damage": {"mult": 0.05}}, "on_hit_status": {"id": "burn", "dur": 3, "p": 0.12}},
          {"id": "heat", "name": "Heat", "desc": "Builds as you deal damage. More heat means more damage; at full, every hit burns.",
           "gain": {"damage_dealt": 0.35, "kill": 15}, "decay": 4.0, "mods_scaled": {"spell_damage": {"mult": 0.25}, "weapon_damage": {"mult": 0.1}}, "full": {"sts_on_hit": [st("burn", 3)], "mods": {"fire_rate": {"mult": 0.1}}}},
          {"burn": 0.6}, s, sig, ult, "A fire caster who burns everything in reach.")

# ------------------------------------------------------------------------------------------------ Frost Mage
c = "frost_mage"
s = [
    skill(c, "ice_shard", "Ice Shard", "skill", 4, 12, {"t": "projectile", "speed": 55, "dmg": 28, "radius": 0, "life": 1.5, "sts": [st("chill", 4, 2)], "count": 3, "spread": 6},
          "Three icy shards that chill whatever they hit.", [0.6, 0.9, 1.0]),
    skill(c, "frost_nova", "Frost Nova", "skill", 12, 30, {"t": "aoe", "at": "self", "radius": 7, "dmg": 30, "delay": 0.25, "sts": [st("chill", 4, 3), st("root", 1.2)]},
          "A burst of cold that damages, chills and holds enemies close to you.", [0.5, 0.85, 1.0]),
    skill(c, "ice_wall", "Ice Wall", "skill", 15, 30, {"t": "wall", "len": 9, "height": 3.4, "dur": 6},
          "Raise a wall of ice that blocks shots and movement.", [0.7, 0.95, 1.0]),
    skill(c, "blink", "Frost Blink", "skill", 8, 20, {"t": "teleport", "dist": 14, "sts_self": [st("haste", 2)]},
          "Blink forward and gain a short burst of speed.", [0.65, 0.9, 1.0]),
    skill(c, "blizzard", "Blizzard", "skill", 14, 35, {"t": "zone", "at": "target", "radius": 7, "dur": 6, "tick": 0.7, "dmg": 7, "sts": [st("chill", 3), st("blind", 1.0)]},
          "A storm of snow that chills and blinds anyone inside.", [0.85, 0.95, 1.0]),
    skill(c, "glacial_armor", "Glacial Armor", "skill", 16, 25, {"t": "buff", "dur": 6, "sts_self": [st("barrier", 6)], "aura": {"radius": 5, "sts": [st("chill", 2)]}},
          "A shell of ice that absorbs damage and chills enemies who get close.", [0.5, 0.8, 1.0]),
]
sig = skill(c, "avalanche_strike", "Avalanche Strike", "signature", 14, 35, {"t": "aoe", "at": "target", "radius": 9, "dmg": 65, "delay": 0.7, "sts": [st("chill", 4, 3)], "knock": 6},
            "Snow and ice crash down on a large area.", [0.8, 0.95, 1.0])
ult = skill(c, "absolute_zero", "Absolute Zero", "ultimate", 0, 0, {"t": "aoe", "at": "self", "radius": 16, "dmg": 120, "delay": 0.8, "sts": [st("freeze", 3), st("chill", 5, 5)]},
            "Everything around you freezes solid.", [0.7, 0.95, 1.0])
add_class(c, "Frost Mage", "frozen_peaks", [0.5, 0.85, 1.0], True, 110, 1.0, 130, "frost_staff",
          {"id": "frost_mage_passive", "name": "Cold Heart", "desc": "Hits chill enemies. Resist chill.", "mods": {"spell_res": {"add": 0.08}}, "on_hit_status": {"id": "chill", "dur": 3, "p": 0.18}},
          {"id": "frost", "name": "Frostbite", "desc": "Builds as you chill enemies. More frost means slower enemies; at full, your next hits freeze.",
           "gain": {"damage_dealt": 0.3, "status_applied": 4}, "decay": 3.5, "mods_scaled": {"cooldown_reduction": {"add": 0.2}}, "full": {"sts_on_hit": [st("chill", 3, 2)], "mods": {"spell_damage": {"mult": 0.2}}}},
          {"chill": 0.6, "freeze": 0.5}, s, sig, ult, "An ice mage who chills, freezes and walls off the fight.")

# ------------------------------------------------------------------------------------------------ Thunder God
c = "thunder_god"
s = [
    skill(c, "lightning_bolt", "Lightning Bolt", "skill", 5, 20, {"t": "beam", "range": 55, "dmg": 42, "width": 0.3, "sts": [st("shock", 4)]},
          "An instant bolt of lightning.", [1.0, 0.95, 0.3]),
    skill(c, "thunder_clap", "Thunder Clap", "skill", 11, 30, {"t": "aoe", "at": "self", "radius": 7, "dmg": 35, "delay": 0.2, "sts": [st("stun", 0.9)], "knock": 7},
          "A thunderclap that stuns and shoves everyone near you.", [1.0, 0.9, 0.4]),
    skill(c, "storm_dash", "Storm Sprint", "skill", 8, 15, {"t": "sprint", "dur": 2.8, "speed": 0.7, "dmg": 22, "sts": [st("shock", 3)]},
          "Sprint as lightning, shocking everything you run through.", [1.0, 0.95, 0.5]),
    skill(c, "chain_lightning", "Chain Lightning", "skill", 9, 30, {"t": "beam", "range": 38, "dmg": 34, "width": 0.3, "chain": {"n": 3, "range": 9, "falloff": 0.8}, "sts": [st("shock", 3)]},
          "Lightning that jumps to nearby enemies.", [0.9, 0.95, 0.4]),
    skill(c, "static_field", "Static Field", "skill", 14, 30, {"t": "zone", "at": "target", "radius": 6, "dur": 6, "tick": 0.6, "dmg": 9, "sts": [st("shock", 3)]},
          "A crackling field that shocks anyone inside.", [1.0, 0.9, 0.3]),
    skill(c, "sky_hammer", "Sky Hammer", "skill", 12, 30, {"t": "leap", "up": 11, "fwd": 10, "slam": {"radius": 6, "dmg": 55, "sts": [st("stun", 0.7)]}},
          "Leap into the air and slam down with the force of thunder.", [1.0, 0.85, 0.2]),
]
sig = skill(c, "thunderstorm", "Thunderstorm", "signature", 14, 35, {"t": "aoe", "at": "target", "radius": 10, "dmg": 70, "delay": 0.7, "sts": [st("shock", 5, 2)]},
            "Lightning rains over a wide area.", [1.0, 0.95, 0.35])
ult = skill(c, "wrath_of_the_heavens", "Wrath of the Heavens", "ultimate", 0, 0, {"t": "strikes", "count": 6, "radius": 5, "dmg": 120, "range": 45, "sts": [st("shock", 5, 3), st("stun", 0.8)]},
            "Six lightning strikes hammer the nearest enemies.", [1.0, 0.95, 0.3])
add_class(c, "Thunder God", "sky_islands", [1.0, 0.9, 0.3], True, 115, 1.04, 125, "storm_staff",
          {"id": "thunder_god_passive", "name": "Storm's Favour", "desc": "Move faster and shock enemies on hit.", "mods": {"move_speed": {"mult": 0.04}}, "on_hit_status": {"id": "shock", "dur": 3, "p": 0.1}},
          {"id": "charge", "name": "Charge", "desc": "Builds as you move and deal damage. At full, your next skill chains lightning.",
           "gain": {"damage_dealt": 0.25, "moving": 3.0}, "decay": 2.5, "mods_scaled": {"fire_rate": {"mult": 0.2}}, "full": {"sts_on_hit": [st("shock", 3)], "mods": {"cast_speed": {"mult": 0.3}}}},
          {"shock": 0.6}, s, sig, ult, "A storm caster who is fast, shocking and hits from range.")

# ------------------------------------------------------------------------------------------------ Pharaoh
c = "pharaoh"
s = [
    skill(c, "sand_blast", "Sand Blast", "skill", 7, 20, {"t": "cone", "range": 12, "angle": 50, "dmg": 38, "sts": [st("blind", 2.5)], "knock": 5},
          "A blast of sand that damages and blinds.", [0.9, 0.75, 0.4]),
    skill(c, "scarab_swarm", "Scarab Swarm", "skill", 9, 25, {"t": "projectile", "speed": 22, "dmg": 20, "radius": 2.5, "life": 2.2, "sts": [st("bleed", 5, 2)], "homing": 4},
          "A swarm of scarabs that homes in and gnaws at the target.", [0.3, 0.3, 0.2]),
    skill(c, "tomb_curse", "Tomb Curse", "skill", 11, 25, {"t": "beam", "range": 36, "dmg": 20, "width": 0.4, "sts": [st("weaken", 5), st("vulnerable", 5)]},
          "A curse that makes the target weak and easy to hurt.", [0.5, 0.2, 0.7]),
    skill(c, "sand_shield", "Sand Shield", "skill", 16, 25, {"t": "buff", "dur": 6, "sts_self": [st("barrier", 6)], "mods": {"armor": {"add": 0.15}}},
          "Swirling sand wraps you and absorbs damage.", [0.95, 0.8, 0.45]),
    skill(c, "mummy_wrap", "Mummy Wrap", "skill", 10, 20, {"t": "projectile", "speed": 36, "dmg": 18, "radius": 0, "life": 1.4, "sts": [st("root", 2)]},
          "Bandages that bind an enemy in place.", [0.9, 0.9, 0.8]),
    skill(c, "sandstorm", "Sandstorm", "skill", 14, 35, {"t": "zone", "at": "target", "radius": 7, "dur": 6, "tick": 0.7, "dmg": 6, "sts": [st("blind", 1.2), st("slow", 1.0)]},
          "A whirling storm that blinds and slows.", [0.9, 0.7, 0.35]),
]
sig = skill(c, "plague_of_locusts", "Plague of Locusts", "signature", 14, 35, {"t": "aoe", "at": "target", "radius": 9, "dmg": 60, "delay": 0.6, "sts": [st("weaken", 5), st("bleed", 4, 2)]},
            "A cloud of locusts devours everything in the area.", [0.7, 0.8, 0.2])
ult = skill(c, "eclipse_of_ra", "Eclipse of Ra", "ultimate", 0, 0, {"t": "zone", "at": "self", "radius": 13, "dur": 5, "tick": 0.6, "dmg": 30, "sts": [st("stun", 0.5), st("vulnerable", 3)], "pull": 8},
            "The sun goes dark: enemies are pulled in, stunned and ripped apart.", [1.0, 0.8, 0.2])
add_class(c, "Pharaoh", "desert_tomb", [0.95, 0.75, 0.3], True, 125, 1.0, 115, "scepter",
          {"id": "pharaoh_passive", "name": "Divine Rule", "desc": "Your debuffs last longer and you resist curses.", "mods": {"status_duration": {"mult": 0.0}, "max_health": {"mult": 0.04}}, "debuff_boost": 0.25},
          {"id": "devotion", "name": "Devotion", "desc": "Builds as you curse and hit enemies. More devotion means stronger skills; at full, skills curse targets.",
           "gain": {"damage_dealt": 0.25, "status_applied": 5}, "decay": 3.0, "mods_scaled": {"skill_damage": {"mult": 0.3}}, "full": {"sts_on_hit": [st("weaken", 3)], "mods": {"cooldown_reduction": {"add": 0.15}}}},
          {"blind": 0.6}, s, sig, ult, "A cursing ruler who weakens, blinds and binds.")

# ------------------------------------------------------------------------------------------------ Necromancer
c = "necromancer"
s = [
    skill(c, "soul_bolt", "Soul Bolt", "skill", 5, 18, {"t": "projectile", "speed": 36, "dmg": 34, "radius": 0, "life": 1.6, "sts": [st("weaken", 3)], "lifesteal": 0.4},
          "A bolt of spirit energy that heals you for part of the damage.", [0.55, 0.9, 0.75]),
    skill(c, "bone_spear", "Bone Spear", "skill", 8, 22, {"t": "beam", "range": 40, "dmg": 40, "width": 0.5, "pierce": True, "sts": [st("bleed", 4, 2)]},
          "A spear of bone that pierces everything in a line.", [0.9, 0.9, 0.8]),
    skill(c, "raise_skeleton", "Raise Skeleton", "skill", 14, 35, {"t": "summon", "kind": "skeleton", "count": 2, "hp": 60, "dmg": 8, "rate": 0.6, "dur": 15, "range": 24},
          "Raise two skeletons that shoot nearby enemies.", [0.85, 0.85, 0.75]),
    skill(c, "death_coil", "Death Coil", "skill", 9, 25, {"t": "projectile", "speed": 32, "dmg": 45, "radius": 0, "life": 1.6, "sts": [], "lifesteal": 1.0},
          "A coil of dark magic that drains life.", [0.5, 0.2, 0.6]),
    skill(c, "wither", "Wither", "skill", 11, 25, {"t": "beam", "range": 38, "dmg": 18, "width": 0.4, "sts": [st("weaken", 6), st("poison", 4)]},
          "A curse that withers the target.", [0.45, 0.5, 0.3]),
    skill(c, "grave_step", "Grave Step", "skill", 9, 20, {"t": "teleport", "dist": 15, "sts_self": [st("invisible", 1.5)]},
          "Slip through the grave and reappear ahead, briefly unseen.", [0.4, 0.4, 0.5]),
]
sig = skill(c, "grave_eruption", "Grave Eruption", "signature", 14, 35, {"t": "aoe", "at": "target", "radius": 8, "dmg": 70, "delay": 0.7, "sts": [st("slow", 3)], "knock": 6},
            "Bone hands tear out of the ground and hurl enemies.", [0.7, 0.75, 0.6])
ult = skill(c, "army_of_the_dead", "Army of the Dead", "ultimate", 0, 0, {"t": "summon", "kind": "skeleton", "count": 5, "hp": 120, "dmg": 14, "rate": 0.5, "dur": 18, "range": 28, "burst": {"radius": 9, "dmg": 80, "sts": [st("slow", 2)]}},
            "Five armoured skeletons rise and fight for you.", [0.7, 0.9, 0.7])
add_class(c, "Necromancer", "shadow_crypt", [0.55, 0.45, 0.7], True, 105, 0.98, 130, "bone_staff",
          {"id": "necromancer_passive", "name": "Death's Hunger", "desc": "Heal when enemies die near you.", "mods": {"lifesteal": {"add": 0.03}}, "on_kill_heal": 0.08},
          {"id": "souls", "name": "Souls", "desc": "Collect souls from kills. More souls mean more damage; at full, enemies you hit are weakened.",
           "gain": {"kill": 25, "damage_dealt": 0.15}, "decay": 1.0, "mods_scaled": {"spell_damage": {"mult": 0.3}}, "full": {"sts_on_hit": [st("weaken", 3)], "mods": {"lifesteal": {"add": 0.06}}}},
          {"poison": 0.5}, s, sig, ult, "A dark caster who drains life and raises the dead.")

# ------------------------------------------------------------------------------------------------ Arcanist
c = "arcanist"
s = [
    skill(c, "arcane_missiles", "Arcane Missiles", "skill", 6, 28, {"t": "projectile", "speed": 40, "dmg": 18, "radius": 0, "life": 2.0, "count": 5, "spread": 8, "homing": 5, "sts": []},
          "Five homing missiles of pure arcane energy.", [0.8, 0.5, 1.0]),
    skill(c, "mana_shield", "Mana Shield", "skill", 14, 20, {"t": "buff", "dur": 6, "sts_self": [st("barrier", 6)], "mods": {"mana_regen": {"mult": 0.3}}},
          "A shield of mana that absorbs damage and speeds mana recovery.", [0.6, 0.5, 1.0]),
    skill(c, "blink", "Arcane Blink", "skill", 7, 20, {"t": "teleport", "dist": 16},
          "Blink forward.", [0.75, 0.55, 1.0]),
    skill(c, "silence_ray", "Silence Ray", "skill", 11, 25, {"t": "beam", "range": 40, "dmg": 18, "width": 0.35, "sts": [st("silence", 3)]},
          "A ray that stops the target from casting.", [0.6, 0.6, 0.95]),
    skill(c, "arcane_orb", "Arcane Orb", "skill", 10, 35, {"t": "projectile", "speed": 14, "dmg": 80, "radius": 4.5, "life": 3.5, "sts": [st("slow", 2)]},
          "A slow orb that bursts in a wide blast.", [0.85, 0.4, 1.0]),
    skill(c, "rune_trap", "Rune Trap", "skill", 10, 25, {"t": "trap", "radius": 3.5, "dmg": 70, "dur": 25, "sts": [st("root", 1.8), st("silence", 2)]},
          "Place a rune that springs on the first enemy who steps on it.", [0.7, 0.5, 1.0]),
]
sig = skill(c, "arcane_explosion", "Arcane Explosion", "signature", 14, 35, {"t": "aoe", "at": "self", "radius": 8, "dmg": 65, "delay": 0.4, "sts": [st("silence", 2.5)], "knock": 6},
            "A burst of raw magic that hurts and silences enemies around you.", [0.8, 0.5, 1.0])
ult = skill(c, "arcane_cataclysm", "Arcane Cataclysm", "ultimate", 0, 0, {"t": "aoe", "at": "target", "radius": 13, "dmg": 220, "delay": 1.3, "sts": [st("silence", 4), st("stun", 0.8)]},
            "A cataclysmic blast that silences everyone caught in it.", [0.85, 0.45, 1.0])
add_class(c, "Arcanist", "crystal_caves", [0.75, 0.5, 1.0], True, 100, 1.0, 160, "arcane_wand",
          {"id": "arcanist_passive", "name": "Arcane Mastery", "desc": "More mana and faster mana regeneration.", "mods": {"max_mana": {"mult": 0.15}, "mana_regen": {"mult": 0.2}}},
          {"id": "arcana", "name": "Arcana", "desc": "Builds as you spend mana. More arcana means cheaper skills; at full, skills cost nothing for a moment.",
           "gain": {"mana_spent": 0.4}, "decay": 3.0, "mods_scaled": {"cooldown_reduction": {"add": 0.25}}, "full": {"mods": {"mana_cost": {"mult": -0.5}}}},
          {"silence": 0.5}, s, sig, ult, "A pure mage with lots of mana and flexible skills.")

# ------------------------------------------------------------------------------------------------ Poison Brewer
c = "poison_brewer"
s = [
    skill(c, "poison_flask", "Poison Flask", "skill", 7, 20, {"t": "projectile", "speed": 26, "dmg": 25, "radius": 3.5, "life": 2.0, "grav": 9, "sts": [st("poison", 5, 2)]},
          "A flask that shatters in a cloud of poison.", [0.5, 0.9, 0.2]),
    skill(c, "toxic_gas", "Toxic Gas", "skill", 13, 30, {"t": "zone", "at": "target", "radius": 6.5, "dur": 7, "tick": 0.8, "dmg": 7, "sts": [st("poison", 4)]},
          "A lingering cloud of toxic gas.", [0.6, 0.85, 0.15]),
    skill(c, "antidote", "Antidote", "skill", 14, 30, {"t": "heal", "amount": 35, "radius": 8, "allies": True, "cleanse": True},
          "Heal and cleanse yourself and nearby allies.", [0.7, 1.0, 0.7]),
    skill(c, "acid_spit", "Acid Spit", "skill", 6, 18, {"t": "beam", "range": 24, "dmg": 30, "width": 0.4, "sts": [st("poison", 4), st("vulnerable", 3)]},
          "Acid that eats armour and burns.", [0.75, 1.0, 0.2]),
    skill(c, "sticky_brew", "Sticky Brew", "skill", 11, 25, {"t": "zone", "at": "target", "radius": 5.5, "dur": 6, "tick": 1.0, "dmg": 3, "sts": [st("slow", 1.2), st("root", 0.5, p=0.25)]},
          "A puddle of goo that slows and sometimes sticks enemies.", [0.55, 0.45, 0.2]),
    skill(c, "elixir", "Swift Elixir", "skill", 16, 25, {"t": "buff", "dur": 7, "sts_self": [st("haste", 7), st("empower", 7)], "mods": {}},
          "Drink a potion for speed and extra damage.", [1.0, 0.7, 0.3]),
]
sig = skill(c, "cauldron_burst", "Cauldron Burst", "signature", 14, 35, {"t": "aoe", "at": "target", "radius": 8, "dmg": 55, "delay": 0.6, "sts": [st("poison", 6, 3)]},
            "A giant cauldron bursts and drenches the area in poison.", [0.45, 0.9, 0.2])
ult = skill(c, "plague_cloud", "Plague Cloud", "ultimate", 0, 0, {"t": "zone", "at": "target", "radius": 13, "dur": 8, "tick": 0.7, "dmg": 20, "sts": [st("poison", 5, 3), st("weaken", 3)]},
            "A vast cloud of plague that poisons and weakens everyone inside.", [0.35, 0.85, 0.15])
add_class(c, "Poison Brewer", "toxic_swamp", [0.5, 0.8, 0.2], True, 110, 1.0, 120, "venom_wand",
          {"id": "poison_brewer_passive", "name": "Toxic Blood", "desc": "Hits poison. Poison hurts more.", "mods": {}, "on_hit_status": {"id": "poison", "dur": 4, "p": 0.18}, "debuff_boost": 0.15},
          {"id": "toxin", "name": "Toxin", "desc": "Builds as poison ticks on enemies. More toxin means stronger poison; at full, poison spreads on hit.",
           "gain": {"damage_dealt": 0.2, "status_applied": 4}, "decay": 2.5, "mods_scaled": {"spell_damage": {"mult": 0.25}}, "full": {"sts_on_hit": [st("poison", 3, 2)], "mods": {"lifesteal": {"add": 0.04}}}},
          {"poison": 0.8}, s, sig, ult, "A brewer who poisons, cleanses and drinks potions.")

# ------------------------------------------------------------------------------------------------ Pirate Captain (non-magic)
c = "pirate_captain"
s = [
    skill(c, "cannon_shot", "Cannon Shot", "skill", 8, 0, {"t": "projectile", "speed": 45, "dmg": 80, "radius": 4.0, "life": 2.5, "grav": 4, "knock": 8, "sts": []},
          "Fire a small cannon: a heavy shell with a wide blast.", [0.3, 0.3, 0.3]),
    skill(c, "grapple_dash", "Grapple Sprint", "skill", 9, 0, {"t": "sprint", "dur": 2.5, "speed": 0.6, "dmg": 10, "sts": []},
          "Haul yourself along with a grappling hook for a long, fast sprint.", [0.6, 0.5, 0.35]),
    skill(c, "flintlock_volley", "Flintlock Volley", "skill", 9, 0, {"t": "projectile", "speed": 90, "dmg": 22, "radius": 0, "life": 0.8, "count": 6, "spread": 7, "sts": []},
          "Fire a volley of six shots in an arc.", [0.7, 0.6, 0.4]),
    skill(c, "smoke_bomb", "Smoke Bomb", "skill", 13, 0, {"t": "zone", "at": "target", "radius": 6, "dur": 7, "tick": 1.0, "dmg": 0, "sts": [st("blind", 1.5)]},
          "A cloud of smoke that blinds enemies inside.", [0.55, 0.55, 0.55]),
    skill(c, "rum_heal", "Rum Ration", "skill", 15, 0, {"t": "buff", "dur": 6, "sts_self": [st("haste", 4), st("regen", 6)], "heal": 25},
          "A swig of rum: heal, regenerate and run.", [0.8, 0.5, 0.2]),
    skill(c, "sabre_rush", "Sabre Rush", "skill", 8, 0, {"t": "sprint", "dur": 2.5, "speed": 0.7, "dmg": 55, "sts": [st("bleed", 4, 2)]},
          "Sprint with a cutlass out, slashing everyone you run through.", [0.8, 0.8, 0.85]),
]
sig = skill(c, "broadside", "Broadside", "signature", 14, 0, {"t": "aoe", "at": "target", "radius": 9, "dmg": 70, "delay": 0.8, "sts": [st("stun", 0.6)], "knock": 10},
            "Call a broadside: cannonballs smash down on the target area.", [0.35, 0.35, 0.4])
ult = skill(c, "ghost_ship", "Ghost Ship", "ultimate", 0, 0, {"t": "zone", "at": "target", "radius": 12, "dur": 8, "tick": 0.5, "dmg": 32, "sts": [st("slow", 1.0)], "blast": True},
            "A phantom ship rakes the area with cannon fire for several seconds.", [0.4, 0.8, 0.8])
add_class(c, "Pirate Captain", "pirate_cove", [0.8, 0.35, 0.25], False, 130, 1.0, 0, "flintlock_rifle",
          {"id": "pirate_captain_passive", "name": "Sea Legs", "desc": "More health, better gun handling and less knockback.", "mods": {"max_health": {"mult": 0.06}, "spread": {"mult": -0.1}, "knockback_taken": {"mult": -0.3}}},
          {"id": "bounty", "name": "Bounty", "desc": "Builds as you get kills and hits. More bounty means more damage; at full, your hits make enemies bleed.",
           "gain": {"damage_dealt": 0.25, "kill": 20}, "decay": 2.0, "mods_scaled": {"weapon_damage": {"mult": 0.25}}, "full": {"sts_on_hit": [st("bleed", 3)], "mods": {"fire_rate": {"mult": 0.15}}}},
          {}, s, sig, ult, "A gunslinger with no magic: tough, loud and good with explosives.")

# ------------------------------------------------------------------------------------------------ Time Mage
c = "time_mage"
s = [
    skill(c, "time_slow", "Time Slow", "skill", 13, 30, {"t": "zone", "at": "target", "radius": 7, "dur": 6, "tick": 0.5, "dmg": 0, "sts": [st("slow", 1.0, strength=0.6)]},
          "A bubble where time crawls: enemies inside are heavily slowed.", [0.5, 0.7, 1.0]),
    skill(c, "rewind", "Rewind", "skill", 16, 30, {"t": "teleport", "back": True, "heal": 40, "dist": 0},
          "Rewind yourself to where you stood a few seconds ago and heal.", [0.7, 0.8, 1.0]),
    skill(c, "quicken", "Quicken", "skill", 14, 25, {"t": "buff", "dur": 6, "sts_self": [st("haste", 6)], "mods": {"fire_rate": {"mult": 0.2}, "cast_speed": {"mult": 0.2}}},
          "Speed up your own time: move, shoot and cast faster.", [0.4, 0.9, 1.0]),
    skill(c, "stasis_bolt", "Stasis Bolt", "skill", 11, 25, {"t": "projectile", "speed": 40, "dmg": 20, "radius": 0, "life": 1.6, "sts": [st("stun", 1.4)]},
          "A bolt that freezes the target in time for a moment.", [0.6, 0.8, 1.0]),
    skill(c, "temporal_echo", "Temporal Echo", "skill", 9, 20, {"t": "sprint", "dur": 3.0, "speed": 0.5, "dmg": 25, "sts": [st("slow", 1.5)], "trail": {"radius": 2.5, "dur": 3, "dmg": 4, "sts": [st("slow", 1.5)]}},
          "Sprint through time, leaving an echo behind that slows enemies.", [0.55, 0.65, 1.0]),
    skill(c, "age", "Age", "skill", 10, 25, {"t": "beam", "range": 38, "dmg": 25, "width": 0.4, "sts": [st("vulnerable", 6), st("slow", 2)]},
          "Age the target: they take extra damage and move slowly.", [0.7, 0.6, 0.5]),
]
sig = skill(c, "chrono_burst", "Chrono Burst", "signature", 14, 35, {"t": "aoe", "at": "self", "radius": 9, "dmg": 55, "delay": 0.3, "sts": [st("slow", 3, strength=0.5)], "knock": 5},
            "A burst of time energy that damages and slows everything near you.", [0.55, 0.75, 1.0])
ult = skill(c, "stop_time", "Stop Time", "ultimate", 0, 0, {"t": "aoe", "at": "self", "radius": 22, "dmg": 60, "delay": 0.4, "sts": [st("stun", 3.0), st("vulnerable", 4)], "self_sts": [st("haste", 4)]},
            "Time stops for your enemies. You do not.", [0.5, 0.8, 1.0])
add_class(c, "Time Mage", "clockwork_mines", [0.5, 0.7, 1.0], True, 105, 1.02, 130, "chrono_orb",
          {"id": "time_mage_passive", "name": "Borrowed Time", "desc": "Skills recharge faster.", "mods": {"cooldown_reduction": {"add": 0.1}}},
          {"id": "flux", "name": "Flux", "desc": "Builds as you cast skills. More flux means faster skills; at full, enemies you hit are slowed.",
           "gain": {"skill_cast": 14, "damage_dealt": 0.1}, "decay": 2.5, "mods_scaled": {"cast_speed": {"mult": 0.4}}, "full": {"sts_on_hit": [st("slow", 2)], "mods": {"cooldown_reduction": {"add": 0.15}}}},
          {"slow": 0.6}, s, sig, ult, "A caster who bends time to slow enemies and speed up allies.")

# ------------------------------------------------------------------------------------------------ Celestial Mage
c = "celestial_mage"
s = [
    skill(c, "moon_beam", "Moonbeam", "skill", 6, 22, {"t": "beam", "range": 50, "dmg": 40, "width": 0.4, "sts": [st("marked", 4)]},
          "A beam of moonlight that reveals and marks the target.", [0.75, 0.85, 1.0]),
    skill(c, "starfall", "Starfall", "skill", 11, 30, {"t": "aoe", "at": "target", "radius": 5.5, "dmg": 55, "delay": 0.9, "sts": [st("stun", 0.5)]},
          "A star falls from the sky onto the marked spot.", [0.9, 0.9, 1.0]),
    skill(c, "lunar_shield", "Lunar Shield", "skill", 15, 25, {"t": "buff", "dur": 6, "sts_self": [st("barrier", 6), st("cleanse_shield", 3)]},
          "A shield of moonlight that absorbs damage and blocks debuffs.", [0.8, 0.85, 1.0]),
    skill(c, "gravity_well", "Gravity Well", "skill", 13, 30, {"t": "zone", "at": "target", "radius": 6, "dur": 5, "tick": 0.5, "dmg": 6, "pull": 7, "sts": [st("slow", 1.0)]},
          "A well of gravity that drags enemies into its centre.", [0.5, 0.4, 0.9]),
    skill(c, "phase_blink", "Phase Blink", "skill", 7, 18, {"t": "teleport", "dist": 14, "sts_self": [st("invisible", 1.0)]},
          "Phase forward through space.", [0.85, 0.85, 1.0]),
    skill(c, "blessing", "Blessing", "skill", 14, 30, {"t": "heal", "amount": 35, "radius": 9, "allies": True, "cleanse": True, "regen": 6},
          "A blessing that heals, regenerates and cleanses allies.", [1.0, 0.95, 0.7]),
]
sig = skill(c, "eclipse_pulse", "Eclipse Pulse", "signature", 14, 35, {"t": "aoe", "at": "self", "radius": 9, "dmg": 55, "delay": 0.4, "sts": [st("blind", 2.5), st("slow", 2)]},
            "A pulse of darkness that blinds and slows nearby enemies.", [0.6, 0.6, 1.0])
ult = skill(c, "moonfall", "Moonfall", "ultimate", 0, 0, {"t": "aoe", "at": "target", "radius": 15, "dmg": 230, "delay": 1.5, "sts": [st("stun", 1.5), st("marked", 5)]},
            "A piece of the moon falls onto the battlefield.", [0.85, 0.9, 1.0])
add_class(c, "Celestial Mage", "moon_sanctuary", [0.8, 0.85, 1.0], True, 110, 1.0, 130, "star_orb",
          {"id": "celestial_mage_passive", "name": "Moon Blessing", "desc": "Your shield blocks more and you heal slowly.", "mods": {"shield_strength": {"mult": 0.2}, "health_regen": {"add": 1.0}}},
          {"id": "phase", "name": "Moon Phase", "desc": "Fills over time and as you heal or hit. More phase means more damage and healing; at full, allies near you are empowered.",
           "gain": {"damage_dealt": 0.2, "heal_done": 0.2, "time": 1.2}, "decay": 0.0, "mods_scaled": {"spell_damage": {"mult": 0.2}, "heal_received": {"mult": 0.3}}, "full": {"mods": {"spell_damage": {"mult": 0.15}}, "allies_empower": True}},
          {"blind": 0.5}, s, sig, ult, "A moon priest who heals, marks and calls down starlight.")

# ------------------------------------------------------------------------------------------------ GM Levy
c = "gm_levy"
s = [
    skill(c, "pawn_push", "Pawn Push", "skill", 6, 15, {"t": "projectile", "speed": 34, "dmg": 28, "radius": 2.0, "life": 1.4, "knock": 12, "sts": []},
          "Push a pawn that shoves enemies back.", [0.9, 0.9, 0.9]),
    skill(c, "knight_leap", "Knight Leap", "skill", 10, 20, {"t": "leap", "up": 9, "fwd": 13, "slam": {"radius": 5.5, "dmg": 50, "sts": [st("stun", 0.5)]}},
          "Jump in an L-shaped arc and crush enemies where you land.", [0.8, 0.8, 0.85]),
    skill(c, "bishop_beam", "Bishop's Beam", "skill", 8, 20, {"t": "beam", "range": 48, "dmg": 45, "width": 0.4, "pierce": True, "sts": []},
          "A diagonal beam that pierces everything in a line.", [0.95, 0.95, 1.0]),
    skill(c, "rook_charge", "Rook Charge", "skill", 9, 15, {"t": "sprint", "dur": 2.5, "speed": 0.75, "dmg": 35, "sts": [st("stun", 0.5)]},
          "Charge in a straight line like a rook.", [0.7, 0.7, 0.75]),
    skill(c, "queens_gambit", "Queen's Gambit", "skill", 12, 30, {"t": "cone", "range": 14, "angle": 90, "dmg": 55, "sts": [st("vulnerable", 4)], "knock": 6},
          "A sweeping attack in a wide arc that leaves enemies exposed.", [1.0, 0.8, 0.3]),
    skill(c, "castling", "Castling", "skill", 14, 25, {"t": "teleport", "dist": 18, "sts_self": [st("barrier", 4)]},
          "Swap position across the board and gain a small barrier.", [0.85, 0.85, 0.9]),
]
sig = skill(c, "fork", "Fork", "signature", 13, 30, {"t": "aoe", "at": "target", "radius": 8, "dmg": 65, "delay": 0.6, "sts": [st("root", 1.8), st("marked", 4)]},
            "Attack two places at once: everything in the area is hit and held.", [1.0, 0.85, 0.3])
ult = skill(c, "rook_sacrifice", "Rook Sacrifice", "ultimate", 0, 0, {"t": "aoe", "at": "target", "radius": 16, "dmg": 260, "delay": 1.6, "sts": [st("stun", 1.5)], "knock": 14, "rook": True, "finisher": True},
            "Spawn a huge rook and sacrifice it: it crashes down and shatters. A kill with an ultimate ends in checkmate.", [1.0, 1.0, 1.0])
add_class(c, "GM Levy", "chess_arena", [1.0, 0.85, 0.3], True, 120, 1.0, 120, "chess_staff",
          {"id": "gm_levy_passive", "name": "Grandmaster", "desc": "No map can weaken you. Slightly stronger skills.", "mods": {"skill_damage": {"mult": 0.05}}, "no_map_debuff": True},
          {"id": "tempo", "name": "Tempo", "desc": "Builds as you use different skills and hit. More tempo means faster casting; at full, your next skill is free.",
           "gain": {"skill_cast": 18, "damage_dealt": 0.15}, "decay": 2.5, "mods_scaled": {"cast_speed": {"mult": 0.3}}, "full": {"mods": {"mana_cost": {"mult": -1.0}}}},
          {}, s, sig, ult, "A chess grandmaster who uses board tactics. No map weakens him.")
