class_name AnimRecipes
extends RefCounted
## Every skill and every weapon family moves its own way. A recipe is a few clips played in a row (the shared CC0 clips: CastEnter, Hook, MeleeC...),
## a body pose on top (lean, crouch, rise, spin, hop, lunge...) and a glow in the skill's colour. The same skill looks different on each class
## (a Thunder God shakes, a Necromancer leans back, a Frost Mage floats) and every skill has its own small speed, so no two casts look alike.
##   c: [[clip, speed, hold seconds (optional)], ...]   p: [[pose, amount, seconds, delay (optional)], ...]   g: 0 none, 1 right hand, 2 both hands, 3 ground ring

const R := {
	# ---- shots
	"bolt_quick": {"c": [["CastShoot", 1.7]], "p": [["recoil", 0.1, 0.35]], "g": 1},
	"bolt_charge": {"c": [["CastEnter", 2.0], ["CastShoot", 1.8]], "p": [["lean_back", 0.1, 0.3], ["lunge", 0.15, 0.35, 0.28]], "g": 1},
	"bolt_hurl": {"c": [["Throw", 2.3]], "p": [["lean_fwd", 0.22, 0.5]], "g": 0},
	"bolt_lob": {"c": [["Throw", 1.5]], "p": [["hop", 0.18, 0.6]], "g": 0},
	"bolt_two_hands": {"c": [["CastEnter", 1.6], ["CastShoot", 1.5]], "p": [["pulse", 0.05, 0.5]], "g": 2},
	"bolt_whip": {"c": [["Hook", 1.2], ["CastShoot", 2.0]], "p": [["tilt", 0.18, 0.5]], "g": 0},
	"bolt_volley": {"c": [["CastShoot", 2.2], ["CastShoot", 2.2], ["CastShoot", 2.2]], "p": [["shake", 0.03, 0.7]], "g": 1},
	"bolt_orbit": {"c": [["CastEnter", 1.4], ["CastShoot", 1.4]], "p": [["spin", 1.0, 0.7]], "g": 1},
	"bolt_cannon": {"c": [["Block", 2.4], ["CastShoot", 2.0]], "p": [["recoil", 0.3, 0.45, 0.25], ["shake", 0.05, 0.4, 0.25]], "g": 0},
	# ---- beams
	"beam_channel": {"c": [["CastEnter", 1.8], ["CastIdle", 1.0, 0.7], ["CastExit", 1.8]], "p": [["lean_fwd", 0.12, 1.2]], "g": 1},
	"beam_two_hand": {"c": [["CastEnter", 1.5], ["CastIdle", 1.0, 0.8], ["CastExit", 1.5]], "p": [["rise", 0.12, 1.3], ["pulse", 0.04, 1.2]], "g": 2},
	"beam_sweep": {"c": [["CastEnter", 2.0], ["MeleeC", 1.5]], "p": [["sway", 0.12, 1.0]], "g": 1},
	"beam_lunge": {"c": [["Hook", 1.2], ["CastIdle", 1.0, 0.5]], "p": [["lunge", 0.25, 0.9]], "g": 1},
	# ---- cones and slashes
	"cone_slash": {"c": [["MeleeB", 1.5]], "p": [["lean_fwd", 0.15, 0.4]], "g": 0},
	"cone_fast": {"c": [["MeleeA", 1.8], ["MeleeB", 1.8]], "p": [["lunge", 0.2, 0.5]], "g": 0},
	"cone_heavy": {"c": [["Attack", 1.5]], "p": [["lean_back", 0.15, 0.35], ["lean_fwd", 0.3, 0.45, 0.3]], "g": 0},
	"cone_spin": {"c": [["MeleeC", 1.6]], "p": [["spin", 1.0, 0.85]], "g": 0},
	"cone_breath": {"c": [["CastEnter", 1.6], ["CastShoot", 1.2]], "p": [["lean_back", 0.2, 0.7]], "g": 1},
	"cone_gust": {"c": [["Hook", 1.3], ["MeleeA", 1.6]], "p": [["tilt", -0.2, 0.7]], "g": 1},
	# ---- area
	"aoe_slam": {"c": [["JumpStart", 2.4, 0.3], ["JumpLand", 2.2]], "p": [["hop", 0.5, 0.35], ["crouch", 0.25, 0.4, 0.3], ["shake", 0.06, 0.5, 0.3]], "g": 3},
	"aoe_burst": {"c": [["CastEnter", 1.8], ["CastShoot", 1.8]], "p": [["rise", 0.2, 0.7], ["pulse", 0.1, 0.5, 0.2]], "g": 2},
	"aoe_pulse": {"c": [["Block", 2.0], ["CastShoot", 2.0]], "p": [["crouch", 0.12, 0.4], ["pulse", 0.12, 0.4, 0.4]], "g": 3},
	"aoe_spin": {"c": [["MeleeC", 1.4]], "p": [["spin", 2.0, 1.0], ["rise", 0.1, 1.0]], "g": 3},
	"aoe_pray": {"c": [["Consume", 1.8]], "p": [["rise", 0.28, 0.8]], "g": 2},
	"aoe_stomp": {"c": [["JumpLand", 2.6]], "p": [["crouch", 0.3, 0.4], ["shake", 0.08, 0.4]], "g": 3},
	"aoe_calm": {"c": [["Block", 1.6], ["CastExit", 1.6]], "p": [["sway", 0.08, 0.9]], "g": 3},
	# ---- zones
	"zone_sow": {"c": [["Throw", 2.0]], "p": [["crouch", 0.2, 0.6]], "g": 0},
	"zone_conjure": {"c": [["CastEnter", 1.5], ["CastIdle", 1.0, 0.4], ["CastExit", 1.8]], "p": [["crouch", 0.18, 0.9], ["sway", 0.06, 0.9]], "g": 2},
	"zone_slam": {"c": [["JumpLand", 2.2]], "p": [["crouch", 0.32, 0.5]], "g": 3},
	"zone_pour": {"c": [["Consume", 2.2]], "p": [["lean_fwd", 0.25, 0.6]], "g": 1},
	# ---- movement
	"dash_lunge": {"c": [["Hook", 1.2]], "p": [["lunge", 0.4, 0.5], ["lean_fwd", 0.25, 0.5]], "g": 0},
	"dash_slide": {"c": [["SlideStart", 1.6]], "p": [["lean_fwd", 0.35, 0.6], ["crouch", 0.15, 0.6]], "g": 0},
	"dash_roll": {"c": [["JumpStart", 3.0, 0.25], ["SlideStart", 2.0]], "p": [["spin", 1.0, 0.5], ["hop", 0.2, 0.5]], "g": 0},
	"dash_grapple": {"c": [["Throw", 2.4], ["Hook", 1.4]], "p": [["lean_fwd", 0.3, 0.8]], "g": 0},
	"teleport_vanish": {"c": [["CastExit", 1.6]], "p": [["shrink", 0.6, 0.4]], "g": 3},
	"teleport_blink": {"c": [["CastShoot", 2.5]], "p": [["pulse", 0.2, 0.3], ["shrink", 0.5, 0.3, 0.1]], "g": 2},
	"teleport_step": {"c": [["Hook", 1.8]], "p": [["tilt", 0.3, 0.4], ["shrink", 0.3, 0.35]], "g": 0},
	"teleport_rewind": {"c": [["EmoteNo", 3.0]], "p": [["spin", -1.0, 0.6], ["shrink", 0.25, 0.5]], "g": 2},
	"leap_up": {"c": [["JumpStart", 1.8]], "p": [["rise", 0.4, 0.8]], "g": 0},
	"leap_slam": {"c": [["JumpStart", 2.2, 0.35], ["JumpLand", 2.0]], "p": [["hop", 0.7, 0.4], ["crouch", 0.3, 0.4, 0.3]], "g": 3},
	# ---- buffs and heals
	"buff_guard": {"c": [["Block", 1.5]], "p": [["crouch", 0.1, 0.8]], "g": 3},
	"buff_flex": {"c": [["ChestOpen", 2.0]], "p": [["pulse", 0.1, 0.8]], "g": 3},
	"buff_drink": {"c": [["Consume", 2.0]], "p": [["lean_back", 0.12, 0.6]], "g": 1},
	"buff_roar": {"c": [["CastEnter", 1.4], ["EmoteYes", 2.4]], "p": [["lean_back", 0.2, 0.5], ["pulse", 0.12, 0.5, 0.4]], "g": 3},
	"buff_orb": {"c": [["CastEnter", 1.2], ["CastIdle", 1.0, 0.5]], "p": [["rise", 0.15, 0.9]], "g": 2},
	"buff_speed": {"c": [["SlideStart", 2.2]], "p": [["lean_fwd", 0.2, 0.4], ["tilt", 0.15, 0.4]], "g": 3},
	"heal_pray": {"c": [["Consume", 1.5], ["CastExit", 1.5]], "p": [["rise", 0.22, 1.0]], "g": 2},
	"heal_wave": {"c": [["CastEnter", 1.2], ["CastShoot", 1.2]], "p": [["sway", 0.1, 0.8]], "g": 2},
	"heal_touch": {"c": [["ChestOpen", 1.8]], "p": [["lean_fwd", 0.12, 0.8]], "g": 1},
	# ---- summons, walls, traps, strikes
	"summon_raise": {"c": [["ChestOpen", 1.6], ["CastShoot", 1.6]], "p": [["rise", 0.12, 0.8], ["shake", 0.03, 0.8]], "g": 2},
	"summon_call": {"c": [["CastEnter", 1.0], ["EmoteYes", 2.5]], "p": [["pulse", 0.08, 0.7]], "g": 2},
	"summon_decoy": {"c": [["EmoteNo", 3.0]], "p": [["spin", 0.5, 0.6], ["shrink", 0.2, 0.3]], "g": 3},
	"wall_push": {"c": [["Hook", 1.4], ["CastShoot", 1.6]], "p": [["lunge", 0.3, 0.6]], "g": 2},
	"wall_raise": {"c": [["CastEnter", 1.4], ["Block", 1.8]], "p": [["rise", 0.08, 0.8]], "g": 2},
	"trap_set": {"c": [["ChestOpen", 2.2]], "p": [["crouch", 0.3, 0.7]], "g": 1},
	"trap_throw": {"c": [["Throw", 2.4]], "p": [["lean_fwd", 0.18, 0.5]], "g": 0},
	"strikes_call": {"c": [["CastEnter", 1.0], ["CastIdle", 1.0, 0.35], ["CastShoot", 2.0]], "p": [["rise", 0.18, 0.9], ["lean_back", 0.15, 0.6]], "g": 2},
	"strikes_flurry": {"c": [["MeleeCombo", 2.0]], "p": [["shake", 0.04, 1.4]], "g": 0},
	"strikes_rain": {"c": [["EmoteYes", 2.6], ["CastShoot", 2.0]], "p": [["lean_back", 0.25, 0.8]], "g": 2},
	# ---- ultimates: bigger, slower, with a ring of light on the ground
	"ult_ascend": {"c": [["CastEnter", 1.0], ["EmoteYes", 1.8, 0.9], ["CastShoot", 1.5]], "p": [["rise", 0.5, 1.6], ["pulse", 0.12, 0.6, 0.8]], "g": 3},
	"ult_wave": {"c": [["Attack", 1.1]], "p": [["lean_back", 0.3, 0.5], ["lean_fwd", 0.45, 0.7, 0.45], ["shake", 0.08, 0.6, 0.5], ["hop", 0.2, 0.6]], "g": 3},
	"ult_nova": {"c": [["CastEnter", 0.8], ["CastIdle", 1.0, 0.6], ["CastShoot", 1.2]], "p": [["crouch", 0.2, 0.7], ["rise", 0.35, 0.9, 0.6], ["pulse", 0.2, 0.5, 0.9]], "g": 3},
	"ult_freeze": {"c": [["Block", 1.0], ["CastShoot", 1.2]], "p": [["crouch", 0.25, 0.8], ["spin", 1.0, 0.7, 0.8]], "g": 3},
	"ult_call": {"c": [["CastEnter", 0.8], ["CastIdle", 1.0, 1.1], ["CastShoot", 1.5]], "p": [["lean_back", 0.3, 1.2], ["shake", 0.05, 1.2], ["rise", 0.2, 1.2]], "g": 3},
	"ult_summon": {"c": [["ChestOpen", 1.0], ["CastShoot", 1.2]], "p": [["rise", 0.3, 1.2], ["shake", 0.07, 1.0]], "g": 3},
	"ult_orbit": {"c": [["CastEnter", 1.4], ["MeleeC", 1.0]], "p": [["spin", 2.0, 1.6], ["rise", 0.35, 1.6]], "g": 3},
	"ult_pour": {"c": [["Consume", 1.1], ["CastShoot", 1.4]], "p": [["lean_fwd", 0.3, 0.9], ["crouch", 0.15, 0.9]], "g": 3},
	"ult_roar": {"c": [["CastEnter", 1.2], ["EmoteYes", 1.5]], "p": [["lean_back", 0.35, 0.9], ["pulse", 0.15, 0.6, 0.5]], "g": 3},
	"ult_stasis": {"c": [["Block", 1.0], ["CastIdle", 1.0, 0.8], ["CastShoot", 1.5]], "p": [["pulse", 0.15, 1.0], ["rise", 0.1, 1.0]], "g": 3},
	"ult_slam": {"c": [["JumpStart", 1.4, 0.5], ["JumpLand", 1.4]], "p": [["hop", 0.9, 0.6], ["crouch", 0.35, 0.6, 0.45], ["shake", 0.1, 0.7, 0.5]], "g": 3},
	"ult_vanish": {"c": [["CastExit", 1.2], ["MeleeCombo", 1.5]], "p": [["shrink", 0.7, 0.5], ["spin", 2.0, 1.0, 0.5]], "g": 3},
}

