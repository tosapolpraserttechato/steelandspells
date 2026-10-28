class_name SkillArt
extends RefCounted
## Skill buttons: every skill gets its own picture (IconArt glyph + element palette), a frame shape that says what kind of skill it is
## (projectile = arrow, beam = hexagon, area = octagon, zone = round, buff = shield, heal = cross, summon = battlement...),
## a background pattern from its element (embers, frost facets, cracks of lightning, bubbles, runes...) and a small badge for its main effect.

# id -> "glyph" or "glyph:palette"
const ICONS := {
	"druid_vine_whip": "vine", "druid_spore_cloud": "mushroom", "druid_thorn_skin": "thorns", "druid_regrowth": "plus_leaf", "druid_wild_dash": "footsteps:leaf", "druid_bloom": "flower",
	"druid_wild_bloom": "sprout", "druid_forests_wrath": "tree", "druid_thorn_volley": "arrow_fly:leaf", "druid_leaf_storm": "spiral:leaf", "druid_wild_growth": "leaf", "druid_stinging_swarm": "scarab:poison",
	"sea_king_tidal_wave": "wave", "sea_king_water_jet": "beam:water", "sea_king_bubble_shield": "bubble", "sea_king_riptide": "dash:water", "sea_king_coral_spikes": "coral", "sea_king_healing_tide": "shell",
	"sea_king_maelstrom": "spiral:water", "sea_king_tsunami": "crest", "sea_king_trident_throw": "trident", "sea_king_ink_cloud": "squid", "sea_king_undertow": "arrow_down:water", "sea_king_pearl_barrier": "orb:moon",
	"flame_lord_fireball": "fireball", "flame_lord_flame_cone": "flame", "flame_lord_fire_dash": "dash:flame", "flame_lord_ember_shield": "shield:flame", "flame_lord_magma_pool": "rock:flame",
	"flame_lord_heat_wave": "sun", "flame_lord_inferno_ring": "ring_fire", "flame_lord_supernova": "burst", "flame_lord_flame_wall": "wall:flame", "flame_lord_ember_barrage": "barrage",
	"flame_lord_phoenix_rise": "wings:flame", "flame_lord_lava_whip": "vine:flame",
	"frost_mage_ice_shard": "ice_shard", "frost_mage_frost_nova": "burst:ice", "frost_mage_ice_wall": "wall:ice", "frost_mage_blink": "snowflake", "frost_mage_blizzard": "wind:ice",
	"frost_mage_glacial_armor": "shield:ice", "frost_mage_avalanche_strike": "rock:ice", "frost_mage_absolute_zero": "crystal:ice", "frost_mage_ice_lance": "arrow_fly:ice",
	"frost_mage_frozen_ground": "boot:ice", "frost_mage_icicle_rain": "icicles", "frost_mage_permafrost": "hex:ice",
	"thunder_god_lightning_bolt": "bolt", "thunder_god_thunder_clap": "burst:bolt", "thunder_god_storm_dash": "dash:bolt", "thunder_god_chain_lightning": "chain_bolt", "thunder_god_static_field": "orb:bolt",
	"thunder_god_sky_hammer": "hammer", "thunder_god_thunderstorm": "spiral:bolt", "thunder_god_wrath_of_the_heavens": "stormcloud", "thunder_god_storm_call": "arrow_down:bolt",
	"thunder_god_overcharge": "gauge:bolt", "thunder_god_thunder_javelin": "arrow_fly:bolt", "thunder_god_lightning_step": "boot:bolt",
	"necromancer_soul_bolt": "ghost:shadow", "necromancer_bone_spear": "bone", "necromancer_raise_skeleton": "skull", "necromancer_death_coil": "spiral:shadow", "necromancer_wither": "scythe:shadow",
	"necromancer_grave_step": "footsteps:bone", "necromancer_grave_eruption": "hand:bone", "necromancer_army_of_the_dead": "tombstone", "necromancer_bone_armor": "shield:bone",
	"necromancer_curse_of_decay": "web:shadow", "necromancer_soul_drain": "heart:shadow", "necromancer_bone_prison": "cage",
	"arcanist_arcane_missiles": "barrage:arcane", "arcanist_mana_shield": "shield_star:arcane", "arcanist_blink": "portal", "arcanist_silence_ray": "eye", "arcanist_arcane_orb": "orb",
	"arcanist_rune_trap": "rune", "arcanist_arcane_explosion": "burst:arcane", "arcanist_arcane_cataclysm": "book", "arcanist_mana_surge": "drop:arcane", "arcanist_prism_beam": "crystal:arcane",
	"arcanist_gravity_rune": "rune:moon", "arcanist_arcane_barrage": "staff",
	"poison_brewer_poison_flask": "flask", "poison_brewer_toxic_gas": "cloud", "poison_brewer_antidote": "plus:heal", "poison_brewer_acid_spit": "drop", "poison_brewer_sticky_brew": "web:poison",
	"poison_brewer_elixir": "potion:gold", "poison_brewer_cauldron_burst": "burst:poison", "poison_brewer_plague_cloud": "cloud:shadow", "poison_brewer_plague_vial": "potion:poison",
	"poison_brewer_bubbling_cauldron": "cauldron", "poison_brewer_panacea": "flask:heal", "poison_brewer_caustic_mist": "wind:poison",
	"pirate_captain_cannon_shot": "cannon", "pirate_captain_grapple_dash": "anchor", "pirate_captain_flintlock_volley": "bow", "pirate_captain_smoke_bomb": "orb:shadow", "pirate_captain_rum_heal": "mug",
	"pirate_captain_sabre_rush": "sword", "pirate_captain_broadside": "ship", "pirate_captain_ghost_ship": "ship:moon", "pirate_captain_powder_keg": "keg", "pirate_captain_boarding_axe": "axe",
	"pirate_captain_parrot_scout": "wings:leaf", "pirate_captain_anchor_slam": "fist:steel",
	"time_mage_time_slow": "clock:ice", "time_mage_rewind": "reload:gold", "time_mage_quicken": "dash:gold", "time_mage_stasis_bolt": "hex:gold", "time_mage_temporal_echo": "clock:arcane",
	"time_mage_age": "gear:earth", "time_mage_chrono_burst": "burst:gold", "time_mage_stop_time": "hand:moon", "time_mage_hourglass": "hourglass", "time_mage_time_skip": "portal:gold",
	"time_mage_overclock": "gear", "time_mage_paradox_bolt": "reload:arcane",
	"celestial_mage_moon_beam": "beam:moon", "celestial_mage_starfall": "meteor:gold", "celestial_mage_lunar_shield": "shield:moon", "celestial_mage_gravity_well": "portal:shadow",
	"celestial_mage_phase_blink": "ghost:moon", "celestial_mage_blessing": "plus:gold", "celestial_mage_eclipse_pulse": "eclipse", "celestial_mage_moonfall": "moon", "celestial_mage_crescent_slash": "slash:moon",
	"celestial_mage_star_shower": "star", "celestial_mage_moon_mend": "heart:moon", "celestial_mage_night_veil": "cloud:moon",
	"gm_ravn_pawn_push": "arrow_up:steel", "gm_ravn_knight_leap": "chess", "gm_ravn_bishop_beam": "beam:gold", "gm_ravn_rook_charge": "rook", "gm_ravn_queens_gambit": "crown", "gm_ravn_castling": "rook:gold",
	"gm_ravn_fork": "swords", "gm_ravn_queen_sacrifice": "crown:blood", "gm_ravn_en_passant": "dash:steel", "gm_ravn_zugzwang": "cage:gold", "gm_ravn_promotion": "pawn", "gm_ravn_stalemate": "web:gold",
	"desert_assassin_shadow_step": "mask", "desert_assassin_sand_veil": "cloud:earth", "desert_assassin_venom_blade": "dagger:poison", "desert_assassin_smoke_bomb": "cloud:steel",
	"desert_assassin_dagger_fan": "dagger_fan", "desert_assassin_mirage": "ghost:gold", "desert_assassin_sand_dash": "dash:earth", "desert_assassin_quick_slash": "slash",
	"desert_assassin_sirocco_gust": "wind:earth", "desert_assassin_mark_for_death": "crosshair:blood", "desert_assassin_dust_devil_flurry": "spiral:earth", "desert_assassin_vanishing_slaughter": "claws",
}

