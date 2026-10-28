extends SceneTree
## Writes the data of the 85 weapons and 85 armor sets that is not in the older JSON files (the python generators are gone from this machine):
##   data/weapons_ext.json      30 new weapons (55 + 30 = 85), each with its own mechanic (see WeaponRunner, the "mech" key)
##   data/armor_sets_ext.json   35 new sets (50 + 35 = 85), five pieces each with their own passive, and a set bonus
##   data/armor_looks.json      the look of all 85 sets (style, colours, glow) and the signature weapon each set goes with
##   data/skins.json            10 weapon skins and 10 armor skins (some rarer than others; only a brand-new item rolls one)
## Run: godot --headless --path game --script res://tools/make_gear85.gd

const TIER := {"common": 1.0, "uncommon": 1.3, "rare": 1.7, "epic": 2.2, "legendary": 3.0, "mythic": 4.0}
const RARITY_IDX := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4, "mythic": 5}

# ------------------------------------------------------------------ the 30 new weapons
# id, name, family, magic, desc, fire, dmg, rate, range, then the optional keys; "mech" is the mechanic.
const WEAPONS := [
	{"id": "bloodletter", "name": "Bloodletter", "family": "sword", "magic": false, "desc": "Drinks what it cuts: heals you for 12% of the damage it deals.", "fire": "melee", "dmg": 46, "rate": 1.9, "range": 3.2, "arc": 100, "mech": {"lifesteal": 0.12}, "on_hit": {"id": "bleed", "dur": 3, "p": 0.2}},
	{"id": "executioner", "name": "Executioner", "family": "heavy", "magic": false, "desc": "Finishes the wounded: x1.8 damage to anything under 35% health.", "fire": "melee", "dmg": 88, "rate": 0.85, "range": 3.5, "arc": 110, "mech": {"execute": [0.35, 1.8]}},
	{"id": "dervish_blades", "name": "Dervish Blades", "family": "sword", "magic": false, "desc": "Twin scimitars that spin in a full circle.", "fire": "melee", "dmg": 34, "rate": 1.7, "range": 2.9, "arc": 360},
	{"id": "lancers_pike", "name": "Lancer's Pike", "family": "polearm", "magic": false, "desc": "Every thrust lunges you forward.", "fire": "melee", "dmg": 74, "rate": 1.0, "range": 4.4, "arc": 30, "mech": {"lunge": 5.0}},
	{"id": "reaver_hook", "name": "Reaver Hook", "family": "polearm", "magic": false, "desc": "A boarding hook that drags enemies toward you.", "fire": "melee", "dmg": 50, "rate": 1.3, "range": 4.2, "arc": 50, "mech": {"pull": 7.0}},
	{"id": "twin_fangs", "name": "Twin Fangs", "family": "dagger", "magic": false, "desc": "Two quick bites per swing, and the wounds keep bleeding.", "fire": "melee", "dmg": 22, "rate": 3.4, "range": 2.6, "arc": 60, "mech": {"double": 0.6}, "on_hit": {"id": "bleed", "dur": 3, "p": 0.35}},
	{"id": "siege_maul", "name": "Siege Maul", "family": "mace", "magic": false, "desc": "Slow, enormous, and it throws enemies across the room.", "fire": "melee", "dmg": 108, "rate": 0.65, "range": 3.5, "arc": 100, "stun": 0.35, "shockwave": 3.5, "mech": {"knock": 9.0}},
	{"id": "tempest_axe", "name": "Tempest Axe", "family": "axe", "magic": false, "desc": "Each hit throws lightning at two more enemies nearby.", "fire": "melee", "dmg": 60, "rate": 1.2, "range": 3.1, "arc": 110, "mech": {"chain": [2, 0.5]}},
	{"id": "harpoon", "name": "Harpoon", "family": "thrown", "magic": false, "desc": "Thrown hard: it drags whoever it hits toward you.", "fire": "thrown", "dmg": 46, "rate": 0.9, "range": 45, "speed": 50, "ammo": 8, "mech": {"pull": 8.0}},
	{"id": "thornspray_crossbow", "name": "Thornspray Crossbow", "family": "crossbow", "magic": false, "desc": "A scattergun of thorn bolts: eight at once, close range.", "fire": "projectile", "dmg": 13, "rate": 0.8, "range": 26, "speed": 60, "ammo": 6, "count": 8, "spread": 34},
	{"id": "gale_repeater", "name": "Gale Repeater", "family": "crossbow", "magic": false, "desc": "The longer you keep firing, the faster it shoots.", "fire": "projectile", "dmg": 15, "rate": 2.2, "range": 70, "speed": 85, "ammo": 28, "mech": {"ramp": [0.07, 6]}},
	{"id": "eagle_piercer", "name": "Eagle Piercer", "family": "bow", "magic": false, "desc": "A long, charged shot that goes through three enemies.", "fire": "projectile", "dmg": 84, "rate": 0.8, "range": 120, "speed": 100, "charge": 1.0, "ammo": 14, "mech": {"pierce": 3}},
	{"id": "thornlash_whip", "name": "Thornlash Whip", "family": "whip", "magic": false, "desc": "A barbed whip that reaches far and makes enemies bleed.", "fire": "melee", "dmg": 32, "rate": 1.8, "range": 6.0, "arc": 40, "on_hit": {"id": "bleed", "dur": 4, "p": 0.5}},
	{"id": "shadowrend_claws", "name": "Shadowrend Claws", "family": "claws", "magic": false, "desc": "Slashes in a short lunge and leaves bleeding gashes.", "fire": "melee", "dmg": 27, "rate": 2.9, "range": 2.5, "arc": 80, "mech": {"lunge": 3.0}, "on_hit": {"id": "bleed", "dur": 3, "p": 0.3}},
	{"id": "stormspark_wand", "name": "Stormspark Wand", "family": "wand", "magic": true, "desc": "Sparks arc from the target to three more enemies.", "fire": "projectile", "dmg": 15, "rate": 4.2, "range": 50, "speed": 80, "mana": 4, "mech": {"chain": [3, 0.55]}, "on_hit": {"id": "shock", "dur": 2, "p": 0.2}},
	{"id": "hex_wand", "name": "Hexwand", "family": "wand", "magic": true, "desc": "Hexes that curve toward the nearest enemy and weaken them.", "fire": "projectile", "dmg": 18, "rate": 2.6, "range": 55, "speed": 60, "mana": 5, "mech": {"homing": 4.0}, "on_hit": {"id": "weaken", "dur": 3, "p": 0.4}},
	{"id": "cometfall_staff", "name": "Cometfall Staff", "family": "staff", "magic": true, "desc": "A slow comet that explodes in a wide blast.", "fire": "projectile", "dmg": 92, "rate": 0.7, "range": 80, "speed": 38, "mana": 16, "radius": 3.8, "on_hit": {"id": "burn", "dur": 3, "p": 0.5}},
	{"id": "dawn_scepter", "name": "Dawn Scepter", "family": "staff", "magic": true, "desc": "Rays of dawn that heal you for 22% of the damage they deal.", "fire": "projectile", "dmg": 30, "rate": 1.7, "range": 60, "speed": 65, "mana": 8, "mech": {"lifesteal": 0.22}},
	{"id": "singularity_orb", "name": "Singularity Orb", "family": "orb", "magic": true, "desc": "A slow black sphere that pulls everything near it inward.", "fire": "projectile", "dmg": 40, "rate": 0.9, "range": 45, "speed": 30, "mana": 14, "radius": 3.0, "mech": {"pull": 8.0}},
	{"id": "siphon_codex", "name": "Siphon Codex", "family": "tome", "magic": true, "desc": "Seeking pages that give back mana with every hit.", "fire": "projectile", "dmg": 20, "rate": 2.0, "range": 40, "speed": 55, "mana": 3, "mech": {"mana_hit": 3.0, "homing": 3.0}},
	{"id": "trinity_rod", "name": "Trinity Rod", "family": "staff", "magic": true, "desc": "Three bolts in quick succession with every cast.", "fire": "projectile", "dmg": 22, "rate": 1.4, "range": 65, "speed": 75, "mana": 9, "mech": {"burst": [3, 0.09]}},
	{"id": "seeker_orbs", "name": "Seeker Orbs", "family": "orb", "magic": true, "desc": "Two orbs that hunt down the nearest enemy.", "fire": "projectile", "dmg": 24, "rate": 1.8, "range": 55, "speed": 40, "mana": 7, "count": 2, "spread": 12, "mech": {"homing": 6.0}},
	{"id": "dragonbreath_grimoire", "name": "Dragonbreath Grimoire", "family": "tome", "magic": true, "desc": "A cone of flames: five fireballs, short range.", "fire": "projectile", "dmg": 9, "rate": 3.2, "range": 15, "speed": 35, "mana": 4, "count": 5, "spread": 30, "on_hit": {"id": "burn", "dur": 3, "p": 0.3}},
	{"id": "rimelance_wand", "name": "Rimelance Wand", "family": "wand", "magic": true, "desc": "A lance of ice that pierces two enemies and chills them.", "fire": "projectile", "dmg": 36, "rate": 1.5, "range": 80, "speed": 95, "mana": 7, "mech": {"pierce": 2}, "on_hit": {"id": "chill", "dur": 3, "p": 0.5}},
	{"id": "soul_reaper", "name": "Soul Reaper", "family": "scythe", "magic": true, "desc": "Reaps the weak (x1.5 under 30% health) and steals a tenth of the damage as health.", "fire": "melee", "dmg": 66, "rate": 1.1, "range": 4.3, "arc": 170, "mana": 5, "mech": {"execute": [0.3, 1.5], "lifesteal": 0.1}},
	{"id": "starfall_bow", "name": "Starfall Bow", "family": "spiritbow", "magic": true, "desc": "A burst of three stars that bend toward their target.", "fire": "projectile", "dmg": 28, "rate": 1.1, "range": 90, "speed": 85, "mana": 8, "mech": {"burst": [3, 0.1], "homing": 2.0}},
	{"id": "void_piercer", "name": "Void Piercer", "family": "spiritbow", "magic": true, "desc": "A slow, charged shot of the void that goes through four enemies.", "fire": "projectile", "dmg": 110, "rate": 0.55, "range": 130, "speed": 120, "mana": 14, "charge": 1.2, "mech": {"pierce": 4}},
	{"id": "phantom_edge", "name": "Phantom Edge", "family": "enchblade", "magic": true, "desc": "A ghost blade: lunges at the foe and strikes twice.", "fire": "melee", "dmg": 44, "rate": 1.9, "range": 3.3, "arc": 90, "mana": 4, "mech": {"lunge": 6.0, "double": 0.5}},
	{"id": "voidfist", "name": "Voidfist", "family": "gauntlet", "magic": true, "desc": "Punches that tear a hole in the air and pull enemies in.", "fire": "melee", "dmg": 38, "rate": 2.2, "range": 2.5, "arc": 90, "mana": 4, "shockwave": 3.0, "mech": {"pull": 6.0}},
	{"id": "meteor_tome", "name": "Meteor Tome", "family": "tome", "magic": true, "desc": "A slow charge, then a meteor with a huge blast.", "fire": "projectile", "dmg": 118, "rate": 0.5, "range": 70, "speed": 30, "mana": 20, "radius": 4.4, "charge": 0.8, "on_hit": {"id": "burn", "dur": 3, "p": 0.6}},
]

