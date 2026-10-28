"""Patches and additions on top of data_classes.py (imported by make_data.py).

 - Pharaoh becomes the Desert Assassin, GM Levy becomes GM Ravn (queen sacrifice ultimate).
 - Every class gets 10 distinct skills (the design says 10 per class, one unlocked every 10 levels).
 - The Pirate Captain loses the flintlock (no guns): crossbow instead.
"""
from data_classes import CLASSES, SKILLS, add_class, skill, st

BY_ID = {s["id"]: s for s in SKILLS}


def cls(cid):
    return next(c for c in CLASSES if c["id"] == cid)


def drop_class(cid):
    c = cls(cid)
    for sid in c["skills"] + [c["signature"], c["ultimate"]]:
        SKILLS.remove(BY_ID.pop(sid))
    CLASSES.remove(c)


def extra(cid, sid, name, cd, mana, fx, desc, color):
    """Append one more regular skill to a class."""
    sk = skill(cid, sid, name, "skill", cd, mana, fx, desc, color)
    BY_ID[sk] = SKILLS[-1]
    cls(cid)["skills"].append(sk)


# ---------------------------------------------------------------- Desert Assassin replaces the Pharaoh
drop_class("pharaoh")
c = "desert_assassin"
s = [
    skill(c, "shadow_step", "Shadow Step", "skill", 7, 15, {"t": "teleport", "dist": 10, "behind": True, "sts_self": [st("haste", 2)]},
          "Step through the dust to the back of the nearest enemy and gain speed.", [0.55, 0.45, 0.3]),
    skill(c, "sand_veil", "Sand Veil", "skill", 20, 25, {"t": "buff", "dur": 5, "sts_self": [st("invisible", 5)]},
          "Vanish in a veil of sand until you strike.", [0.9, 0.75, 0.45]),
    skill(c, "venom_blade", "Venom Blade", "skill", 14, 20, {"t": "buff", "dur": 8, "mods": {"weapon_damage": {"mult": 0.15}}, "on_hit": [st("poison", 4)]},
          "Coat your blades: every hit poisons and hurts more.", [0.5, 0.8, 0.2]),
    skill(c, "smoke_bomb", "Smoke Bomb", "skill", 13, 20, {"t": "aoe", "at": "self", "radius": 6, "dmg": 5, "delay": 0.1, "sts": [st("blind", 3), st("slow", 1.5)]},
          "A cloud of smoke that blinds and slows nearby enemies.", [0.6, 0.6, 0.6]),
    skill(c, "dagger_fan", "Dagger Fan", "skill", 6, 18, {"t": "projectile", "speed": 50, "dmg": 16, "radius": 0, "life": 0.9, "count": 5, "spread": 24, "sts": [st("bleed", 3)]},
          "Throw a fan of daggers that make enemies bleed.", [0.85, 0.85, 0.9]),
    skill(c, "mirage", "Mirage", "skill", 16, 25, {"t": "summon", "what": "decoy", "count": 2, "dur": 6},
          "Two mirages of you run in different directions while you slip away.", [0.95, 0.85, 0.55]),
    skill(c, "sand_dash", "Sand Sprint", "skill", 8, 15, {"t": "sprint", "dur": 3.0, "speed": 0.5, "dmg": 22, "sts": [st("bleed", 3)]},
          "Sprint through enemies and cut them as you pass.", [0.9, 0.7, 0.35]),
    skill(c, "quick_slash", "Quick Slash", "skill", 6, 12, {"t": "cone", "range": 5, "angle": 100, "dmg": 48, "sts": [st("bleed", 4)]},
          "A fast sweeping cut in front of you.", [0.9, 0.9, 0.95]),
    skill(c, "sirocco_gust", "Sirocco Gust", "skill", 12, 25, {"t": "aoe", "at": "self", "radius": 8, "dmg": 25, "delay": 0.2, "knock": 10, "sts": [st("slow", 2), st("blind", 1)]},
          "A hot gust that shoves enemies away and fills their eyes with sand.", [0.95, 0.8, 0.4]),
    skill(c, "mark_for_death", "Mark for Death", "skill", 15, 20, {"t": "beam", "range": 40, "dmg": 10, "width": 0.4, "sts": [st("marked", 6), st("vulnerable", 4)]},
          "Mark a target: everyone sees it and it takes extra damage.", [0.9, 0.2, 0.25]),
]
sig = skill(c, "dust_devil_flurry", "Dust Devil Flurry", "signature", 14, 35,
            {"t": "aoe", "at": "self", "radius": 7, "dmg": 62, "delay": 0.2, "sts": [st("bleed", 4, 2), st("blind", 1.5)]},
            "You spin into a dust devil of blades that cuts everything around you.", [0.95, 0.75, 0.35])
