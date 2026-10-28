"""Build the 125-card list: design/cards.json (for the game) and design/cards.md (to read).

Each card is (name, category, effect text, value at stack 1, growth per extra stack[, "int"]).
A card can be taken up to 6 times. Copy n shows the card one rarity tier higher than copy n-1
(common climbs to mythic on the 6th copy), and its numbers grow each time.

  python make_cards.py
"""
import json
import math
import re
from pathlib import Path

RARITIES = ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
OFFER_WEIGHT = {"common": 45, "uncommon": 25, "rare": 15, "epic": 9, "legendary": 5, "mythic": 1}

CARDS = {
    "common": [
        ("Sharp Eyes", "offense", "+{v}% critical hit chance", 3, 1.5),
        ("Steady Hands", "offense", "-{v}% weapon spread", 5, 2),
        ("Quick Reload", "offense", "-{v}% reload time", 6, 2.5),
        ("Heavy Rounds", "offense", "+{v}% weapon damage", 4, 2),
        ("Rapid Trigger", "offense", "+{v}% fire rate", 4, 2),
        ("Long Barrel", "offense", "+{v}% weapon range", 6, 3),
        ("Spell Edge", "offense", "+{v}% spell damage", 4, 2),
        ("Keen Blade", "offense", "+{v}% melee damage", 5, 2.5),
        ("Deep Quiver", "offense", "+{v}% maximum ammo", 8, 4),
        ("Dead Focus", "offense", "+{v}% headshot damage", 6, 3),
        ("Iron Skin", "defense", "+{v}% armor", 4, 2),
        ("Thick Hide", "defense", "+{v}% maximum health", 4, 2),
        ("Mana Ward", "defense", "+{v}% spell resistance", 5, 2.5),
        ("Second Wind", "defense", "Regenerate {v} health per second", 0.5, 0.25),
        ("Quick Patch", "defense", "Healing pickups heal +{v}% more", 8, 4),
        ("Steady Stance", "defense", "-{v}% knockback taken", 8, 4),
        ("Warding Charm", "defense", "-{v}% status effect duration", 8, 4),
        ("Shield Polish", "defense", "+{v}% shield strength", 6, 3),
        ("Light Step", "mobility", "+{v}% movement speed", 3, 1.5),
        ("Spring Legs", "mobility", "+{v}% jump height", 5, 2.5),
        ("Slide Grease", "mobility", "+{v}% slide distance", 8, 4),
        ("Quick Vault", "mobility", "+{v}% vault and climb speed", 8, 4),
        ("Dash Tonic", "mobility", "-{v}% dash cooldown", 5, 2.5),
        ("Sure Footing", "mobility", "+{v}% slow resistance", 8, 4),
        ("Fast Casting", "skill", "+{v}% cast speed", 4, 2),
        ("Cooldown Tonic", "skill", "-{v}% skill cooldowns", 3, 1.5),
        ("Wider Reach", "skill", "+{v}% area-of-effect radius", 4, 2),
        ("Mana Flow", "skill", "+{v}% mana regeneration", 6, 3),
        ("Skill Power", "skill", "+{v}% skill damage", 4, 2),
        ("Bigger Blast", "skill", "+{v}% area-of-effect damage", 4, 2),
        ("Meter Spark", "skill", "+{v}% class meter charge speed", 5, 2.5),
        ("Passive Boost", "skill", "+{v}% class passive strength", 4, 2),
        ("Treasure Sense", "economy", "Loot boxes give +{v}% XP", 8, 4),
        ("Scholar", "economy", "+{v}% XP from kills", 5, 2.5),
        ("Lucky Find", "economy", "+{v}% chance for a rarer loot box drop", 4, 2),
        ("Scavenger", "economy", "Kills refund {v}% of a magazine", 6, 3),
        ("Home Pride", "class", "+{v}% damage with your own class's skills", 3, 1.5),
        ("Map Native", "class", "Your home-map buff is {v}% stronger", 5, 2.5),
        ("Rival Resistance", "class", "Your map debuff is {v}% weaker", 6, 3),
        ("Set Collector", "class", "Armor set passives are {v}% stronger", 4, 2),
    ],
    "uncommon": [
        ("Marksman", "offense", "+{v}% damage beyond 25 m", 6, 3),
        ("Close Quarters", "offense", "+{v}% damage within 8 m", 6, 3),
        ("Chain Shot", "offense", "{v}% chance for shots to pierce an enemy", 10, 5),
        ("Overkill", "offense", "Excess damage splashes {v}% to nearby enemies", 20, 8),
        ("Opening Strike", "offense", "+{v}% damage on the first hit against a full-health enemy", 10, 5),
        ("Combo Counter", "offense", "Each hit in a row adds +{v}% damage (max 10 hits)", 0.5, 0.25),
        ("Hunter's Mark", "offense", "Enemies you hit take +{v}% damage from you for 4s", 6, 3),
        ("Elemental Edge", "offense", "Hits have a {v}% chance to burn or chill", 8, 4),
        ("Hit and Run", "mobility", "+{v}% speed for 2s after dealing damage", 10, 5),
        ("Thorns", "defense", "Reflect {v}% of melee damage back", 15, 7),
        ("Bulwark", "defense", "Your shield blocks {v}% more damage", 8, 4),
        ("Adrenaline", "defense", "+{v}% speed below 30% health", 10, 5),
        ("Life Steal", "defense", "Heal {v}% of damage dealt", 3, 1.5),
        ("Barrier Pop", "defense", "Kills grant a shield worth {v}% of max health", 8, 4),
        ("Cleanse", "defense", "Healing has a {v}% chance to remove a debuff", 20, 10),
        ("Stone Stance", "defense", "Standing still for 2s gives +{v}% armor", 12, 6),
        ("Patch Job", "defense", "Armor repairs {v}% per second out of combat", 2, 1),
        ("Echo Cast", "skill", "{v}% chance to cast a skill twice", 5, 2.5),
        ("Quick Recharge", "skill", "Kills reduce skill cooldowns by {v}%", 8, 4),
        ("Overflow", "skill", "Excess mana becomes {v}% shield", 20, 10),
        ("Arcane Surge", "skill", "+{v}% skill damage at full mana", 8, 4),
        ("Zone Control", "skill", "Area effects last {v}% longer", 10, 5),
        ("Opening Spell", "skill", "+{v}% skill damage on your first cast each life", 10, 5),
        ("Charge Siphon", "meter", "Damage dealt charges your meter {v}% faster", 6, 3),
        ("Meter Memory", "meter", "Keep {v}% of your meter when you die", 15, 7),
        ("Overcharge", "meter", "Your meter can fill {v}% past full", 10, 5),
        ("Steady Flow", "meter", "Your meter decays {v}% slower", 10, 5),
        ("Air Strafe", "mobility", "+{v}% air control", 15, 7),
        ("Dodge Roll", "mobility", "+{v}% dodge distance", 10, 5),
        ("Rooftop Runner", "mobility", "+{v}% speed on high ground", 8, 4),
    ],
    "rare": [
        ("Executioner", "offense", "+{v}% damage to enemies below 30% health", 15, 7),
        ("Ricochet Rounds", "offense", "Bullets bounce to a second target for {v}% damage", 25, 10),
        ("Piercing Gaze", "utility", "Enemies you hit are revealed to your team for {v}s", 1.5, 0.5),
        ("Vampiric Aura", "defense", "Heal {v}% of the damage your nearby allies deal", 4, 2),
        ("Frostbite Touch", "offense", "Your hits slow enemies by {v}%", 8, 3),
        ("Blazing Trail", "mobility", "Dashing leaves fire dealing {v} damage per second", 10, 5),
        ("Static Shock", "offense", "Every 6th shot chains lightning for {v}% damage", 40, 15),
        ("Poison Tip", "offense", "Hits poison for {v} damage per second for 4s", 4, 2),
        ("Shield Bash", "defense", "Shield bashes stun for {v}s", 0.3, 0.1),
        ("Deflector", "defense", "Reflect the first projectile every 8s for {v}% damage", 40, 15),
        ("Second Skin", "defense", "After taking damage gain +{v}% armor for 3s", 10, 4),
        ("Phase Step", "mobility", "Dash through enemies; dash cooldown -{v}%", 8, 4),
        ("Mana Battery", "skill", "Kills restore {v}% mana", 15, 6),
        ("Spell Weaver", "skill", "Casting a skill boosts your next shot by {v}%", 25, 10),
        ("Siphon Soul", "defense", "Kills give {v}% of max health as temporary health", 8, 3),
        ("Gale Boots", "mobility", "+{v}% movement speed, doubled in the air", 5, 2),
        ("Treasure Hunter", "economy", "Loot boxes show on the map and drop {v}% more gear", 10, 4),
        ("Guardian Spirit", "defense", "An ally near you takes {v}% less damage", 5, 2),
        ("Rune Etcher", "class", "Armor piece passives are {v}% stronger", 10, 4),
        ("Meter Burst", "meter", "Kills fill {v}% of your meter", 10, 4),
        ("Pack Leader", "utility", "Nearby allies deal +{v}% damage", 3, 1.5),
        ("Silent Step", "mobility", "Crouch-walking is silent and {v}% faster", 15, 6),
    ],
    "epic": [
        ("Tide Caller", "skill", "Skills leave a puddle that heals allies {v} health per second", 5, 2),
        ("Thunderstep", "mobility", "Dashing releases a lightning arc for {v} damage", 40, 15),
        ("Echoing Blade", "offense", "Melee attacks create a shockwave for {v}% damage", 30, 10),
        ("Blood Pact", "skill", "Spend 10% health to refill {v}% of your mana", 40, 15),
        ("Grave Chill", "offense", "Killed enemies leave a frost field that slows for {v}s", 3, 1),
        ("Hunter's Instinct", "utility", "Enemies below 40% health show through walls for {v}s", 1.5, 0.5),
        ("Spell Mirror", "defense", "Reflect the first skill cast at you every {v}s", 20, -2),
        ("Overload Core", "meter", "At full meter, deal +{v}% damage for 6s", 25, 10),
        ("Twin Souls", "class", "Gain a second copy of your passive at {v}% strength", 40, 12),
        ("Fortress Mode", "defense", "Standing still for 3s gives {v}% damage reduction", 20, 6),
        ("Ember Heart", "defense", "Below 25% health, explode for {v} damage once per life", 120, 40),
        ("Void Anchor", "skill", "Your signature skill pulls enemies {v} m toward you", 3, 1),
        ("Mercy Mark", "utility", "Allies you heal deal +{v}% damage for 5s", 10, 4),
        ("Loot Magnet", "economy", "Pickups and loot boxes come to you from {v} m", 6, 2),
        ("Spellblade", "skill", "Each melee hit reduces skill cooldowns by {v}s", 0.5, 0.2),
        ("Arcane Armor", "defense", "{v}% of damage taken drains mana instead of health", 20, 6),
    ],
    "legendary": [
        ("Dragon's Pact", "skill", "Your signature skill burns enemies for {v}% of its damage over 5s", 30, 10),
        ("Archmage Mantle", "skill", "The first {v} casts each life have no cooldown", 1, 0.5, "int"),
        ("Thousand Cuts", "offense", "Gain +{v}% damage for every 10 hits in a row", 5, 2),
        ("Bastion", "defense", "Your shield blocks {v}% of ranged damage", 50, 8),
        ("Ghost Walk", "utility", "After a kill you turn invisible for {v}s", 2, 0.6),
        ("Tidebound", "skill", "Area skills gain +{v}% radius and pull enemies in", 20, 6),
        ("Stormcaller's Gift", "skill", "Each ultimate cast chains lightning for {v} damage", 150, 50),
        ("Grave Whisper", "utility", "Enemies you kill fight for you for {v}s", 4, 1),
        ("Rune of Plenty", "economy", "An extra card choice every {v} levels", 6, -0.8, "int"),
        ("Soul Forge", "economy", "Kills have a {v}% chance to drop a gear piece", 6, 2),
    ],
    "mythic": [
        ("Phoenix Heart", "defense", "Once per match, revive with {v}% health", 40, 10),
        ("Time Fracture", "meter", "Killing with an ultimate refunds {v}% of your meter", 40, 12),
        ("Omnimancer", "class", "Skills from other classes get {v}% of your class mastery buff", 40, 12),
        ("Worldbreaker", "skill", "Area skills hit twice; the second hit deals {v}% damage", 40, 12),
        ("Mythic Echo", "meter", "Your ultimate is cast again after {v}s", 4, -0.5),
        ("Crown of Kings", "utility", "Allies near you gain {v}% of your damage bonuses", 20, 8),
        ("Fate Weaver", "economy", "See {v} cards on every level-up", 4, 0.4, "int"),
    ],
}


