class_name Weapons
extends RefCounted
## Which CC0 model each of the 55 weapons uses in the hand, and how to hold it. Models: Quaternius (med, rpg items), KayKit, Cardinal Zebra.
## Placeholders (no crossbow or whip model exists in the free packs): crossbows use bow models, the chain whip a wooden club.

const PACK := {"med": "res://models/weapons/med/%s.fbx", "kay": "res://models/weapons/kay/%s.gltf", "cz": "res://models/weapons/cz/%s.fbx", "rpg": "res://models/weapons/rpg/%s.fbx"}

# weapon id -> model path
const MODEL := {
	"longsword": ["cz", "Longsword"], "claymore": ["med", "Claymore"], "rapier": ["kay", "sword_B"], "scimitar": ["kay", "sword_C"], "katana": ["cz", "Katana"],
	"battle_axe": ["med", "Axe"], "greataxe": ["cz", "Greataxe"], "hatchet": ["med", "Axe_Small"],
	"war_hammer": ["med", "Hammer_Double"], "flanged_mace": ["cz", "Spiked mace"], "morning_star": ["kay", "hammer_B"],
	"boar_spear": ["med", "Spear"], "halberd": ["kay", "halberd"], "glaive": ["kay", "spear_A"], "harvest_scythe": ["med", "Scythe"],
	"twin_daggers": ["med", "Dagger"], "kukri": ["med", "Dagger_2"], "tiger_claws": ["kay", "fistweapon_A"],
	"wayfarers_bow": ["med", "Bow_Wooden"], "hunters_recurve": ["med", "Bow_Wooden2"], "gilded_longbow": ["med", "Bow_Golden"], "rangers_shortbow": ["cz", "Shortbow"],
	"hand_crossbow": ["kay", "bow_B"], "heavy_crossbow": ["kay", "bow_A"],
	"throwing_axes": ["med", "Axe_Small"], "javelins": ["med", "Spear"], "chain_whip": ["cz", "Wooden club"],
	"ember_staff": ["cz", "Magic staff"], "frost_staff": ["kay", "staff_A"], "storm_staff": ["kay", "staff_B"], "nature_staff": ["cz", "Magic staff"],
	"bone_staff": ["cz", "Bo Staff"], "trident_staff": ["kay", "spear_A"], "chess_staff": ["cz", "Magic staff"],
	"arcane_wand": ["kay", "wand_A"], "venom_wand": ["cz", "Magic Wand"], "shadow_wand": ["cz", "Magic Wand"],
	"crystal_orb": ["rpg", "Crystal1"], "chrono_orb": ["rpg", "Crystal2"], "star_orb": ["rpg", "Star"], "void_orb": ["rpg", "Crystal3"], "ember_orb": ["rpg", "Crystal5"],
	"embers_spellbook": ["rpg", "Book1_Closed"], "tome_of_frost": ["rpg", "Book2_Closed"], "grimoire_of_shadows": ["rpg", "Book3_Closed"],
	"codex_of_stars": ["rpg", "Book4_Closed"], "book_of_thorns": ["cz", "Spell Tome"],
	"flameblade": ["med", "Sword_Golden"], "frostbrand": ["kay", "sword_E"], "stormcaller": ["med", "Sword_2"],
	"thunder_gauntlet": ["rpg", "Glove"], "stone_fist": ["kay", "fistweapon_B"],
	"moonlight_bow": ["med", "Bow_Evil"], "wisp_bow": ["kay", "bow_A_withString"], "phoenix_bow": ["cz", "Longbow"],
	# the 30 newer weapons (placeholders from the same packs until their Hunyuan models are in models/weapons/hy/<id>.glb)
	"bloodletter": ["cz", "Short sword"], "executioner": ["cz", "Greatsword"], "dervish_blades": ["kay", "sword_C"], "lancers_pike": ["kay", "spear_A"], "reaver_hook": ["med", "Spear"],
	"twin_fangs": ["kay", "dagger_B"], "siege_maul": ["med", "Hammer_Double"], "tempest_axe": ["kay", "axe_C"], "harpoon": ["rpg", "Dart"], "thornspray_crossbow": ["kay", "bow_B"],
	"gale_repeater": ["kay", "bow_A"], "eagle_piercer": ["cz", "Longbow"], "thornlash_whip": ["cz", "Wooden club"], "shadowrend_claws": ["kay", "fistweapon_A"],
	"stormspark_wand": ["kay", "wand_A"], "hex_wand": ["cz", "Magic Wand"], "cometfall_staff": ["kay", "staff_A"], "dawn_scepter": ["cz", "Bo Staff"], "singularity_orb": ["rpg", "Crystal3"],
	"siphon_codex": ["rpg", "Book4_Closed"], "trinity_rod": ["kay", "staff_B"], "seeker_orbs": ["rpg", "Crystal5"], "dragonbreath_grimoire": ["rpg", "Book1_Closed"], "rimelance_wand": ["cz", "Magic Wand"],
	"soul_reaper": ["med", "Scythe"], "starfall_bow": ["kay", "bow_A_withString"], "void_piercer": ["med", "Bow_Evil"], "phantom_edge": ["med", "Sword_Golden"], "voidfist": ["rpg", "Glove"], "meteor_tome": ["rpg", "Book2_Closed"],
}