# ------------------------------------------------------------------ the looks of all 85 sets: [style, c1, c2, glow, signature weapon]
const LOOKS := {
	"set_01_squire_s_plate": ["plate", "#9aa0aa", "#6a3a2a", "#ffd070", "longsword"],
	"set_02_knight_s_bastion": ["plate", "#c0c4cc", "#2a3f8a", "#8ab4ff", "claymore"],
	"set_03_ranger_s_leathers": ["leather", "#5a6a3a", "#8a6a3a", "#c8e070", "wayfarers_bow"],
	"set_04_pathfinder_s_mail": ["chain", "#7a8a6a", "#5a4a2a", "#d8e8a0", "hunters_recurve"],
	"set_05_dwarven_forgeplate": ["mech", "#6a5a50", "#d0782a", "#ff9a3a", "war_hammer"],
	"set_06_pirate_captain_s_regalia": ["royal", "#1a2f6a", "#d8b048", "#ffd870", "scimitar"],
	"set_07_corsair_s_leather": ["leather", "#4a2a2a", "#c8a060", "#ffb060", "rapier"],
	"set_08_desert_nomad_wraps": ["desert", "#d8c090", "#a0522d", "#ffd890", "kukri"],
	"set_09_sandstalker_leathers": ["desert", "#b8903a", "#6a4a2a", "#ffcf70", "rangers_shortbow"],
	"set_10_tomb_guardian_s_bronze": ["desert", "#b0803a", "#3a8a8a", "#5ae6d0", "boar_spear"],
	"set_11_mountain_warden_s_furs": ["organic", "#c8c0b0", "#6a5a4a", "#e8f0ff", "hatchet"],
	"set_12_iceplate_bastion": ["ice", "#b8dcf0", "#5a8ac0", "#aeeaff", "battle_axe"],
	"set_13_gravewarden_s_mail": ["bone", "#4a4a50", "#b8b09a", "#7aff9a", "harvest_scythe"],
	"set_14_foreman_s_gear": ["mech", "#8a6a3a", "#e0b030", "#ffe070", "flanged_mace"],
	"set_15_clockwork_brigandine": ["mech", "#5a4a3a", "#c8a050", "#ffd070", "heavy_crossbow"],
	"set_16_swamp_hunter_s_hides": ["organic", "#3a4a2a", "#6a7a3a", "#b0ff50", "hand_crossbow"],
	"set_17_mangrove_scale": ["scale", "#3a5a3a", "#7a9a4a", "#b8ff80", "javelins"],
	"set_18_sea_wolf_chainmail": ["chain", "#5a7a8a", "#c8c8c0", "#a0e0ff", "throwing_axes"],
	"set_19_coral_shell_armor": ["ocean", "#e07a6a", "#5ac8c0", "#7affe0", "glaive"],
	"set_20_forgemaster_s_plate": ["flame", "#3a3a40", "#ff6a1a", "#ff8a2a", "greataxe"],
	"set_21_obsidian_lamellar": ["scale", "#14141a", "#c03a2a", "#ff4a2a", "katana"],
	"set_22_skyguard_scale": ["storm", "#4a7ab0", "#e8e8f0", "#bde0ff", "halberd"],
	"set_23_windrider_s_leather": ["leather", "#7aaa9a", "#e0e8c8", "#c8fff0", "gilded_longbow"],
	"set_24_gladiator_s_harness": ["royal", "#a07a3a", "#6a1a1a", "#ffc040", "morning_star"],
	"set_25_chessmaster_s_formal_plate": ["royal", "#e8e4d8", "#15151a", "#ffe08a", "chess_staff"],
	"set_26_verdant_robes": ["robe", "#4a8a3a", "#d8e8a0", "#9aff6a", "nature_staff"],
	"set_27_tide_regalia": ["ocean", "#2a5a8a", "#a0e0e0", "#6ae0ff", "trident_staff"],
	"set_28_emberweave": ["robe", "#8a2a1a", "#ffb040", "#ff7a2a", "ember_staff"],
	"set_29_rimecloth": ["robe", "#8ab8d8", "#f0f8ff", "#bff0ff", "frost_staff"],
	"set_30_stormweave": ["robe", "#3a4a7a", "#f0e060", "#ffee70", "storm_staff"],
	"set_31_mirage_shroud": ["robe", "#c8a868", "#4a8a9a", "#ffe6a0", "arcane_wand"],
	"set_32_shroud_robes": ["robe", "#2a2430", "#7a5a9a", "#b07aff", "bone_staff"],
	"set_33_prism_vestments": ["crystal", "#c0a0e0", "#60d0ff", "#ffffff", "crystal_orb"],
	"set_34_alchemist_garb": ["robe", "#3a5a3a", "#c8a030", "#9aff4a", "venom_wand"],
	"set_35_chrono_vestments": ["moon", "#e8e0c0", "#2a2a3a", "#ffe08a", "chrono_orb"],
	"set_36_moonsilk": ["moon", "#c8d0e8", "#6a7ac0", "#bcd0ff", "moonlight_bow"],
	"set_37_grandmaster_s_suit": ["royal", "#14141a", "#e8e4d8", "#ffe08a", "star_orb"],
	"set_38_sun_priest_vestments": ["royal", "#f0d890", "#c04a1a", "#ffd04a", "wisp_bow"],
	"set_39_starweaver_robes": ["moon", "#1a1a4a", "#ffe8a0", "#ffe890", "codex_of_stars"],
	"set_40_voidwalker_raiment": ["crystal", "#0e0a1c", "#8a3aff", "#a45aff", "void_orb"],
	"set_41_runesmith_robes": ["robe", "#4a4a5a", "#4ac0ff", "#6adaff", "embers_spellbook"],
	"set_42_spiritcaller_mantle": ["bone", "#5a6a6a", "#a8ffe0", "#7affd0", "grimoire_of_shadows"],
	"set_43_witchwood_robes": ["organic", "#3a2a3a", "#7aa04a", "#a0ff6a", "shadow_wand"],
	"set_44_dreamweaver_silks": ["moon", "#8a6ab0", "#f0d0ff", "#e0b0ff", "tome_of_frost"],
	"set_45_seer_s_regalia": ["robe", "#3a3a6a", "#e0c070", "#ffe090", "ember_orb"],
	"set_46_phoenix_plumage": ["flame", "#c0301a", "#ffc040", "#ff8030", "phoenix_bow"],
	"set_47_frostbound_vestments": ["ice", "#7aa8d0", "#e8f4ff", "#9ae0ff", "frostbrand"],
	"set_48_stormcaller_mantle": ["storm", "#2a3060", "#fff070", "#fff090", "stormcaller"],
	"set_49_shadowdancer_veils": ["moon", "#1a1a28", "#7a7ac0", "#9a9aff", "twin_daggers"],
	"set_50_crystal_mail": ["crystal", "#6a9ac8", "#e0f4ff", "#a0e0ff", "stone_fist"],
}