# class -> skill id without the class prefix -> recipe
const SKILL := {
	"druid": {"vine_whip": "bolt_whip", "spore_cloud": "zone_sow", "thorn_skin": "buff_guard", "regrowth": "heal_pray", "wild_dash": "dash_lunge", "bloom": "heal_wave", "wild_bloom": "aoe_pulse",
		"forests_wrath": "ult_ascend", "thorn_volley": "bolt_volley", "leaf_storm": "aoe_spin", "wild_growth": "buff_flex", "stinging_swarm": "bolt_lob"},
	"sea_king": {"tidal_wave": "bolt_charge", "water_jet": "beam_channel", "bubble_shield": "buff_orb", "riptide": "dash_slide", "coral_spikes": "zone_slam", "healing_tide": "heal_touch",
		"maelstrom": "aoe_burst", "tsunami": "ult_wave", "trident_throw": "bolt_hurl", "ink_cloud": "zone_pour", "undertow": "beam_sweep", "pearl_barrier": "buff_drink"},
	"flame_lord": {"fireball": "bolt_charge", "flame_cone": "cone_breath", "fire_dash": "dash_lunge", "ember_shield": "buff_guard", "magma_pool": "zone_slam", "heat_wave": "aoe_pulse",
		"inferno_ring": "aoe_spin", "supernova": "ult_nova", "flame_wall": "wall_raise", "ember_barrage": "bolt_volley", "phoenix_rise": "heal_pray", "lava_whip": "bolt_whip"},
	"frost_mage": {"ice_shard": "bolt_quick", "frost_nova": "aoe_pulse", "ice_wall": "wall_raise", "blink": "teleport_blink", "blizzard": "zone_conjure", "glacial_armor": "buff_guard",
		"avalanche_strike": "aoe_slam", "absolute_zero": "ult_freeze", "ice_lance": "bolt_hurl", "frozen_ground": "zone_slam", "icicle_rain": "strikes_rain", "permafrost": "buff_flex"},
	"thunder_god": {"lightning_bolt": "beam_channel", "thunder_clap": "aoe_slam", "storm_dash": "dash_roll", "chain_lightning": "beam_two_hand", "static_field": "zone_conjure", "sky_hammer": "leap_slam",
		"thunderstorm": "aoe_burst", "wrath_of_the_heavens": "ult_call", "storm_call": "strikes_call", "overcharge": "buff_roar", "thunder_javelin": "bolt_hurl", "lightning_step": "teleport_step"},
	"necromancer": {"soul_bolt": "bolt_charge", "bone_spear": "beam_lunge", "raise_skeleton": "summon_raise", "death_coil": "bolt_two_hands", "wither": "beam_sweep", "grave_step": "teleport_vanish",
		"grave_eruption": "aoe_stomp", "army_of_the_dead": "ult_summon", "bone_armor": "buff_guard", "curse_of_decay": "zone_conjure", "soul_drain": "beam_two_hand", "bone_prison": "wall_raise"},
	"arcanist": {"arcane_missiles": "bolt_volley", "mana_shield": "buff_orb", "blink": "teleport_blink", "silence_ray": "beam_channel", "arcane_orb": "bolt_two_hands", "rune_trap": "trap_set",
		"arcane_explosion": "aoe_burst", "arcane_cataclysm": "ult_orbit", "mana_surge": "buff_drink", "prism_beam": "beam_two_hand", "gravity_rune": "trap_throw", "arcane_barrage": "bolt_orbit"},
	"poison_brewer": {"poison_flask": "bolt_lob", "toxic_gas": "zone_pour", "antidote": "heal_touch", "acid_spit": "beam_lunge", "sticky_brew": "zone_sow", "elixir": "buff_drink",
		"cauldron_burst": "aoe_stomp", "plague_cloud": "ult_pour", "plague_vial": "bolt_hurl", "bubbling_cauldron": "zone_slam", "panacea": "heal_wave", "caustic_mist": "cone_breath"},
	"pirate_captain": {"cannon_shot": "bolt_cannon", "grapple_dash": "dash_grapple", "flintlock_volley": "bolt_volley", "smoke_bomb": "trap_throw", "rum_heal": "buff_drink", "sabre_rush": "dash_lunge",
		"broadside": "aoe_stomp", "ghost_ship": "ult_roar", "powder_keg": "trap_set", "boarding_axe": "bolt_hurl", "parrot_scout": "summon_call", "anchor_slam": "leap_slam"},
	"time_mage": {"time_slow": "zone_conjure", "rewind": "teleport_rewind", "quicken": "buff_speed", "stasis_bolt": "bolt_two_hands", "temporal_echo": "dash_roll", "age": "beam_sweep",
		"chrono_burst": "aoe_pulse", "stop_time": "ult_stasis", "hourglass": "zone_slam", "time_skip": "teleport_step", "overclock": "buff_roar", "paradox_bolt": "bolt_orbit"},
	"celestial_mage": {"moon_beam": "beam_channel", "starfall": "strikes_rain", "lunar_shield": "buff_orb", "gravity_well": "zone_conjure", "phase_blink": "teleport_vanish", "blessing": "heal_pray",
		"eclipse_pulse": "aoe_pray", "moonfall": "ult_ascend", "crescent_slash": "cone_slash", "star_shower": "strikes_call", "moon_mend": "heal_wave", "night_veil": "buff_flex"},
	"gm_ravn": {"pawn_push": "bolt_quick", "knight_leap": "leap_up", "bishop_beam": "beam_lunge", "rook_charge": "dash_lunge", "queens_gambit": "cone_fast", "castling": "teleport_blink",
		"fork": "cone_heavy", "queen_sacrifice": "ult_slam", "en_passant": "dash_roll", "zugzwang": "zone_slam", "promotion": "buff_roar", "stalemate": "aoe_calm"},
	"desert_assassin": {"shadow_step": "teleport_step", "sand_veil": "buff_flex", "venom_blade": "buff_drink", "smoke_bomb": "aoe_calm", "dagger_fan": "bolt_volley", "mirage": "summon_decoy",
		"sand_dash": "dash_slide", "quick_slash": "cone_fast", "sirocco_gust": "cone_gust", "mark_for_death": "beam_lunge", "dust_devil_flurry": "aoe_spin", "vanishing_slaughter": "ult_vanish"},
}

