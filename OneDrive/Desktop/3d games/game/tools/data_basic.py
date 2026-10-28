"""Basic game data: rarities, status effects, maps. Imported by make_data.py."""

RARITIES = ["common", "uncommon", "rare", "epic", "legendary", "mythic"]

RARITY_INFO = {
    # shape is the frame/icon shape so rarity never relies on colour alone
    "common":    {"name": "Common",    "color": [0.62, 0.64, 0.68], "shape": "square",   "weight": 45, "glow": 0.0, "factor": 1.0},
    "uncommon":  {"name": "Uncommon",  "color": [0.30, 0.78, 0.38], "shape": "leaf",     "weight": 25, "glow": 0.1, "factor": 1.35},
    "rare":      {"name": "Rare",      "color": [0.28, 0.55, 0.95], "shape": "diamond",  "weight": 15, "glow": 0.25, "factor": 1.8},
    "epic":      {"name": "Epic",      "color": [0.66, 0.36, 0.92], "shape": "hexagon",  "weight": 9,  "glow": 0.45, "factor": 2.4},
    "legendary": {"name": "Legendary", "color": [1.00, 0.76, 0.20], "shape": "star",     "weight": 5,  "glow": 0.7,  "factor": 3.2},
    "mythic":    {"name": "Mythic",    "color": [0.95, 0.15, 0.22], "shape": "crown",    "weight": 1,  "glow": 1.0,  "factor": 4.2},
}

# Status effects. kinds: dot (damage over time), speed (move speed multiplier), flags (stun, root, silence, blind...)
STATUSES = [
    {"id": "burn", "name": "Burn", "harmful": True, "max_stacks": 3, "duration": 4.0, "dps": 5.0, "color": [1.0, 0.45, 0.1], "symbol": "flame",
     "desc": "Fire damage every second."},
    {"id": "chill", "name": "Chill", "harmful": True, "max_stacks": 5, "duration": 4.0, "speed_per_stack": -0.10, "color": [0.55, 0.85, 1.0], "symbol": "snow",
     "desc": "Slows you. At 5 stacks you freeze.", "freeze_at": 5},
    {"id": "freeze", "name": "Freeze", "harmful": True, "max_stacks": 1, "duration": 1.6, "flags": ["root", "no_skills"], "damage_taken": 0.15, "color": [0.7, 0.95, 1.0],
     "symbol": "snow", "desc": "Frozen in place and takes more damage."},
    {"id": "poison", "name": "Poison", "harmful": True, "max_stacks": 5, "duration": 5.0, "dps": 3.0, "heal_taken": -0.3, "color": [0.45, 0.85, 0.2], "symbol": "drop",
     "desc": "Damage over time and less healing."},
    {"id": "shock", "name": "Shock", "harmful": True, "max_stacks": 3, "duration": 4.0, "burst": 4.0, "color": [1.0, 0.95, 0.3], "symbol": "bolt",
     "desc": "Small damage. At 3 stacks you are stunned.", "stun_at": 3},
    {"id": "stun", "name": "Stun", "harmful": True, "max_stacks": 1, "duration": 1.0, "flags": ["root", "no_skills", "no_fire"], "color": [1.0, 0.85, 0.2], "symbol": "stars",
     "desc": "You cannot move or act."},
    {"id": "slow", "name": "Slow", "harmful": True, "max_stacks": 1, "duration": 3.0, "speed_per_stack": -0.35, "color": [0.7, 0.6, 0.4], "symbol": "arrow_down",
     "desc": "You move slower."},
    {"id": "root", "name": "Root", "harmful": True, "max_stacks": 1, "duration": 2.0, "flags": ["root"], "color": [0.3, 0.7, 0.3], "symbol": "roots",
     "desc": "You cannot move but can still shoot and cast."},
    {"id": "bleed", "name": "Bleed", "harmful": True, "max_stacks": 3, "duration": 5.0, "dps": 3.0, "dps_moving_mult": 2.0, "color": [0.8, 0.1, 0.15], "symbol": "drop",
     "desc": "Damage over time, doubled while moving."},
    {"id": "weaken", "name": "Weaken", "harmful": True, "max_stacks": 1, "duration": 5.0, "damage_dealt": -0.25, "color": [0.6, 0.5, 0.7], "symbol": "arrow_down",
     "desc": "You deal less damage."},
    {"id": "vulnerable", "name": "Vulnerable", "harmful": True, "max_stacks": 1, "duration": 5.0, "damage_taken": 0.20, "color": [0.95, 0.4, 0.55], "symbol": "cross",
     "desc": "You take extra damage."},
    {"id": "silence", "name": "Silence", "harmful": True, "max_stacks": 1, "duration": 3.0, "flags": ["no_skills"], "magic_only": True, "color": [0.6, 0.6, 0.9], "symbol": "mute",
     "desc": "You cannot use skills. Non-magic gear is immune."},
    {"id": "blind", "name": "Blind", "harmful": True, "max_stacks": 1, "duration": 2.5, "flags": ["blind"], "color": [0.85, 0.8, 0.5], "symbol": "eye",
     "desc": "Your view is covered and your aim shakes."},
    {"id": "haste", "name": "Haste", "harmful": False, "max_stacks": 1, "duration": 5.0, "speed_per_stack": 0.30, "color": [0.4, 0.95, 0.7], "symbol": "arrow_up",
     "desc": "You move faster."},
    {"id": "barrier", "name": "Barrier", "harmful": False, "max_stacks": 1, "duration": 6.0, "absorb": 60.0, "color": [0.4, 0.8, 1.0], "symbol": "shield",
     "desc": "Absorbs damage."},
    {"id": "regen", "name": "Regen", "harmful": False, "max_stacks": 1, "duration": 6.0, "hps": 6.0, "color": [0.4, 0.95, 0.4], "symbol": "plus",
     "desc": "You heal over time."},
    {"id": "empower", "name": "Empower", "harmful": False, "max_stacks": 1, "duration": 6.0, "damage_dealt": 0.25, "color": [1.0, 0.6, 0.2], "symbol": "arrow_up",
     "desc": "You deal more damage."},
    {"id": "cleanse_shield", "name": "Cleansed", "harmful": False, "max_stacks": 1, "duration": 3.0, "flags": ["immune_debuffs"], "color": [0.95, 0.95, 1.0], "symbol": "sparkle",
     "desc": "You cannot be hit by debuffs."},
    {"id": "invisible", "name": "Invisible", "harmful": False, "max_stacks": 1, "duration": 3.0, "flags": ["invisible"], "color": [0.8, 0.8, 0.9], "symbol": "eye",
     "desc": "Enemies cannot see you."},
    {"id": "marked", "name": "Marked", "harmful": True, "max_stacks": 1, "duration": 4.0, "damage_taken": 0.10, "flags": ["revealed"], "color": [1.0, 0.3, 0.3], "symbol": "eye",
     "desc": "You are revealed and take extra damage."},
]