# ------------------------------------------------------------------ the 35 new sets
# id suffix, name, magic, rarity, theme, [style, c1, c2, glow], weapon, set bonus {desc, mods, extra keys...}
const NEW_SETS := [
	["bloodmoon_plate", "Bloodmoon Plate", false, "rare", "blood", ["plate", "#7a1f2b", "#c9a24a", "#ff3355"], "bloodletter",
		{"desc": "Bloodthirst: you heal 7% of the damage you deal and hit the wounded harder.", "mods": {"lifesteal": {"add": 0.07}, "damage_vs_low": {"add": 0.1}}}],
	["headsman_s_regalia", "Headsman's Regalia", false, "epic", "blood", ["leather", "#2b2b30", "#8a1c1c", "#ff5533"], "executioner",
		{"desc": "Executioner: +25% damage to anything under 30% health, and a kill heals you.", "mods": {"damage_vs_low": {"add": 0.25}}, "heal_on_kill": 0.08}],
	["dervish_silks", "Dervish Silks", false, "uncommon", "swift", ["desert", "#d9b36a", "#3b7a8a", "#ffe08a"], "dervish_blades",
		{"desc": "Whirl: faster, longer slides and +8% movement speed.", "mods": {"slide_distance": {"mult": 0.3}, "move_speed": {"mult": 0.08}}}],
	["lancer_s_barding", "Lancer's Barding", false, "rare", "guard", ["plate", "#b9bcc6", "#2a4aa0", "#9ac0ff"], "lancers_pike",
		{"desc": "Steadfast: you are hard to knock back and take 10% less damage from projectiles.", "mods": {"knockback_resist": {"add": 0.4}, "projectile_resist": {"add": 0.1}}}],
	["reaver_s_hide", "Reaver's Hide", false, "uncommon", "pirate", ["organic", "#5a4630", "#9a2a2a", "#ff8a5a"], "reaver_hook",
		{"desc": "Boarding party: your hits slow enemies and you run faster for a moment after taking a hit.", "mods": {"speed_after_hit": {"add": 0.25}}, "on_hit": {"id": "slow", "dur": 2, "p": 0.2}}],
	["fangweave", "Fangweave", false, "rare", "venom", ["leather", "#2f3a2a", "#9acd32", "#b6ff3c"], "twin_fangs",
		{"desc": "Venomous: your hits poison and you resist poison.", "mods": {"weapon_damage": {"mult": 0.06}}, "on_hit": {"id": "poison", "dur": 3, "p": 0.25}, "resist": {"poison": 0.6}}],
	["siegebreaker_plate", "Siegebreaker Plate", false, "epic", "gear", ["mech", "#5a5f6a", "#d08a28", "#ffb040"], "siege_maul",
		{"desc": "Siegebreaker: +15% armor, +10% health and you cannot be stunned for long.", "mods": {"armor": {"add": 0.15}, "max_health": {"mult": 0.1}}, "resist": {"stun": 0.5}}],
	["tempest_mail", "Tempest Mail", false, "epic", "storm", ["storm", "#4a5e8a", "#f0e060", "#bde0ff"], "tempest_axe",
		{"desc": "Tempest: your hits shock enemies and a stormy aura slows those who come close.", "mods": {"move_speed": {"mult": 0.05}}, "on_hit": {"id": "shock", "dur": 3, "p": 0.2}, "aura": {"radius": 4, "sts": [{"id": "slow", "dur": 2, "n": 1}]}}],
	["harpooner_s_oilskins", "Harpooner's Oilskins", false, "common", "tide", ["ocean", "#2e5a6a", "#d8c890", "#a0e8ff"], "harpoon",
		{"desc": "Sea legs: +10% health and a clean slide.", "mods": {"max_health": {"mult": 0.1}, "slide_distance": {"mult": 0.15}}}],
	["thornbriar_hide", "Thornbriar Hide", false, "uncommon", "nature", ["organic", "#3e5a2a", "#8a6a3a", "#ffd23c"], "thornspray_crossbow",
		{"desc": "Thorns: attackers take 12% of the damage they deal.", "mods": {"armor": {"add": 0.08}}, "reflect": 0.12}],
	["gale_runner_gear", "Gale Runner Gear", false, "rare", "storm", ["storm", "#7a8a9a", "#4aa0c0", "#c8f0ff"], "gale_repeater",
		{"desc": "Gale: +12% sprint speed and a faster reload.", "mods": {"sprint_speed": {"mult": 0.12}, "reload_speed": {"mult": 0.2}}}],
	["eaglesight_leathers", "Eaglesight Leathers", false, "rare", "swift", ["leather", "#6a5a3a", "#e6e0c0", "#fff0b0"], "eagle_piercer",
		{"desc": "Eagle eye: you see 20% farther and crit 8% more often.", "mods": {"sight": {"mult": 0.2}, "crit_chance": {"add": 0.08}}}],
	["thornlash_harness", "Thornlash Harness", false, "common", "venom", ["leather", "#4a3a2a", "#7a9a3a", "#c0ff60"], "thornlash_whip",
		{"desc": "Lash: your hits make enemies bleed.", "mods": {"weapon_damage": {"mult": 0.05}}, "on_hit": {"id": "bleed", "dur": 3, "p": 0.2}}],
	["shadowrend_garb", "Shadowrend Garb", false, "epic", "grave", ["leather", "#1e1e28", "#6a3a8a", "#a05cff"], "shadowrend_claws",
		{"desc": "Shadowstep: 12% to dodge a hit completely and +10% movement speed.", "mods": {"move_speed": {"mult": 0.1}}, "dodge": 0.12}],
	["tigerhide_wraps", "Tigerhide Wraps", false, "uncommon", "desert", ["desert", "#c88a3a", "#2a2a2a", "#ffcc66"], "tiger_claws",
		{"desc": "Prowl: +15% jump height and +6% damage.", "mods": {"jump_height": {"mult": 0.15}, "weapon_damage": {"mult": 0.06}}}],
	["ironlink_mail", "Ironlink Mail", false, "uncommon", "gear", ["chain", "#8a8f98", "#5a4a3a", "#e0e0e8"], "chain_whip",
		{"desc": "Linked: +12% armor and you shrug off slows.", "mods": {"armor": {"add": 0.12}}, "resist": {"slow": 0.6}}],
	["stormspark_vestments", "Stormspark Vestments", true, "rare", "storm", ["robe", "#3a4a8a", "#ffe04a", "#ffee66"], "stormspark_wand",
		{"desc": "Static: spells shock and you cast 10% faster.", "mods": {"cast_speed": {"mult": 0.1}}, "on_hit": {"id": "shock", "dur": 3, "p": 0.2}}],
	["hexweaver_robes", "Hexweaver Robes", true, "rare", "arcane", ["robe", "#4a2a5a", "#8aff5a", "#9dff6a"], "hex_wand",
		{"desc": "Hexed: your spells weaken enemies and deal +8% damage.", "mods": {"spell_damage": {"mult": 0.08}}, "on_hit": {"id": "weaken", "dur": 3, "p": 0.25}}],
	["cometfall_regalia", "Cometfall Regalia", true, "legendary", "fire", ["robe", "#1a1a3a", "#ff7a2a", "#ffa040"], "cometfall_staff",
		{"desc": "Cometfall: +20% area size on your spells and +12% spell damage.", "mods": {"aoe_radius": {"mult": 0.2}, "spell_damage": {"mult": 0.12}}, "on_hit": {"id": "burn", "dur": 3, "p": 0.25}}],
	["dawnbringer_vestments", "Dawnbringer Vestments", true, "legendary", "moon", ["royal", "#f2e8c8", "#e0a020", "#fff0a0"], "dawn_scepter",
		{"desc": "Dawn: you regenerate health and 10% of your damage heals you.", "mods": {"health_regen": {"add": 3.0}, "lifesteal": {"add": 0.1}}}],
	["singularity_shroud", "Singularity Shroud", true, "mythic", "arcane", ["crystal", "#0a0a14", "#6a2aff", "#8a4aff"], "singularity_orb",
		{"desc": "Event horizon: enemies near you are slowed and your spells deal +18% damage.", "mods": {"spell_damage": {"mult": 0.18}}, "aura": {"radius": 5, "sts": [{"id": "slow", "dur": 2, "n": 1}]}}],
	["siphon_scholar_s_garb", "Siphon Scholar's Garb", true, "uncommon", "arcane", ["robe", "#2a4a6a", "#6ac0ff", "#8ad4ff"], "siphon_codex",
		{"desc": "Studious: +20% mana and faster mana regeneration.", "mods": {"mana": {"mult": 0.2}, "mana_regen": {"mult": 0.25}}}],
	["trinity_priest_robes", "Trinity Priest Robes", true, "rare", "moon", ["moon", "#e0e4f0", "#5a6ac0", "#a0b0ff"], "trinity_rod",
		{"desc": "Trinity: spells cost 12% less mana and skills recharge 8% faster.", "mods": {"mana_cost": {"mult": -0.12}, "cooldown_reduction": {"add": 0.08}}}],
	["seeker_s_mantle", "Seeker's Mantle", true, "rare", "arcane", ["moon", "#4a6a8a", "#e0f0ff", "#c0e8ff"], "seeker_orbs",
		{"desc": "Farsight: +25% sight and your crits land 6% more often.", "mods": {"sight": {"mult": 0.25}, "crit_chance": {"add": 0.06}}}],
	["dragonbreath_robes", "Dragonbreath Robes", true, "epic", "fire", ["flame", "#7a1a10", "#ffb02a", "#ff6a1a"], "dragonbreath_grimoire",
		{"desc": "Dragonblood: your spells burn and you resist fire.", "mods": {"spell_damage": {"mult": 0.1}}, "on_hit": {"id": "burn", "dur": 3, "p": 0.3}, "resist": {"burn": 0.7}}],
	["rimelance_raiment", "Rimelance Raiment", true, "rare", "frost", ["ice", "#a8d4f0", "#ffffff", "#aef0ff"], "rimelance_wand",
		{"desc": "Rime: your spells chill and you resist cold.", "mods": {"spell_damage": {"mult": 0.07}}, "on_hit": {"id": "chill", "dur": 3, "p": 0.25}, "resist": {"chill": 0.6}}],
	["soul_reaper_s_shroud", "Soul Reaper's Shroud", true, "legendary", "grave", ["bone", "#1e1a24", "#c8d0c0", "#5affb0"], "soul_reaper",
		{"desc": "Harvest: a kill heals you for 12% of your health and you hit the wounded harder.", "mods": {"damage_vs_low": {"add": 0.2}}, "heal_on_kill": 0.12}],
	["starfall_regalia", "Starfall Regalia", true, "epic", "moon", ["moon", "#1a2a5a", "#c8d8ff", "#a0c0ff"], "starfall_bow",
		{"desc": "Starlight: +10% spell damage and 10% faster casting.", "mods": {"spell_damage": {"mult": 0.1}, "cast_speed": {"mult": 0.1}}}],
	["voidpiercer_s_veil", "Voidpiercer's Veil", true, "mythic", "arcane", ["crystal", "#120a24", "#a04aff", "#c07aff"], "void_piercer",
		{"desc": "Voidstep: 15% to dodge a hit, +15% spell damage, and a barrier when you are nearly dead.", "mods": {"spell_damage": {"mult": 0.15}}, "dodge": 0.15, "low_health_barrier": 60}],
	["phantom_dancer_silks", "Phantom Dancer Silks", true, "epic", "grave", ["moon", "#3a3a5a", "#aaccff", "#cfe4ff"], "phantom_edge",
		{"desc": "Phantom: 12% to dodge and +10% movement speed.", "mods": {"move_speed": {"mult": 0.1}}, "dodge": 0.12}],
	["voidfist_vestments", "Voidfist Vestments", true, "rare", "arcane", ["crystal", "#2a1a4a", "#9a6aff", "#b890ff"], "voidfist",
		{"desc": "Rift: +12% damage up close and +10% health.", "mods": {"damage_near": {"mult": 0.12}, "max_health": {"mult": 0.1}}}],
	["meteor_magus_regalia", "Meteor Magus Regalia", true, "mythic", "fire", ["flame", "#2a1010", "#ff5a1a", "#ff8a3a"], "meteor_tome",
		{"desc": "Impact: +25% area size and +20% spell damage; your spells burn.", "mods": {"aoe_radius": {"mult": 0.25}, "spell_damage": {"mult": 0.2}}, "on_hit": {"id": "burn", "dur": 4, "p": 0.35}}],
	["flamebearer_armor", "Flamebearer Armor", true, "rare", "fire", ["flame", "#8a2a1a", "#f0b030", "#ff9a30"], "flameblade",
		{"desc": "Flamebearer: your hits burn and you resist fire.", "mods": {"weapon_damage": {"mult": 0.08}}, "on_hit": {"id": "burn", "dur": 3, "p": 0.25}, "resist": {"burn": 0.6}}],
	["thunderfist_wraps", "Thunderfist Wraps", true, "rare", "storm", ["storm", "#3a3a50", "#ffe040", "#fff080"], "thunder_gauntlet",
		{"desc": "Thunderfist: your hits shock and you move 8% faster.", "mods": {"move_speed": {"mult": 0.08}}, "on_hit": {"id": "shock", "dur": 3, "p": 0.3}}],
	["briar_witch_robes", "Briar Witch Robes", true, "common", "nature", ["organic", "#2e4a2a", "#8a3a5a", "#d070a0"], "book_of_thorns",
		{"desc": "Briar: thorns hurt attackers for 10% of their damage.", "mods": {"spell_res": {"add": 0.08}}, "reflect": 0.1}],
]