ult = skill(c, "vanishing_slaughter", "Vanishing Slaughter", "ultimate", 0, 0,
            {"t": "aoe", "at": "self", "radius": 10, "dmg": 210, "delay": 0.9, "sts": [st("stun", 0.6), st("bleed", 5, 3)], "sts_self": [st("invisible", 4)]},
            "You vanish, then every enemy nearby is cut to ribbons at once.", [1.0, 0.8, 0.3])
add_class(c, "Desert Assassin", "desert_tomb", [0.9, 0.7, 0.3], False, 100, 1.0, 100, "twin_daggers",
          {"id": "desert_assassin_passive", "name": "Desert Wind", "desc": "Faster, harder to see and likelier to crit.", "mods": {"move_speed": {"mult": 0.06}, "crit_chance": {"add": 0.06}}},
          {"id": "mirage", "name": "Mirage", "desc": "Builds as you hit from behind and dodge. More mirage means a bigger crit; at full, you flicker and the next hit crits.",
           "gain": {"damage_dealt": 0.2, "kill": 20}, "decay": 3.0, "mods_scaled": {"crit_chance": {"add": 0.25}}, "full": {"sts_self": [st("invisible", 2)], "mods": {"crit_chance": {"add": 0.3}}}},
          {"blind": 0.6, "slow": 0.2}, s, sig, ult, "A fast, sneaky blade fighter of the dunes: sand, vanishing and poison.")

# ---------------------------------------------------------------- GM Levy becomes GM Ravn
lv = cls("gm_levy")
lv["id"], lv["name"] = "gm_ravn", "GM Ravn"
lv["weapon"] = "chess_staff"
lv["passive"]["id"], lv["passive"]["name"] = "gm_ravn_passive", "Grandmaster"
for old, new in (("gm_levy_pawn_push", "gm_ravn_pawn_push"), ("gm_levy_knight_leap", "gm_ravn_knight_leap"), ("gm_levy_bishop_beam", "gm_ravn_bishop_beam"),
                 ("gm_levy_rook_charge", "gm_ravn_rook_charge"), ("gm_levy_queens_gambit", "gm_ravn_queens_gambit"), ("gm_levy_castling", "gm_ravn_castling"),
                 ("gm_levy_fork", "gm_ravn_fork"), ("gm_levy_rook_sacrifice", "gm_ravn_queen_sacrifice")):
    BY_ID[old]["id"] = new
    BY_ID[new] = BY_ID.pop(old)
    BY_ID[new]["class"] = "gm_ravn"
lv["skills"] = [i.replace("gm_levy", "gm_ravn") for i in lv["skills"]]
lv["signature"] = "gm_ravn_fork"
lv["ultimate"] = "gm_ravn_queen_sacrifice"
q = BY_ID["gm_ravn_queen_sacrifice"]
q["name"] = "Queen Sacrifice"
q["desc"] = "Spawn a huge queen and sacrifice it: she sweeps across the board and shatters. A kill with an ultimate ends in checkmate."
q["fx"].pop("rook", None)
q["fx"]["queen"] = True
lv["blurb"] = "An invented young chess grandmaster who plays the board. No map weakens him."