const FRAME_BY_FX := {"projectile": "arrow", "beam": "hex", "cone": "wedge", "aoe": "octagon", "zone": "round", "sprint": "slant", "teleport": "kite", "leap": "wedge", "buff": "shield",
	"heal": "cross", "summon": "tooth", "wall": "banner", "trap": "gem", "strikes": "square"}

# unit-square outlines of the frames
const FRAMES := {
	"square": [0.1, 0, 0.9, 0, 1, 0.1, 1, 0.9, 0.9, 1, 0.1, 1, 0, 0.9, 0, 0.1],
	"octagon": [0.27, 0, 0.73, 0, 1, 0.27, 1, 0.73, 0.73, 1, 0.27, 1, 0, 0.73, 0, 0.27],
	"hex": [0.5, 0, 0.95, 0.25, 0.95, 0.75, 0.5, 1, 0.05, 0.75, 0.05, 0.25],
	"arrow": [0.5, 0, 1, 0.4, 0.9, 1, 0.1, 1, 0, 0.4],
	"wedge": [0, 0, 1, 0, 1, 0.12, 0.8, 1, 0.2, 1, 0, 0.12],
	"slant": [0.2, 0, 1, 0, 0.8, 1, 0, 1],
	"kite": [0.5, 0, 1, 0.5, 0.5, 1, 0, 0.5],
	"shield": [0, 0.04, 0.5, 0, 1, 0.04, 1, 0.55, 0.5, 1, 0, 0.55],
	"cross": [0.2, 0, 0.8, 0, 0.8, 0.2, 1, 0.2, 1, 0.8, 0.8, 0.8, 0.8, 1, 0.2, 1, 0.2, 0.8, 0, 0.8, 0, 0.2, 0.2, 0.2],
	"tooth": [0, 0.2, 0.12, 0.2, 0.12, 0, 0.3, 0, 0.3, 0.2, 0.42, 0.2, 0.42, 0, 0.58, 0, 0.58, 0.2, 0.7, 0.2, 0.7, 0, 0.88, 0, 0.88, 0.2, 1, 0.2, 1, 1, 0, 1],
	"banner": [0, 0, 1, 0, 1, 1, 0.5, 0.84, 0, 1],
	"gem": [0.25, 0, 0.75, 0, 1, 0.5, 0.75, 1, 0.25, 1, 0, 0.5],
}
# glyph radius as a share of the button width, per frame (narrow frames get smaller pictures)
const GLYPH_SCALE := {"square": 0.34, "octagon": 0.33, "hex": 0.31, "arrow": 0.3, "wedge": 0.31, "slant": 0.31, "kite": 0.26, "shield": 0.31, "cross": 0.29, "tooth": 0.31, "banner": 0.31, "gem": 0.31, "round": 0.34}
const GLYPH_Y := {"arrow": 0.56, "wedge": 0.46, "shield": 0.44, "tooth": 0.56, "banner": 0.46}