# the passives of a piece: slot -> [[name noun, stat, mode, base value], ...] ; chosen by the set's seed, so sets with the same theme still differ
const POOL := {
	"helmet": [["Gaze", "crit_chance", "add", 0.02], ["Sight", "sight", "mult", 0.06], ["Mind", "mana", "mult", 0.08], ["Focus", "cooldown_reduction", "add", 0.02], ["Resolve", "headshot_resist", "add", 0.05], ["Insight", "spell_damage", "mult", 0.03]],
	"chestplate": [["Heart", "max_health", "mult", 0.04], ["Plating", "armor", "add", 0.04], ["Ward", "spell_res", "add", 0.04], ["Vigor", "health_regen", "add", 0.7], ["Mantle", "shield_strength", "mult", 0.1], ["Barbs", "reflect", "add", 0.03]],
	"shield": [["Bulwark", "projectile_resist", "add", 0.05], ["Aegis", "spell_res", "add", 0.05], ["Guard", "block_stun", "add", 0.06], ["Anchor", "knockback_resist", "add", 0.06], ["Rampart", "armor", "add", 0.05], ["Barrier", "shield_strength", "mult", 0.12]],
	"leggings": [["Stride", "slide_distance", "mult", 0.06], ["Spring", "jump_height", "mult", 0.06], ["Tread", "move_speed", "mult", 0.02], ["Stamina", "stamina", "mult", 0.08], ["Footing", "slow_resist", "add", 0.08]],
	"boots": [["Pace", "move_speed", "mult", 0.025], ["Dash", "sprint_speed", "mult", 0.05], ["Leap", "jump_height", "mult", 0.07], ["Hush", "sound", "mult", -0.1], ["Grip", "slow_resist", "add", 0.1]],
}
const SLOTS := ["helmet", "chestplate", "shield", "leggings", "boots"]
const PIECE_NAMES := {
	false: {"helmet": "Helm", "chestplate": "Cuirass", "shield": "Shield", "leggings": "Greaves", "boots": "Boots"},
	true: {"helmet": "Hood", "chestplate": "Robe", "shield": "Ward", "leggings": "Leggings", "boots": "Slippers"},
}