# ---------------------------------------------------------------- the Pirate Captain loses the gun
pc = cls("pirate_captain")
pc["weapon"] = "hand_crossbow"
for sid in pc["skills"]:
    sk = BY_ID[sid]
    if "flintlock" in sk["id"]:
        sk["name"] = "Crossbow Volley"
        sk["desc"] = sk["desc"].replace("flintlock", "crossbow").replace("Flintlock", "Crossbow").replace("pistols", "bolts").replace("shots", "bolts")

# ---------------------------------------------------------------- skills 7-10 for every class
extra("druid", "thorn_volley", "Thorn Volley", 7, 20, {"t": "projectile", "speed": 45, "dmg": 14, "radius": 0, "life": 1.0, "count": 5, "spread": 10, "sts": [st("bleed", 3)]},
      "A spray of thorns that make enemies bleed.", [0.35, 0.7, 0.25])
extra("druid", "leaf_storm", "Leaf Storm", 13, 30, {"t": "aoe", "at": "self", "radius": 6, "dmg": 36, "delay": 0.2, "sts": [st("slow", 2), st("bleed", 3)]},
      "A whirl of razor leaves around you.", [0.4, 0.85, 0.3])
extra("druid", "wild_growth", "Wild Growth", 18, 25, {"t": "buff", "dur": 6, "sts_self": [st("haste", 6), st("regen", 6)]},
      "Plants lift you: faster and healing.", [0.5, 0.9, 0.4])
extra("druid", "stinging_swarm", "Stinging Swarm", 10, 22, {"t": "projectile", "speed": 24, "dmg": 18, "radius": 2.0, "life": 2.5, "homing": 4, "sts": [st("poison", 4, 2)]},
      "Wasps chase the target and poison it.", [0.9, 0.8, 0.2])

extra("sea_king", "trident_throw", "Trident Throw", 7, 20, {"t": "projectile", "speed": 60, "dmg": 52, "radius": 0, "life": 1.2, "pierce": True, "sts": []},
      "Hurl your trident through everything in a line.", [0.3, 0.75, 1.0])
extra("sea_king", "ink_cloud", "Ink Cloud", 14, 25, {"t": "zone", "at": "target", "radius": 6, "dur": 6, "tick": 1.0, "dmg": 3, "sts": [st("blind", 1.5), st("slow", 1.0)]},
      "A cloud of dark ink that blinds and slows.", [0.15, 0.15, 0.3])
extra("sea_king", "undertow", "Undertow", 11, 25, {"t": "beam", "range": 30, "dmg": 14, "width": 0.5, "pull": 14, "sts": [st("slow", 2)]},
      "A current that drags one enemy to you.", [0.2, 0.65, 0.9])
extra("sea_king", "pearl_barrier", "Pearl Barrier", 17, 25, {"t": "buff", "dur": 5, "sts_self": [st("barrier", 5), st("regen", 5)]},
      "A pearl shell absorbs damage and heals you.", [0.9, 0.95, 1.0])

extra("flame_lord", "flame_wall", "Flame Wall", 14, 30, {"t": "wall", "len": 10, "height": 3.0, "dur": 6, "dmg": 8, "tick": 0.5, "sts": [st("burn", 3)]},
      "A wall of fire that burns whoever crosses it.", [1.0, 0.5, 0.1])
extra("flame_lord", "ember_barrage", "Ember Barrage", 8, 25, {"t": "projectile", "speed": 40, "dmg": 14, "radius": 1.2, "life": 1.4, "count": 6, "spread": 14, "sts": [st("burn", 2)]},
      "A burst of embers in a wide spread.", [1.0, 0.6, 0.15])