const STATUS_BADGE := {"burn": "flame", "chill": "snowflake", "freeze": "crystal", "poison": "drop", "shock": "bolt", "stun": "star", "slow": "arrow_down", "root": "vine", "bleed": "claws",
	"weaken": "arrow_down", "vulnerable": "crosshair", "silence": "eye", "blind": "eye", "marked": "crosshair"}
const STATUS_BADGE_PAL := {"burn": "flame", "chill": "ice", "freeze": "ice", "poison": "poison", "shock": "bolt", "stun": "gold", "slow": "water", "root": "leaf", "bleed": "blood",
	"weaken": "shadow", "vulnerable": "blood", "silence": "arcane", "blind": "shadow", "marked": "blood"}
const FX_BADGE := {"heal": "plus", "buff": "arrow_up", "sprint": "dash", "teleport": "portal", "summon": "skull", "wall": "wall", "trap": "rune", "aoe": "burst", "cone": "slash", "leap": "boot",
	"strikes": "bolt", "zone": "cloud", "beam": "beam", "projectile": "arrow_fly"}

static var _spec_cache: Dictionary = {}
static var _poly_cache: Dictionary = {}


## Everything the button needs to be drawn, worked out once per skill.
static func spec_for_skill(skill: Dictionary) -> Dictionary:
	var id := String(skill.get("id", skill.get("name", "")))
	if _spec_cache.has(id):
		return _spec_cache[id]
	var pair: PackedStringArray = String(ICONS.get(id, "")).split(":")
	var glyph: String = pair[0] if pair[0] != "" else IconArt.glyph_for_skill(skill)
	var pal_key: String = pair[1] if pair.size() > 1 else ""
	var fx: Dictionary = skill.get("fx", {})
	var col: Color = Data.color_of(skill["color"]) if skill.has("color") else Color(0.7, 0.7, 0.8)
	var sts: Array = fx.get("sts", [])
	var badge := ""
	var badge_pal := ""
	if sts.size() > 0 and STATUS_BADGE.has(String(sts[0]["id"])):
		badge = STATUS_BADGE[String(sts[0]["id"])]
		badge_pal = STATUS_BADGE_PAL[String(sts[0]["id"])]
	elif FX_BADGE.has(String(fx.get("t", ""))):
		badge = FX_BADGE[String(fx.get("t", ""))]
	if badge == glyph:
		badge = ""
	var s := {
		"id": id, "glyph": glyph, "pal": pal_key, "color": col, "frame": FRAME_BY_FX.get(String(fx.get("t", "")), "square"), "name": String(skill.get("name", "")),
		"badge": badge, "badge_pal": badge_pal, "seed": absi(id.hash()) % 100000,
	}
	s["colors"] = IconArt.palette_for(glyph, col, pal_key)
	s["theme"] = pal_key if pal_key != "" else String(IconArt._def(glyph)[0])
	_spec_cache[id] = s
	return s