def fmt(value, integer):
    if integer:
        return str(int(math.floor(value + 1e-9)))
    value = round(value, 2)
    return str(int(value)) if value == int(value) else f"{value:g}"


def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


cards = []
for rarity, rows in CARDS.items():
    base_tier = RARITIES.index(rarity)
    for row in rows:
        name, category, text, base, step = row[:5]
        integer = len(row) > 5 and row[5] == "int"
        values = [fmt(base + step * n, integer) for n in range(6)]
        cards.append({
            "number": len(cards) + 1,
            "id": slug(name),
            "name": name,
            "base_rarity": rarity,
            "category": category,
            "effect": text,
            "values_by_stack": values,
            "effect_by_stack": [text.replace("{v}", v) for v in values],
            "rarity_by_stack": [RARITIES[min(base_tier + n, 5)] for n in range(6)],
            "offer_weight": OFFER_WEIGHT[rarity],
            "max_stack": 6,
        })

counts = {r: len(rows) for r, rows in CARDS.items()}
assert len(cards) == 125, len(cards)
assert len({c["id"] for c in cards}) == 125, "duplicate card names"
assert list(counts.values()) == [40, 30, 22, 16, 10, 7], counts

out = Path(__file__).resolve().parent
(out / "cards.json").write_text(json.dumps({"count": len(cards), "rarity_order": RARITIES, "offer_weight": OFFER_WEIGHT,
                                            "cards": cards}, indent=1), encoding="utf-8")