const DEFAULT_BY_FX := {"projectile": "bolt_quick", "beam": "beam_channel", "cone": "cone_slash", "aoe": "aoe_burst", "zone": "zone_conjure", "sprint": "dash_lunge", "teleport": "teleport_blink",
	"leap": "leap_up", "buff": "buff_flex", "heal": "heal_pray", "summon": "summon_call", "wall": "wall_raise", "trap": "trap_set", "strikes": "strikes_call"}

# how each class carries itself while casting: extra poses and a speed factor on every clip
const FLAVOUR := {
	"druid": {"p": [["sway", 0.07, 0.8]], "s": 1.0}, "sea_king": {"p": [["sway", 0.1, 0.9]], "s": 0.95}, "flame_lord": {"p": [["pulse", 0.04, 0.5]], "s": 1.05},
	"frost_mage": {"p": [["rise", 0.07, 0.9]], "s": 0.95}, "thunder_god": {"p": [["shake", 0.025, 0.5]], "s": 1.1}, "necromancer": {"p": [["lean_back", 0.1, 0.7]], "s": 0.9},
	"arcanist": {"p": [["rise", 0.1, 0.8]], "s": 1.0}, "poison_brewer": {"p": [["crouch", 0.08, 0.6]], "s": 1.0}, "pirate_captain": {"p": [["tilt", 0.1, 0.6]], "s": 1.05},
	"time_mage": {"p": [["sway", 0.05, 1.0]], "s": 0.82}, "celestial_mage": {"p": [["rise", 0.12, 1.0]], "s": 0.92}, "gm_ravn": {"p": [["tilt", -0.06, 0.5]], "s": 1.0},
	"desert_assassin": {"p": [["crouch", 0.1, 0.5]], "s": 1.2},
}