## For skills that have no entry in the table (quest skills): the picture comes from the name, the colour from the rarity.
static func spec_for_quest(q: Dictionary) -> Dictionary:
	var id := "quest_" + String(q.get("id", q.get("name", "")))
	if _spec_cache.has(id):
		return _spec_cache[id]
	var col: Color = Data.rarity_color(String(q.get("rarity", "common")))
	var glyph := IconArt.glyph_for_skill({"name": String(q.get("name", "")), "fx": {}})
	var s := {"id": id, "glyph": glyph, "pal": "", "color": col, "frame": "gem", "name": String(q.get("name", "")), "badge": "", "badge_pal": "", "seed": absi(id.hash()) % 100000}
	s["colors"] = IconArt.palette_for(glyph, col)
	s["theme"] = String(IconArt._def(glyph)[0])
	_spec_cache[id] = s
	return s


static func frame_poly(kind: String, s: Vector2) -> PackedVector2Array:
	var key := "%s_%d_%d" % [kind, int(s.x), int(s.y)]
	if _poly_cache.has(key):
		return _poly_cache[key]
	var out := PackedVector2Array()
	if kind == "round":
		for i in 32:
			var a := TAU * i / 32.0
			out.append(Vector2(0.5 + 0.5 * cos(a), 0.5 + 0.5 * sin(a)) * s)
	else:
		var arr: Array = FRAMES.get(kind, FRAMES["square"])
		for i in range(0, arr.size(), 2):
			out.append(Vector2(arr[i], arr[i + 1]) * s)
	_poly_cache[key] = out
	return out


static func _inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var r := Geometry2D.offset_polygon(poly, -d)
	return r[0] if r.size() > 0 else poly


