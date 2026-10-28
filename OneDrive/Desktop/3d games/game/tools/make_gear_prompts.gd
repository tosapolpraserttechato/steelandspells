extends SceneTree
## Writes the list of reference pictures that go to Hunyuan image-to-3D: ../asset_refs/gear/prompts_plain.tsv, one line `id<TAB>prompt`.
## EVERY picture (armor pieces, weapons, perches, chests) uses the same STYLE text and the same generator settings (Perchance, art style "Concept Art", square),
## (Perchance art style "Concept Art": realistic, not anime), so the whole game's models come from pictures in one art style. 85 sets x 5 pieces + 85 weapons + 12 perches + 6 chests = 528 lines.
## Run: godot --headless --path game --script res://tools/make_gear_prompts.gd

const STYLE := ", single isolated object on a plain white background, no person, front three-quarter view, realistic fantasy game asset concept art, photorealistic metal and leather materials, detailed engraving and wear, natural lighting, highly detailed"
const MATERIAL := {
	"plate": "polished steel plate", "leather": "stitched leather and straps", "chain": "riveted chainmail and steel", "scale": "overlapping metal scales",
	"robe": "embroidered cloth", "bone": "bone and dark leather", "crystal": "glowing crystal shards and silver", "organic": "carved bark, vines and leaves",
	"mech": "brass gears, rivets and pipes", "royal": "gold filigree and white enamel", "ice": "frosted blue steel and ice crystals", "flame": "blackened steel with glowing lava cracks",
	"storm": "dark steel with lightning engraving", "moon": "silver with moon motifs", "ocean": "coral, pearl and sea shell", "desert": "bronze, linen and gold ornaments",
}
const COLORS := {"white": Color(0.95, 0.95, 0.95), "black": Color(0.08, 0.08, 0.1), "grey": Color(0.5, 0.5, 0.55), "silver": Color(0.75, 0.78, 0.82), "red": Color(0.75, 0.12, 0.12),
	"crimson": Color(0.55, 0.1, 0.15), "orange": Color(0.95, 0.5, 0.1), "gold": Color(0.92, 0.75, 0.25), "yellow": Color(0.95, 0.9, 0.3), "green": Color(0.2, 0.6, 0.25),
	"dark green": Color(0.12, 0.3, 0.15), "teal": Color(0.15, 0.6, 0.6), "blue": Color(0.2, 0.35, 0.8), "navy": Color(0.1, 0.15, 0.4), "purple": Color(0.5, 0.25, 0.75),
	"violet": Color(0.3, 0.15, 0.45), "pink": Color(0.9, 0.5, 0.65), "brown": Color(0.4, 0.26, 0.15), "tan": Color(0.78, 0.65, 0.45), "ice blue": Color(0.65, 0.85, 0.95)}
const SLOT_PHRASE := {
	false: {"helmet": "a single helmet", "chestplate": "a single breastplate chest armor piece with shoulder plates", "shield": "a single shield", "leggings": "a single leg armor greave", "boots": "a single armored boot"},
	true: {"helmet": "a single magic hood with circlet", "chestplate": "a single magic robe top with shoulder mantle", "shield": "a single magical ward shield", "leggings": "a single ornate cloth leg wrap", "boots": "a single ornate slipper boot"},
}
const FAMILY_WORD := {"sword": "sword", "heavy": "two-handed greatsword", "axe": "battle axe", "mace": "mace", "polearm": "polearm spear", "scythe": "scythe", "dagger": "dagger", "claws": "pair of claw gauntlet blades",
	"whip": "whip", "bow": "longbow", "crossbow": "crossbow", "thrown": "throwing weapon", "staff": "magic staff", "wand": "magic wand", "orb": "floating magic orb", "tome": "spell tome book",
	"enchblade": "enchanted glowing sword", "gauntlet": "armored gauntlet fist weapon", "spiritbow": "glowing spirit bow"}
const PERCHES := {
	"flora_forest": "a wooden treehouse sniper lookout platform with rope rails and leaf roof", "toxic_swamp": "a rickety stilt hut sniper platform with glowing green jars",
	"underwater_ocean": "a coral reef lookout platform with pearl posts", "frozen_peaks": "an ice shelf sniper ledge with icicles and snow", "volcano_forge": "a black iron forge gallery sniper platform with glowing lava cracks",
	"desert_tomb": "a sandstone sun terrace sniper balcony with gold braziers", "shadow_crypt": "a bone balcony sniper platform with purple torches", "crystal_caves": "a crystal shelf sniper ledge with glowing crystals",
	"clockwork_mines": "a brass gear walk sniper platform with pipes and gears", "moon_sanctuary": "a white marble moon terrace sniper balcony with a glowing orb",
	"pirate_cove": "a ship's crow's nest sniper platform with ropes and barrels", "chess_arena": "a marble rook tower sniper balcony with black and white checker floor",
}
const CHESTS := {"common": "a plain wooden treasure chest with iron bands", "uncommon": "a green wooden treasure chest with silver bands", "rare": "a blue lacquered treasure chest with silver and a sapphire",
	"epic": "a purple treasure chest with gold bands and an amethyst", "legendary": "a golden treasure chest with a glowing gem", "mythic": "a black treasure chest with glowing runes and floating crystals"}


func _init() -> void:
	var sets: Array = _read("armor_sets") + _read("armor_sets_ext")
	var looks: Dictionary = _read("armor_looks")
	var weapons: Array = _read("weapons") + _read("weapons_ext")
	var lines: PackedStringArray = []
	for s in sets:
		var id: String = s["id"]
		var look: Dictionary = looks.get(id, {})
		var mat: String = MATERIAL.get(String(look.get("style", "plate")), "steel")
		var c1 := _color_name(Color.html(String(look.get("c1", "#999999"))))
		var c2 := _color_name(Color.html(String(look.get("c2", "#cccc99"))))
		var theme_word := String(s["name"]).to_lower()
		for slot in ["helmet", "chestplate", "shield", "leggings", "boots"]:
			var phrase: String = SLOT_PHRASE[bool(s["magic"])][slot]
			lines.append("%s__%s\t%s, %s with %s main color and %s trim, %s design%s" % [id, slot, phrase, mat, c1, c2, theme_word, STYLE])
	for w in weapons:
		var fam: String = FAMILY_WORD.get(String(w["family"]), "weapon")
		var elem := ""
		if w.has("on_hit"):
			elem = ", %s element energy glowing" % String(w["on_hit"]["id"])
		lines.append("weapon__%s\ta single %s named %s, %s%s, fantasy weapon, ornate design%s" % [w["id"], fam, String(w["name"]), String(w["desc"]).trim_suffix("."), elem, STYLE])
	for m in PERCHES:
		lines.append("perch__%s\t%s%s" % [m, PERCHES[m], STYLE])
	for r in CHESTS:
		lines.append("chest__%s\t%s%s" % [r, CHESTS[r], STYLE])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join("../asset_refs/gear"))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../asset_refs/gear/prompts_plain.tsv"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("GEAR_PROMPTS ", lines.size(), " lines")
	quit()


func _color_name(c: Color) -> String:
	var best := "grey"
	var bd := 99.0
	for n in COLORS:
		var k: Color = COLORS[n]
		var d := (c.r - k.r) * (c.r - k.r) + (c.g - k.g) * (c.g - k.g) + (c.b - k.b) * (c.b - k.b)
		if d < bd:
			bd = d
			best = n
	return best


func _read(name: String) -> Variant:
	var f := FileAccess.open("res://data/%s.json" % name, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())
