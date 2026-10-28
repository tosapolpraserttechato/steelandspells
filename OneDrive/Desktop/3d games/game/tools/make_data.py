"""Writes every game data file into game/data/*.json.

  python make_data.py        (Blender's Python works: "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" -I make_data.py)

Sources: data_basic.py (rarities, statuses), data_classes.py + data_extra.py (classes and skills), data_gear.py (weapons, armor, runes,
modifiers, potions, items), ../../design/cards.json and quest_skills.json, ../../maps/*/markers.json (map info).
"""
import json
import sys
from pathlib import Path

here = Path(__file__).resolve().parent
sys.path.insert(0, str(here))
import data_basic as basic  # noqa: E402
import data_classes as classes_mod  # noqa: E402
import data_extra  # noqa: E402,F401  (patches the class data in place)
import data_gear as gear  # noqa: E402

out = here.parent / "data"
out.mkdir(exist_ok=True)
design = here.parent.parent / "design"


def dump(name, obj):
    (out / f"{name}.json").write_text(json.dumps(obj, indent=1), encoding="utf-8")
    print("wrote", name, len(obj) if hasattr(obj, "__len__") else "")


# per-class movement and sight numbers from the design doc: speed (m/s), acceleration, body size, sight distance (m), crit chance
CLASS_STATS = {
    "druid": (5.8, 9, 1.00, 70, 0.06), "sea_king": (5.6, 8, 1.10, 65, 0.05), "flame_lord": (5.8, 9, 1.00, 70, 0.08), "frost_mage": (5.6, 8, 0.95, 75, 0.07),
    "thunder_god": (6.4, 12, 1.00, 70, 0.08), "desert_assassin": (6.8, 15, 0.90, 80, 0.14), "necromancer": (5.4, 8, 1.00, 70, 0.06),
    "arcanist": (5.6, 9, 0.95, 75, 0.07), "poison_brewer": (5.6, 9, 0.95, 65, 0.06), "pirate_captain": (5.8, 10, 1.10, 70, 0.09),
    "time_mage": (6.0, 11, 0.95, 75, 0.07), "celestial_mage": (5.8, 9, 0.95, 85, 0.06), "gm_ravn": (6.0, 10, 1.00, 80, 0.08),
}
for c_ in classes_mod.CLASSES:
    sp, ac, sz, sg, cr = CLASS_STATS[c_["id"]]
    c_["stats"] = {"speed": sp, "accel": ac, "size": sz, "sight": sg, "crit": cr}
    c_["model"] = "res://models/classes/class_%s.glb" % c_["id"]

rarities = [dict(basic.RARITY_INFO[r], id=r) for r in basic.RARITIES]
dump("rarities", rarities)
dump("statuses", basic.STATUSES)
dump("classes", classes_mod.CLASSES)
dump("skills", classes_mod.SKILLS)
import data_cards  # noqa: E402
cards = json.loads((design / "cards.json").read_text(encoding="utf-8"))
for c_ in cards["cards"]:
    stat, kind, scale = data_cards.CARD_EFFECTS[c_["id"]]
    c_["stat"], c_["kind"] = stat, kind
    c_["per_stack"] = [round(float(v) * scale, 5) for v in c_["values_by_stack"]]
missing = [c_["id"] for c_ in cards["cards"] if c_["id"] not in data_cards.CARD_EFFECTS]
assert not missing, missing
dump("cards", cards)
quest = json.loads((design / "quest_skills.json").read_text(encoding="utf-8"))
dump("quest_skills", [quest[k] for k in sorted(quest, key=int)] if isinstance(quest, dict) else quest)
dump("weapons", gear.WEAPONS)
dump("armor_sets", gear.ARMOR_SETS)
dump("runes", gear.RUNES)
dump("modifiers", {"modifiers": gear.MODIFIERS, "auras": gear.AURAS, "skins": gear.SKIN_THEMES})
dump("potions", gear.POTIONS)
dump("items", gear.ITEMS)

# lighting and mood per map (taken from each map script's kit.lighting call): sun pitch/yaw in degrees, sun colour, sun energy (Godot scale), sky colour, ambient energy
ENV = {
    "flora_forest": dict(pitch=58, yaw=25, color=[1.0, 0.95, 0.78], energy=1.3, sky=[0.50, 0.68, 0.85], ambient=0.9),
    "underwater_ocean": dict(pitch=75, yaw=20, color=[0.6, 0.88, 1.0], energy=1.2, sky=[0.05, 0.28, 0.42], ambient=1.3, fog=[0.06, 0.32, 0.46, 0.012]),
    "volcano_forge": dict(pitch=60, yaw=-130, color=[1.0, 0.7, 0.45], energy=1.3, sky=[0.55, 0.28, 0.2], ambient=1.0, fog=[0.35, 0.18, 0.12, 0.004]),
    "frozen_peaks": dict(pitch=48, yaw=-35, color=[0.9, 0.95, 1.0], energy=1.4, sky=[0.62, 0.76, 0.92], ambient=1.1, fog=[0.82, 0.9, 0.97, 0.003]),
    "sky_islands": dict(pitch=52, yaw=-30, color=[1.0, 0.96, 0.88], energy=1.3, sky=[0.34, 0.58, 0.95], ambient=1.0, fog=[0.7, 0.82, 1.0, 0.0015]),
    "desert_tomb": dict(pitch=58, yaw=20, color=[1.0, 0.93, 0.78], energy=1.5, sky=[0.60, 0.72, 0.90], ambient=0.9, fog=[0.9, 0.78, 0.55, 0.0015]),
    "shadow_crypt": dict(pitch=38, yaw=-35, color=[0.62, 0.66, 1.0], energy=0.7, sky=[0.16, 0.14, 0.30], ambient=0.6, fog=[0.30, 0.30, 0.42, 0.035]),
    "crystal_caves": dict(pitch=60, yaw=20, color=[0.55, 0.65, 1.0], energy=0.35, sky=[0.07, 0.08, 0.20], ambient=0.35, fog=[0.05, 0.06, 0.15, 0.006]),
    "toxic_swamp": dict(pitch=48, yaw=30, color=[1.0, 0.92, 0.65], energy=1.0, sky=[0.46, 0.60, 0.42], ambient=0.8, fog=[0.45, 0.6, 0.35, 0.008]),
    "pirate_cove": dict(pitch=48, yaw=25, color=[1.0, 0.92, 0.80], energy=1.4, sky=[0.52, 0.70, 0.92], ambient=1.0),
    "clockwork_mines": dict(pitch=55, yaw=25, color=[1.0, 0.86, 0.66], energy=1.0, sky=[0.24, 0.18, 0.14], ambient=0.8, fog=[0.2, 0.15, 0.12, 0.006]),
    "moon_sanctuary": dict(pitch=40, yaw=-20, color=[0.62, 0.72, 1.0], energy=0.6, sky=[0.06, 0.07, 0.20], ambient=0.7, fog=[0.06, 0.07, 0.2, 0.002]),
    "chess_arena": dict(pitch=52, yaw=30, color=[1.0, 0.93, 0.80], energy=1.4, sky=[0.55, 0.60, 0.78], ambient=1.0),
}
maps = []
for p in sorted((here.parent.parent / "maps").glob("*/markers.json")):
    info = json.loads(p.read_text(encoding="utf-8"))
    maps.append({"id": info["map"], "title": info["title"], "size_m": info.get("size_m"), "buffed_class": info.get("buffed_class"),
                 "debuffed_class": info.get("debuffed_class"), "mechanic": info.get("mechanic"), "hazard": info.get("hazard"),
                 "env": ENV.get(info["map"], {})})
dump("maps", maps)