## Draws the whole button into `ci` over `rect`. `st` carries the live state: cooldown (seconds left), cooldown_total, charge (-1 = not an ultimate),
## ready, special (signature), ult, disabled, letter, t (animation clock), show_name, badge.
static func draw_button(ci: CanvasItem, rect: Rect2, spec: Dictionary, st: Dictionary) -> void:
	var s := rect.size
	var pad := 3.0
	var kind: String = spec["frame"]
	var poly := frame_poly(kind, s - Vector2(pad * 2, pad * 2))
	var off := rect.position + Vector2(pad, pad)
	ci.draw_set_transform(off, 0.0, Vector2.ONE)
	var colors: Dictionary = spec["colors"]
	var skill_col: Color = spec["color"]
	var inner_s := s - Vector2(pad * 2, pad * 2)
	var t: float = st.get("t", 0.0)
	var rim: Color = colors["l"]
	if st.get("special", false):
		rim = Color(1.0, 0.82, 0.3)
	elif st.get("ult", false):
		rim = Color(1.0, 0.55, 0.3)
	# shadow
	var sh := PackedVector2Array()
	for p in poly:
		sh.append(p + Vector2(0, 2))
	ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.55))
	# gradient fill: the element's dark colour mixed with the skill colour
	var d: Color = (colors["d"] as Color).lerp(skill_col, 0.3).darkened(0.45)
	var m: Color = (colors["m"] as Color).lerp(skill_col, 0.3).darkened(0.1)
	var cols := PackedColorArray()
	for p in poly:
		var f: float = clampf(p.y / maxf(inner_s.y, 1.0), 0.0, 1.0)
		cols.append(d.lerp(m, pow(f, 1.4) * 0.8))
	ci.draw_polygon(poly, cols)
	_pattern(ci, String(spec["theme"]), inner_s, int(spec["seed"]), t, colors, poly)
	# glow disc + picture
	var gs: float = GLYPH_SCALE.get(kind, 0.32)
	var gy: float = GLYPH_Y.get(kind, 0.5)
	var c := Vector2(inner_s.x * 0.5, inner_s.y * gy - (3.0 if st.get("show_name", true) else 0.0))
	var r := inner_s.x * gs
	var lift := sin(t * 2.0 + float(spec["seed"])) * 0.6 if st.get("ready", false) else 0.0
	IconArt.draw_glyph(ci, spec["glyph"], c + Vector2(0, lift), r, skill_col, true, colors)
	# cooldown sweep
	var cd: float = st.get("cooldown", 0.0)
	if cd > 0.0:
		var frac := clampf(cd / maxf(float(st.get("cooldown_total", 1.0)), 0.01), 0.0, 1.0)
		var ctr := inner_s * 0.5
		var pie := PackedVector2Array([ctr])
		for i in 25:
			var a := -PI / 2.0 + TAU * frac * float(i) / 24.0
			pie.append(ctr + Vector2(cos(a), sin(a)) * inner_s.x)
		for piece in Geometry2D.intersect_polygons(pie, poly):
			ci.draw_colored_polygon(piece, Color(0, 0, 0, 0.66))
		var f := ThemeDB.fallback_font
		var txt := "%.0f" % ceilf(cd)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(inner_s.x * 0.34)).x
		ci.draw_string(f, ctr + Vector2(-tw * 0.5, inner_s.x * 0.12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(inner_s.x * 0.34), Color.WHITE)
	var charge: float = st.get("charge", -1.0)
	if cd <= 0.0 and charge >= 0.0 and charge < 0.999:
		var box := PackedVector2Array([Vector2(-2, inner_s.y * (1.0 - charge)), Vector2(inner_s.x + 2, inner_s.y * (1.0 - charge)), Vector2(inner_s.x + 2, inner_s.y + 2), Vector2(-2, inner_s.y + 2)])
		for piece in Geometry2D.intersect_polygons(box, poly):
			ci.draw_colored_polygon(piece, Color(1.0, 0.8, 0.3, 0.35))
	if st.get("disabled", false):
		ci.draw_colored_polygon(poly, Color(0, 0, 0, 0.5))
	# rim
	var closed := poly.duplicate()
	closed.append(poly[0])
	ci.draw_polyline(closed, Color(0.02, 0.02, 0.04), 4.0, true)
	var ready_now: bool = st.get("ready", false) and cd <= 0.0 and (charge < 0.0 or charge >= 0.999)
	var rim_col := rim
	if ready_now:
		rim_col = rim.lerp(Color(1, 1, 0.8), 0.5 + 0.5 * sin(t * 5.0))
	ci.draw_polyline(closed, rim_col, 2.4 if (ready_now or st.get("special", false)) else 1.8, true)
	if st.get("special", false) or st.get("ult", false):
		var inner := _inset(poly, 4.0)
		var ic := inner.duplicate()
		ic.append(inner[0])
		ci.draw_polyline(ic, Color(rim.r, rim.g, rim.b, 0.55), 1.0, true)
		for p in poly:
			ci.draw_circle(p, 2.2, rim)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var f2 := ThemeDB.fallback_font
	# the small badge for the main effect
	if spec["badge"] != "" and s.x >= 44.0:
		var br := s.x * 0.15
		var bc := Vector2(s.x - br - 3.0, s.y - br - (17.0 if st.get("show_name", true) else 4.0))
		ci.draw_circle(bc, br + 1.5, Color(0, 0, 0, 0.9))
		ci.draw_circle(bc, br, Color(0.08, 0.08, 0.12))
		IconArt.draw_glyph(ci, spec["badge"], bc, br * 0.82, skill_col, false, {}, spec["badge_pal"])
	# the name plate
	if st.get("show_name", true):
		var nm: String = String(spec["name"])
		var fs := 11 if s.x >= 60.0 else 9
		var tw2 := f2.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while tw2 > s.x - 8.0 and fs > 7:
			fs -= 1
			tw2 = f2.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pw := minf(maxf(tw2 + 10.0, s.x * 0.5), s.x)
		var pr := Rect2(Vector2((s.x - pw) * 0.5, s.y - 15.0), Vector2(pw, 14.0))
		ci.draw_rect(pr, Color(0.02, 0.02, 0.04, 0.88), true)
		ci.draw_rect(pr, Color(rim.r, rim.g, rim.b, 0.8), false, 1.0)
		ci.draw_string(f2, pr.position + Vector2(maxf((pw - tw2) * 0.5, 1.0), 11.0), nm, HORIZONTAL_ALIGNMENT_LEFT, pw - 2.0, fs, Color(1, 1, 1, 0.95))
	# the hot key
	var letter: String = st.get("letter", "")
	if letter != "":
		var kr := 8.5 if s.x >= 54.0 else 7.0
		ci.draw_circle(Vector2(kr + 1.0, kr + 1.0), kr + 1.2, Color(0, 0, 0, 0.85))
		ci.draw_circle(Vector2(kr + 1.0, kr + 1.0), kr, Color(0.16, 0.17, 0.24))
		ci.draw_arc(Vector2(kr + 1.0, kr + 1.0), kr, 0.0, TAU, 20, Color(rim.r, rim.g, rim.b, 0.9), 1.2)
		var lw := f2.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, int(kr * 1.5)).x
		ci.draw_string(f2, Vector2(kr + 1.0 - lw * 0.5, kr + 1.0 + kr * 0.52), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, int(kr * 1.5), Color.WHITE)