extra("flame_lord", "phoenix_rise", "Phoenix Rise", 20, 35, {"t": "heal", "amount": 40, "radius": 0, "allies": False, "regen": 6, "sts_self": [st("barrier", 4)]},
      "Rise from the ashes: heal, regenerate and gain a barrier.", [1.0, 0.7, 0.2])
extra("flame_lord", "lava_whip", "Lava Whip", 9, 20, {"t": "beam", "range": 16, "dmg": 40, "width": 1.0, "pull": 5, "sts": [st("burn", 3)]},
      "A whip of lava that burns and pulls.", [1.0, 0.35, 0.05])

extra("frost_mage", "ice_lance", "Ice Lance", 6, 18, {"t": "projectile", "speed": 80, "dmg": 55, "radius": 0, "life": 1.2, "pierce": True, "sts": [st("chill", 4, 2)]},
      "A fast lance of ice that pierces.", [0.7, 0.95, 1.0])
extra("frost_mage", "frozen_ground", "Frozen Ground", 14, 25, {"t": "zone", "at": "self", "radius": 8, "dur": 7, "tick": 0.8, "dmg": 4, "sts": [st("chill", 2), st("slow", 2)]},
      "The ground around you freezes and slows enemies.", [0.6, 0.85, 1.0])
extra("frost_mage", "icicle_rain", "Icicle Rain", 13, 35, {"t": "strikes", "at": "target", "radius": 8, "count": 7, "dmg": 26, "delay": 0.6, "sts": [st("chill", 3)]},
      "Icicles fall from the sky over an area.", [0.8, 0.95, 1.0])
extra("frost_mage", "permafrost", "Permafrost", 16, 25, {"t": "buff", "dur": 6, "mods": {"armor": {"add": 0.2}, "slow_resist": {"add": 0.4}}},
      "Skin like ice: much tougher and hard to slow.", [0.7, 0.9, 1.0])

extra("thunder_god", "storm_call", "Storm Call", 12, 35, {"t": "strikes", "at": "target", "radius": 9, "count": 5, "dmg": 32, "delay": 0.7, "sts": [st("shock", 3)]},
      "Call down lightning on an area.", [1.0, 0.95, 0.4])
extra("thunder_god", "overcharge", "Overcharge", 18, 25, {"t": "buff", "dur": 6, "mods": {"fire_rate": {"mult": 0.2}, "move_speed": {"mult": 0.1}}, "sts_self": [st("haste", 6)]},
      "Crackle with power: faster hands and feet.", [1.0, 0.95, 0.3])
extra("thunder_god", "thunder_javelin", "Thunder Javelin", 7, 22, {"t": "projectile", "speed": 70, "dmg": 58, "radius": 0, "life": 1.3, "pierce": True, "sts": [st("shock", 3)]},
      "A javelin of lightning that pierces.", [1.0, 0.95, 0.5])
extra("thunder_god", "lightning_step", "Lightning Step", 9, 18, {"t": "teleport", "dist": 12, "sts_self": [st("haste", 2)], "leave_zone": {"radius": 2.0, "dur": 2, "dmg": 5, "sts": [st("shock", 2)]}},
      "Vanish in a flash and leave a shocking spot behind.", [1.0, 1.0, 0.6])

extra("necromancer", "bone_armor", "Bone Armor", 16, 25, {"t": "buff", "dur": 7, "sts_self": [st("barrier", 7)], "mods": {"armor": {"add": 0.15}}},
      "A shell of bones absorbs damage.", [0.85, 0.85, 0.75])
extra("necromancer", "curse_of_decay", "Curse of Decay", 13, 30, {"t": "zone", "at": "target", "radius": 6, "dur": 7, "tick": 1.0, "dmg": 6, "sts": [st("weaken", 3), st("vulnerable", 3)]},
      "An area of rot that weakens everyone in it.", [0.45, 0.6, 0.3])