lines = ["# The 125 cards", "",
         "Generated by `make_cards.py`; the data for the game is in `cards.json`.", "",
         "- **Level up:** pick 1 of 3 cards.",
         "- **Stacking:** a card can be taken up to 6 times. Each copy is stronger, and each copy shows **one rarity higher** than the last (common reaches mythic on the 6th copy).",
         "- **How often each rarity is offered:** " + ", ".join(f"{r} {w}%" for r, w in OFFER_WEIGHT.items()) + ".",
         "- Card types: offense, defense, mobility, skill, meter, economy, class, utility.", ""]
lines.append("| Rarity | Cards |\n|---|---|\n" + "\n".join(f"| {r.title()} | {n} |" for r, n in counts.items()) + f"\n| **Total** | **{len(cards)}** |\n")
for rarity in RARITIES:
    lines += [f"## {rarity.title()} ({counts[rarity]})", "",
              "| # | Card | Type | 1st copy | 6th copy |", "|---|---|---|---|---|"]
    for c in cards:
        if c["base_rarity"] == rarity:
            lines.append(f"| {c['number']} | **{c['name']}** | {c['category']} | {c['effect_by_stack'][0]} | {c['effect_by_stack'][5]} |")
    lines.append("")
(out / "cards.md").write_text("\n".join(lines), encoding="utf-8")
print(f"{len(cards)} cards", counts)