static func _line(ci: CanvasItem, poly: PackedVector2Array, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	if Geometry2D.is_point_in_polygon(a, poly) and Geometry2D.is_point_in_polygon(b, poly):
		ci.draw_line(a, b, col, w, true)


static func _dot(ci: CanvasItem, poly: PackedVector2Array, p: Vector2, r: float, col: Color) -> void:
	if Geometry2D.is_point_in_polygon(p, poly):
		ci.draw_circle(p, r, col)


## Pattern behind the picture, from the element (everything is kept inside the frame).
static func _pattern(ci: CanvasItem, theme: String, s: Vector2, seed_i: int, t: float, colors: Dictionary, poly: PackedVector2Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i + 17
	var light: Color = colors["l"]
	var c := s * 0.5
	var lo := Color(light.r, light.g, light.b, 0.4)
	var lo2 := Color(light.r, light.g, light.b, 0.2)
	match theme:
		"flame":
			for i in 8:
				var x := rng.randf_range(0.2, 0.8) * s.x
				var sp := rng.randf_range(0.25, 0.6)
				var ph := fposmod(t * sp + rng.randf(), 1.0)
				_dot(ci, poly, Vector2(x + sin(ph * 6.0 + i) * 3.0, s.y * (0.9 - 0.75 * ph)), 1.2 + rng.randf() * 1.3, Color(1.0, 0.8, 0.35, 0.85 * (1.0 - ph)))
		"ice":
			for i in 3:
				var a := Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.1, 0.5)) * s
				var b := a + Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(0.25, 0.5)) * s
				_line(ci, poly, a, b, lo2, 1.2)
				_line(ci, poly, a, a + (b - a).rotated(0.5) * 0.5, lo2, 1.0)
			for i in 3:
				var p := Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8)) * s
				_line(ci, poly, p - Vector2(3, 0), p + Vector2(3, 0), lo, 1.0)
				_line(ci, poly, p - Vector2(0, 3), p + Vector2(0, 3), lo, 1.0)
		"bolt":
			for k in 2:
				var x := rng.randf_range(0.25, 0.75) * s.x
				var prev := Vector2(x, s.y * 0.1)
				for i in 6:
					var nxt := Vector2(x + rng.randf_range(-0.1, 0.1) * s.x, s.y * (0.1 + (i + 1) * 0.15))
					_line(ci, poly, prev, nxt, lo2, 1.2)
					prev = nxt
					x = nxt.x
		"leaf", "bloom":
			for i in 8:
				var p := Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.15, 0.85)) * s
				var rr := 2.0 + rng.randf() * 2.0
				if Geometry2D.is_point_in_polygon(p, poly):
					ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -rr * 1.6), p + Vector2(rr, 0), p + Vector2(0, rr * 1.6), p + Vector2(-rr, 0)]), lo2)
		"poison", "coral":
			for i in 7:
				var p := Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.85)) * s
				var ph := fposmod(t * 0.2 + rng.randf(), 1.0)
				p.y -= ph * s.y * 0.12
				if Geometry2D.is_point_in_polygon(p, poly):
					ci.draw_arc(p, 1.8 + rng.randf() * 2.5, 0.0, TAU, 12, lo, 1.0, true)
		"water":
			for i in 3:
				var y := s.y * (0.55 + i * 0.13)
				var prev := Vector2(s.x * 0.1, y)
				for k in range(1, 9):
					var nxt := Vector2(s.x * (0.1 + 0.8 * k / 8.0), y + sin(k * 1.4 + t * 1.5 + i) * 2.0)
					_line(ci, poly, prev, nxt, lo2, 1.4)
					prev = nxt
		"arcane", "moon":
			var rot := t * 0.25
			for i in 4:
				ci.draw_arc(c, s.x * 0.34, rot + i * PI / 2.0, rot + i * PI / 2.0 + 0.9, 10, lo, 1.4, true)
			for i in 6:
				var p := Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.15, 0.85)) * s
				_dot(ci, poly, p, 0.9, Color(1, 1, 1, 0.35 + 0.3 * sin(t * 2.0 + i)))
		"shadow":
			for i in 3:
				var p := Vector2(rng.randf_range(0.3, 0.7) + sin(t * 0.4 + i) * 0.05, rng.randf_range(0.35, 0.75)) * s
				ci.draw_circle(p, s.x * rng.randf_range(0.12, 0.2), Color(0, 0, 0, 0.2))
		"gold":
			for i in 12:
				var a := TAU * i / 12.0
				var l0 := s.x * (0.31 if i % 3 == 0 else 0.34)
				ci.draw_line(c + Vector2(cos(a), sin(a)) * l0, c + Vector2(cos(a), sin(a)) * s.x * 0.37, lo, 1.2 if i % 3 == 0 else 0.8)
		_:
			for i in 10:
				var a := TAU * i / 10.0 + float(seed_i % 7)
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s.x * 0.18, c + Vector2(cos(a), sin(a)) * s.x * 0.34, lo2, 1.6)