extra("necromancer", "soul_drain", "Soul Drain", 9, 22, {"t": "beam", "range": 22, "dmg": 30, "width": 0.5, "lifesteal": 0.8, "sts": []},
      "Drain life from an enemy and heal.", [0.6, 0.9, 0.6])
extra("necromancer", "bone_prison", "Bone Prison", 12, 25, {"t": "zone", "at": "target", "radius": 4, "dur": 3, "tick": 0.5, "dmg": 4, "sts": [st("root", 1.2)]},
      "Bones close around enemies and hold them.", [0.9, 0.9, 0.8])

extra("arcanist", "mana_surge", "Mana Surge", 20, 0, {"t": "buff", "dur": 4, "mana": 40, "mods": {"cooldown_reduction": {"add": 0.3}}},
      "Surge of mana: refill some and cast faster for a short time.", [0.55, 0.45, 1.0])
extra("arcanist", "prism_beam", "Prism Beam", 8, 25, {"t": "beam", "range": 40, "dmg": 38, "width": 0.5, "pierce": True, "sts": []},
      "A beam of light that pierces everything.", [0.8, 0.6, 1.0])
extra("arcanist", "gravity_rune", "Gravity Rune", 15, 30, {"t": "trap", "dur": 20, "radius": 5, "dmg": 20, "sts": [st("slow", 3), st("root", 1)]},
      "A hidden rune that slows and holds whoever steps on it.", [0.6, 0.4, 0.95])
extra("arcanist", "arcane_barrage", "Arcane Barrage", 9, 25, {"t": "projectile", "speed": 50, "dmg": 12, "radius": 0, "life": 1.2, "count": 7, "spread": 10, "sts": []},
      "A flurry of bolts.", [0.7, 0.5, 1.0])

extra("poison_brewer", "plague_vial", "Plague Vial", 8, 20, {"t": "projectile", "speed": 30, "dmg": 20, "radius": 3.0, "life": 1.6, "sts": [st("poison", 5, 2)]},
      "A vial that shatters into a poison splash.", [0.5, 0.9, 0.2])
extra("poison_brewer", "bubbling_cauldron", "Bubbling Cauldron", 15, 30, {"t": "zone", "at": "target", "radius": 5, "dur": 8, "tick": 1.0, "dmg": 6, "sts": [st("poison", 3)]},
      "A cauldron that bubbles poison onto the ground.", [0.4, 0.8, 0.25])
extra("poison_brewer", "panacea", "Panacea", 16, 25, {"t": "heal", "amount": 30, "radius": 8, "allies": True, "cleanse": True},
      "A cure-all that heals allies and cleanses debuffs.", [0.6, 1.0, 0.7])
extra("poison_brewer", "caustic_mist", "Caustic Mist", 10, 22, {"t": "cone", "range": 10, "angle": 80, "dmg": 20, "sts": [st("poison", 4), st("blind", 1)]},
      "A spray of caustic mist.", [0.6, 0.85, 0.3])

extra("pirate_captain", "powder_keg", "Powder Keg", 15, 25, {"t": "trap", "dur": 20, "radius": 5, "dmg": 70, "knock": 10, "sts": [st("stun", 0.5)]},
      "A hidden keg that explodes when an enemy steps close.", [0.55, 0.35, 0.2])
extra("pirate_captain", "boarding_axe", "Boarding Axe", 8, 15, {"t": "projectile", "speed": 40, "dmg": 45, "radius": 0, "life": 1.0, "sts": [st("bleed", 3), st("slow", 1)]},
      "Throw an axe that bites deep and slows.", [0.8, 0.8, 0.85])
extra("pirate_captain", "parrot_scout", "Parrot Scout", 18, 20, {"t": "buff", "dur": 6, "reveal": 30, "sts_self": []},
      "Your parrot circles overhead and shows nearby enemies.", [0.9, 0.2, 0.2])