# ------------------------------------------------------------------ the skins (the paint pasted over a brand-new weapon or armor)
# weight: how common (higher = more common); tier: which crate rarity it is shown as. Weapon: tint + glow of the metal. Armor: new colours for the set.
const SKINS := [
	{"id": "ivory", "name": "Ivory", "tier": "common", "weight": 26.0, "tint": "#e8e0c8", "glow": "", "armor_c1": "#e8e0c8", "armor_c2": "#b09a60", "armor_glow": "#fff0c0"},
	{"id": "obsidian", "name": "Obsidian", "tier": "common", "weight": 22.0, "tint": "#1c1c26", "glow": "", "armor_c1": "#1c1c26", "armor_c2": "#5a5a70", "armor_glow": "#9090c0"},
	{"id": "crimson", "name": "Crimson", "tier": "uncommon", "weight": 16.0, "tint": "#8a1a22", "glow": "", "armor_c1": "#8a1a22", "armor_c2": "#d8c070", "armor_glow": "#ff6070"},
	{"id": "azure", "name": "Azure", "tier": "uncommon", "weight": 14.0, "tint": "#2a5aa0", "glow": "", "armor_c1": "#2a5aa0", "armor_c2": "#e0e8f0", "armor_glow": "#80c0ff"},
	{"id": "verdant", "name": "Verdant", "tier": "rare", "weight": 9.0, "tint": "#3a8a3a", "glow": "#7aff7a", "armor_c1": "#3a8a3a", "armor_c2": "#d8e8a0", "armor_glow": "#8aff8a"},
	{"id": "gilded", "name": "Gilded", "tier": "rare", "weight": 7.0, "tint": "#e0b030", "glow": "#ffd860", "armor_c1": "#e0b030", "armor_c2": "#fff0b0", "armor_glow": "#ffe070"},
	{"id": "frostwork", "name": "Frostwork", "tier": "epic", "weight": 4.0, "tint": "#a0d8f0", "glow": "#aef0ff", "armor_c1": "#a0d8f0", "armor_c2": "#ffffff", "armor_glow": "#c0f4ff"},
	{"id": "emberglass", "name": "Emberglass", "tier": "epic", "weight": 3.0, "tint": "#ff7a2a", "glow": "#ff6a1a", "armor_c1": "#802010", "armor_c2": "#ff9a30", "armor_glow": "#ff7a20"},
	{"id": "moonlit", "name": "Moonlit", "tier": "legendary", "weight": 1.5, "tint": "#c8d0f0", "glow": "#bcd0ff", "armor_c1": "#b8c4ee", "armor_c2": "#6a7ac0", "armor_glow": "#dce6ff"},
	{"id": "voidtouched", "name": "Voidtouched", "tier": "mythic", "weight": 0.6, "tint": "#12081f", "glow": "#9a4aff", "armor_c1": "#120a22", "armor_c2": "#8a3aff", "armor_glow": "#b070ff"},
]