# basic attacks by weapon family: a list the combo counter walks through
const WEAPON := {
	"sword": [{"c": [["MeleeA", 1.8]], "p": [["tilt", 0.12, 0.35], ["lunge", 0.1, 0.3]]}, {"c": [["MeleeB", 1.7]], "p": [["tilt", -0.12, 0.35], ["lunge", 0.1, 0.3]]}, {"c": [["Hook", 1.5]], "p": [["lunge", 0.3, 0.4]]}],
	"enchblade": [{"c": [["MeleeA", 1.8]], "p": [["tilt", 0.12, 0.35], ["lunge", 0.1, 0.3]], "g": 1}, {"c": [["MeleeB", 1.7]], "p": [["tilt", -0.12, 0.35]], "g": 1}, {"c": [["Hook", 1.5]], "p": [["lunge", 0.3, 0.4]], "g": 1}],
	"heavy": [{"c": [["Attack", 1.2]], "p": [["lean_back", 0.12, 0.25], ["lean_fwd", 0.3, 0.4, 0.22], ["crouch", 0.08, 0.4, 0.2]]}, {"c": [["MeleeC", 1.5]], "p": [["spin", 1.0, 0.8]]}],
	"axe": [{"c": [["MeleeB", 1.3]], "p": [["lean_fwd", 0.25, 0.45]]}, {"c": [["Attack", 1.4]], "p": [["lean_fwd", 0.2, 0.5]]}],
	"mace": [{"c": [["Attack", 1.4]], "p": [["hop", 0.1, 0.45], ["crouch", 0.1, 0.4, 0.2]]}, {"c": [["MeleeB", 1.3]], "p": [["lean_fwd", 0.3, 0.4]]}],
	"polearm": [{"c": [["Hook", 1.4]], "p": [["lunge", 0.4, 0.45]]}, {"c": [["Hook", 1.4]], "p": [["lunge", 0.4, 0.45]]}, {"c": [["MeleeC", 1.8]], "p": [["spin", 0.5, 0.7]]}],
	"scythe": [{"c": [["MeleeC", 1.5]], "p": [["spin", 0.3, 0.7], ["lean_fwd", 0.1, 0.6]]}, {"c": [["MeleeA", 1.4]], "p": [["tilt", 0.2, 0.5]]}],
	"dagger": [{"c": [["MeleeA", 2.4]], "p": [["lunge", 0.15, 0.25]]}, {"c": [["MeleeB", 2.4]], "p": [["lunge", 0.15, 0.25], ["tilt", 0.1, 0.25]]}],
	"claws": [{"c": [["MeleeA", 2.6]], "p": [["lean_fwd", 0.12, 0.25], ["tilt", 0.12, 0.25]]}, {"c": [["MeleeB", 2.6]], "p": [["lean_fwd", 0.12, 0.25], ["tilt", -0.12, 0.25]]}],
	"whip": [{"c": [["MeleeC", 1.9]], "p": [["tilt", 0.2, 0.5]]}, {"c": [["MeleeA", 1.6]], "p": [["tilt", -0.2, 0.4]]}],
	"gauntlet": [{"c": [["Hook", 1.6]], "p": [["lunge", 0.35, 0.4], ["pulse", 0.05, 0.3]], "g": 1}, {"c": [["MeleeB", 1.8]], "p": [["lunge", 0.25, 0.35]], "g": 1}],
	"bow": [{"c": [["CastEnter", 3.0], ["CastShoot", 2.2]], "p": [["recoil", 0.1, 0.4]]}],
	"spiritbow": [{"c": [["CastEnter", 3.0], ["CastShoot", 2.2]], "p": [["recoil", 0.1, 0.4]], "g": 1}],
	"crossbow": [{"c": [["CastShoot", 1.8]], "p": [["recoil", 0.18, 0.3]]}],
	"thrown": [{"c": [["Throw", 2.2]], "p": [["lean_fwd", 0.2, 0.45]]}, {"c": [["Throw", 2.4]], "p": [["tilt", 0.15, 0.4], ["lean_fwd", 0.15, 0.4]]}],
	"staff": [{"c": [["CastShoot", 1.9]], "p": [["rise", 0.04, 0.3]], "g": 1}, {"c": [["CastShoot", 1.7]], "p": [["lean_back", 0.06, 0.3]], "g": 1}],
	"wand": [{"c": [["Hook", 2.0]], "p": [["tilt", 0.12, 0.25]], "g": 1}, {"c": [["CastShoot", 2.2]], "p": [["tilt", -0.12, 0.25]], "g": 1}],
	"orb": [{"c": [["CastEnter", 2.0]], "p": [["pulse", 0.05, 0.35]], "g": 2}],
	"tome": [{"c": [["Consume", 2.4]], "p": [["lean_back", 0.08, 0.4]], "g": 1}, {"c": [["CastShoot", 1.8]], "p": [["recoil", 0.08, 0.3]], "g": 1}],
}