extra("pirate_captain", "anchor_slam", "Anchor Slam", 12, 25, {"t": "leap", "up": 7, "fwd": 9, "slam": {"radius": 6, "dmg": 55, "sts": [st("stun", 0.6)]}},
      "Leap and slam an anchor into the ground.", [0.5, 0.55, 0.6])

extra("time_mage", "hourglass", "Hourglass", 14, 30, {"t": "zone", "at": "target", "radius": 6, "dur": 6, "tick": 1.0, "dmg": 4, "sts": [st("slow", 3), st("vulnerable", 2)]},
      "A bubble where time crawls.", [0.95, 0.8, 0.4])
extra("time_mage", "time_skip", "Time Skip", 10, 20, {"t": "teleport", "dist": 16, "sts_self": [st("barrier", 2)]},
      "Skip forward a few moments and gain a small barrier.", [0.9, 0.75, 0.4])
extra("time_mage", "overclock", "Overclock", 18, 25, {"t": "buff", "dur": 6, "mods": {"fire_rate": {"mult": 0.25}, "cast_speed": {"mult": 0.25}}, "sts_self": [st("haste", 6)]},
      "Everything about you runs faster.", [1.0, 0.8, 0.3])
extra("time_mage", "paradox_bolt", "Paradox Bolt", 9, 25, {"t": "projectile", "speed": 45, "dmg": 35, "radius": 0, "life": 1.5, "sts": [st("stun", 0.8), st("weaken", 3)]},
      "A bolt that is hit before it is thrown.", [0.8, 0.65, 0.95])

extra("celestial_mage", "crescent_slash", "Crescent Slash", 8, 20, {"t": "cone", "range": 10, "angle": 120, "dmg": 42, "sts": [st("silence", 2)]},
      "A wide slash of moonlight that silences magic users.", [0.8, 0.85, 1.0])
extra("celestial_mage", "star_shower", "Star Shower", 14, 35, {"t": "strikes", "at": "target", "radius": 10, "count": 8, "dmg": 22, "delay": 0.7, "sts": []},
      "Stars fall over a wide area.", [1.0, 0.95, 0.6])
extra("celestial_mage", "moon_mend", "Moon Mend", 15, 30, {"t": "heal", "amount": 35, "radius": 8, "allies": True, "regen": 5},
      "Moonlight heals nearby allies.", [0.85, 0.9, 1.0])
extra("celestial_mage", "night_veil", "Night Veil", 17, 25, {"t": "buff", "dur": 5, "sts_self": [st("barrier", 5), st("haste", 5)]},
      "A veil of night protects and quickens you.", [0.3, 0.35, 0.8])

extra("gm_ravn", "en_passant", "En Passant", 7, 15, {"t": "sprint", "dur": 2.5, "speed": 0.6, "dmg": 30, "sts": [st("vulnerable", 3)]},
      "Capture in passing: sprint through an enemy and leave it exposed.", [0.9, 0.9, 0.95])
extra("gm_ravn", "zugzwang", "Zugzwang", 15, 30, {"t": "zone", "at": "target", "radius": 7, "dur": 3, "tick": 0.5, "dmg": 4, "sts": [st("slow", 3), st("weaken", 3)]},
      "Every move makes it worse: enemies in the area are slowed and weakened.", [0.8, 0.8, 0.9])
extra("gm_ravn", "promotion", "Promotion", 18, 25, {"t": "buff", "dur": 8, "mods": {"skill_damage": {"mult": 0.25}}, "sts_self": [st("haste", 8)]},
      "A pawn becomes a queen: stronger skills and more speed.", [1.0, 0.85, 0.3])
extra("gm_ravn", "stalemate", "Stalemate", 12, 25, {"t": "aoe", "at": "target", "radius": 6, "dmg": 20, "delay": 0.4, "sts": [st("root", 2.5)]},
      "Enemies in the area cannot move.", [0.85, 0.85, 0.9])

for c_ in CLASSES:
    assert len(c_["skills"]) == 10, (c_["id"], len(c_["skills"]))