# Map data: environment settings, buff/debuff numbers, kill plane, ambience
BUFF = {"damage": 0.15, "speed": 0.08, "health": 0.12}
DEBUFF = {"damage": -0.15, "speed": -0.08, "health": -0.12}

MAPS = [
    {"id": "flora_forest", "title": "Flora Forest", "home": "druid", "debuffed": "pharaoh", "sun": {"pitch": 55, "yaw": 30, "color": [1.0, 0.96, 0.85], "energy": 1.3},
     "sky": [0.55, 0.75, 0.92], "ambient": 0.55, "fog": {"color": [0.6, 0.78, 0.7], "density": 0.004}, "mechanic": "Spore Bounce", "hazard": "Thorn Vines"},
    {"id": "underwater_ocean", "title": "Underwater Ocean", "home": "sea_king", "debuffed": "flame_lord", "sun": {"pitch": 70, "yaw": 20, "color": [0.7, 0.9, 1.0], "energy": 1.0},
     "sky": [0.1, 0.35, 0.55], "ambient": 0.7, "fog": {"color": [0.1, 0.4, 0.6], "density": 0.02}, "mechanic": "Tidal Currents", "hazard": "Jellyfish Swarms"},
    {"id": "volcano_forge", "title": "Volcano Forge", "home": "flame_lord", "debuffed": "frost_mage", "sun": {"pitch": 45, "yaw": -40, "color": [1.0, 0.7, 0.45], "energy": 1.1},
     "sky": [0.35, 0.18, 0.12], "ambient": 0.5, "fog": {"color": [0.4, 0.2, 0.12], "density": 0.01}, "mechanic": "Cooling Bridges", "hazard": "Lava"},
    {"id": "frozen_peaks", "title": "Frozen Peaks", "home": "frost_mage", "debuffed": "sea_king", "sun": {"pitch": 48, "yaw": -35, "color": [0.92, 0.96, 1.0], "energy": 1.4},
     "sky": [0.62, 0.76, 0.92], "ambient": 0.65, "fog": {"color": [0.8, 0.88, 0.96], "density": 0.006}, "mechanic": "Ice Slides", "hazard": "Avalanche"},
    {"id": "sky_islands", "title": "Sky Islands", "home": "thunder_god", "debuffed": "pirate_captain", "sun": {"pitch": 52, "yaw": -30, "color": [1.0, 0.96, 0.88], "energy": 1.3},
     "sky": [0.34, 0.58, 0.95], "ambient": 0.6, "fog": {"color": [0.7, 0.82, 1.0], "density": 0.002}, "mechanic": "Updrafts", "hazard": "Lightning Strikes"},
    {"id": "desert_tomb", "title": "Desert Tomb", "home": "pharaoh", "debuffed": "druid", "sun": {"pitch": 58, "yaw": 20, "color": [1.0, 0.93, 0.78], "energy": 1.5},
     "sky": [0.6, 0.72, 0.9], "ambient": 0.55, "fog": {"color": [0.9, 0.78, 0.55], "density": 0.003}, "mechanic": "Pressure Plates", "hazard": "Quicksand"},
]