static func _scaled(poses: Array, mul: float) -> Array:
	var out: Array = []
	for p in poses:
		var q: Array = p.duplicate()
		if String(q[0]) != "spin":
			q[1] = float(q[1]) * mul
		out.append(q)
	return out


static func _speeds(clips: Array, mul: float) -> Array:
	var out: Array = []
	for c in clips:
		var q: Array = c.duplicate()
		q[1] = float(q[1]) * mul
		if q.size() > 2:
			q[2] = float(q[2]) / mul
		out.append(q)
	return out


## The body animation for a cast of `skill` by `c` (slot "ult" gets a bigger, slower version).
static func play_skill(c: Combatant, skill: Dictionary, slot: String) -> void:
	play_skill_on(c.model, c.class_id, skill, slot)


## The same for any model (the title screen heroes have no Combatant).
static func play_skill_on(m: CharacterModel, class_id: String, skill: Dictionary, slot: String) -> float:
	if m == null:
		return 0.0
	var cls := String(skill.get("class", ""))
	var id := String(skill.get("id", ""))
	var name: String = SKILL.get(cls, {}).get(id.trim_prefix(cls + "_"), "")
	if name == "" or not R.has(name):
		name = DEFAULT_BY_FX.get(String(skill.get("fx", {}).get("t", "")), "bolt_quick")
	var r: Dictionary = R[name]
	var fl: Dictionary = FLAVOUR.get(class_id, {"p": [], "s": 1.0})
	var jitter := 0.93 + 0.14 * float(absi(id.hash()) % 100) / 100.0     # every skill has its own small tempo
	var spd: float = float(fl["s"]) * jitter
	if slot == "ult" and not name.begins_with("ult_"):
		spd *= 0.85
	var poses: Array = _scaled(r["p"], 1.0 + (0.4 if slot == "ult" else 0.0))
	for p in fl["p"]:
		poses.append(p.duplicate())
	var col: Color = Data.color_of(skill.get("color", [1, 1, 1]))
	return m.play_recipe(_speeds(r["c"], spd), poses, col, int(r.get("g", 0)) if slot != "ult" else 3)


## The body animation for a basic attack with weapon `w`; `combo` walks through the family's list. `rate_mul` speeds fast weapons up.
static func play_weapon(c: Combatant, w: Dictionary, combo: int, rate_mul: float = 1.0) -> void:
	play_weapon_on(c.model, w, combo, rate_mul)


static func play_weapon_on(m: CharacterModel, w: Dictionary, combo: int, rate_mul: float = 1.0) -> float:
	if m == null:
		return 0.0
	var list: Array = WEAPON.get(String(w.get("family", "sword")), WEAPON["sword"])
	var r: Dictionary = list[combo % list.size()]
	var col := Weapons.color_for(w)
	var h := float(absi(String(w.get("id", "")).hash()) % 100) / 100.0
	var spd := clampf(rate_mul, 0.7, 1.7) * (0.95 + 0.1 * h)
	return m.play_recipe(_speeds(r["c"], spd), r["p"], col, int(r.get("g", 0)))