func _init() -> void:
	_write("res://data/weapons_ext.json", WEAPONS)
	var sets: Array = []
	var looks := {}
	for i in NEW_SETS.size():
		var e: Array = NEW_SETS[i]
		var id := "set_%02d_%s" % [51 + i, e[0]]
		sets.append(_make_set(id, e, 51 + i))
		looks[id] = _look(e[5], e[6])
	for id in LOOKS:
		var l: Array = LOOKS[id]
		looks[id] = _look(l, l[4])
	# the clothes some classes always wear (see CharacterModel.dress): not a set, only a look
	looks["outfit_necromancer"] = {"style": "bone", "c1": "#1a1424", "c2": "#b8b09a", "glow": "#7affc0", "helm": "hood", "shoulder": "skull", "skirt": "tabard", "sleeve": "bracer", "shield": "ward", "weapon": "bone_staff"}
	_write("res://data/armor_sets_ext.json", sets)
	_write("res://data/armor_looks.json", looks)
	_write("res://data/skins.json", {"weapon": SKINS, "armor": SKINS})
	print("MAKE_GEAR85 done: ", WEAPONS.size(), " weapons, ", sets.size(), " new sets, ", looks.size(), " looks, ", SKINS.size(), " skins")
	quit()


func _look(l: Array, weapon: String) -> Dictionary:
	return {"style": l[0], "c1": l[1], "c2": l[2], "glow": l[3], "weapon": weapon}


func _make_set(id: String, e: Array, number: int) -> Dictionary:
	var name: String = e[1]
	var magic: bool = e[2]
	var rarity: String = e[3]
	var theme: String = e[4]
	var bonus: Dictionary = (e[7] as Dictionary).duplicate(true)
	var tier: float = float(TIER[rarity])
	var first := name.split(" ")[0].trim_suffix("'s")
	var pieces: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = number * 7717
	for slot in SLOTS:
		var pool: Array = POOL[slot]
		var pick: Array = pool[(number * 3 + SLOTS.find(slot) * 5 + rng.randi() % 3) % pool.size()]
		var value: float = float(pick[3]) * tier * 0.8
		var mods := {}
		mods[pick[1]] = {pick[2]: snappedf(value, 0.001)}
		pieces.append({"slot": slot, "name": "%s %s" % [name, PIECE_NAMES[magic][slot]], "passive": {"name": "%s %s" % [first, pick[0]], "mods": mods}})
	return {"id": id, "name": name, "magic": magic, "rarity": rarity, "theme": theme, "pieces": pieces, "set_bonus": bonus}


func _write(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, " "))
	f.close()