# family -> how it is held: length (m, the weapon is scaled to this), grip (0..1 along the long axis from the bottom: where the hand holds it),
# pitch (degrees the top tilts forward from straight up), axis ("y" = the model's long axis, "x" or "z" for models lying down), roll, offset (m, in the hand's space)
const HOLD := {
	"sword": {"length": 0.85, "grip": 0.13, "pitch": 40.0, "offset": Vector3(-0.04, 0.0, -0.04)}, "heavy": {"length": 1.1, "grip": 0.18, "pitch": 75.0},
	"axe": {"length": 0.7, "grip": 0.2, "pitch": 50.0, "offset": Vector3(-0.04, 0.0, 0.0)}, "mace": {"length": 0.7, "grip": 0.15, "pitch": 40.0, "offset": Vector3(-0.04, 0.0, -0.04)},
	"polearm": {"length": 1.6, "grip": 0.32, "pitch": 44.0, "offset": Vector3(-0.04, 0.0, 0.0)}, "scythe": {"length": 1.3, "grip": 0.3, "pitch": 50.0, "offset": Vector3(-0.04, 0.0, 0.0)},
	"dagger": {"length": 0.3, "grip": 0.15, "pitch": 60.0, "offset": Vector3(-0.04, 0.0, 0.0)}, "claws": {"length": 0.28, "grip": 0.5, "pitch": 80.0, "axis": "z", "offset": Vector3(-0.04, 0.0, 0.0)},
	"whip": {"length": 0.7, "grip": 0.12, "pitch": 50.0, "offset": Vector3(-0.04, 0.0, 0.0)}, "bow": {"length": 0.95, "grip": 0.5, "pitch": 36.0, "offset": Vector3(-0.04, 0.0, -0.04)},
	"crossbow": {"length": 0.55, "grip": 0.5, "pitch": 80.0, "axis": "x"}, "thrown": {"length": 0.5, "grip": 0.2, "pitch": 45.0, "offset": Vector3(-0.04, 0.0, 0.0)},
	"staff": {"length": 1.35, "grip": 0.36, "pitch": 40.0, "offset": Vector3(-0.04, 0.0, 0.0)}, "wand": {"length": 0.34, "grip": 0.15, "pitch": 50.0, "offset": Vector3(-0.04, 0.0, 0.0)},
	"orb": {"length": 0.22, "grip": 0.5, "pitch": 0.0, "offset": Vector3(-0.04, 0.0, 0.04)}, "tome": {"length": 0.26, "grip": 0.5, "pitch": 70.0, "offset": Vector3(-0.04, 0.0, 0.0)},
	"enchblade": {"length": 0.85, "grip": 0.13, "pitch": 40.0, "offset": Vector3(-0.04, 0.0, -0.04)}, "gauntlet": {"length": 0.3, "grip": 0.5, "pitch": 80.0, "axis": "z"},
	"spiritbow": {"length": 0.95, "grip": 0.5, "pitch": 36.0, "offset": Vector3(-0.04, 0.0, -0.04)},
}
const ELEMENT_COLOR := {"burn": Color(1.0, 0.5, 0.15), "chill": Color(0.6, 0.88, 1.0), "shock": Color(1.0, 0.95, 0.4), "poison": Color(0.5, 0.95, 0.25),
	"weaken": Color(0.6, 0.35, 0.85), "slow": Color(0.5, 0.75, 1.0), "bleed": Color(0.9, 0.15, 0.2), "marked": Color(1.0, 0.3, 0.35), "stun": Color(1.0, 0.85, 0.3),
	"vulnerable": Color(1.0, 0.4, 0.5)}


static var use_bevel := true


## `skin` is the name of the skin of a brand-new weapon ("" for an old one). A model made on Hunyuan (models/weapons/hy/<id>.glb) is used instead of the pack model when it exists.
static func visual_for(w: Dictionary, skin: String = "", worn: bool = false) -> Dictionary:
	var entry: Array = MODEL.get(w["id"], [])
	var path: String = (PACK[entry[0]] % entry[1]) if entry.size() == 2 else ""
	if entry.size() == 2 and use_bevel:
		var bev: String = "res://models/weapons/bev/%s_%s.glb" % [entry[0], String(entry[1]).replace(" ", "_")]
		if ResourceLoader.exists(bev):
			path = bev
	var hy := "res://models/weapons/hy/%s.glb" % w["id"]
	var from_hunyuan := ResourceLoader.exists(hy)
	if from_hunyuan:
		path = hy
	var hold: Dictionary = HOLD.get(w["family"], HOLD["sword"]).duplicate()
	hold["hunyuan"] = from_hunyuan
	if from_hunyuan and String(w["family"]) in ["wand", "dagger", "orb", "claws", "tome", "thrown"]:
		hold["length"] = float(hold["length"]) * 1.35                    # the small weapons read too small in a hand otherwise
	hold["skin"] = skin
	hold["worn"] = worn
	hold["path"] = path
	hold["weapon"] = w
	if w["id"] == "star_orb":
		hold["axis"] = "x"
	if w["id"] == "stone_fist":
		hold["axis"] = "x"
	return hold


static func color_for(w: Dictionary) -> Color:
	if w.has("on_hit") and ELEMENT_COLOR.has(w["on_hit"]["id"]):
		return ELEMENT_COLOR[w["on_hit"]["id"]]
	return Color(0.85, 0.8, 1.0) if w["magic"] else Color(1.0, 0.95, 0.8)


## Projectile look for a weapon family / element.
static func bolt_kind(w: Dictionary) -> String:
	match w["family"]:
		"bow", "crossbow", "spiritbow": return "arrow"
		"thrown": return "dart"
	if w.has("on_hit"):
		match w["on_hit"]["id"]:
			"burn": return "fire"
			"chill": return "ice"
			"shock": return "storm"
			"poison": return "leaf"
	return "bolt"
