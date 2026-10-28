class_name Decor
extends RefCounted
## Scatters small decorations over a map when it loads: patches of flowers, grass, mushrooms, crystals, corals, shells, cacti, pebbles, gears...
## Every map has its own kinds and colours (SPECS). A patch picks one kind and two or three colours from the kind's palette, so a meadow is a mix of
## shades and no two patches look the same; every flower also gets its own size, lean and tint. The ground height comes from rays shot at the ground.

const CELL := 80.0
const VARIANTS := 4

const PAL := {
	"white": Color(0.97, 0.97, 0.94), "cream": Color(0.98, 0.92, 0.72), "yellow": Color(1.0, 0.84, 0.2), "gold": Color(0.95, 0.7, 0.15), "orange": Color(1.0, 0.52, 0.12),
	"red": Color(0.9, 0.14, 0.14), "pink": Color(1.0, 0.5, 0.7), "magenta": Color(0.85, 0.2, 0.65), "purple": Color(0.55, 0.28, 0.85), "violet": Color(0.7, 0.5, 0.95),
	"blue": Color(0.28, 0.48, 0.95), "sky": Color(0.55, 0.8, 1.0), "teal": Color(0.15, 0.8, 0.75), "green": Color(0.3, 0.72, 0.25), "lime": Color(0.68, 0.9, 0.2),
	"dkgreen": Color(0.16, 0.42, 0.18), "olive": Color(0.45, 0.5, 0.2), "brown": Color(0.5, 0.32, 0.18), "tan": Color(0.82, 0.7, 0.48), "grey": Color(0.56, 0.56, 0.6),
	"dark": Color(0.22, 0.22, 0.27), "ice": Color(0.75, 0.92, 1.0), "ember": Color(1.0, 0.38, 0.08), "obsidian": Color(0.3, 0.14, 0.42), "brass": Color(0.78, 0.55, 0.2),
	"iron": Color(0.42, 0.44, 0.5), "copper": Color(0.8, 0.42, 0.25), "moon": Color(0.82, 0.86, 1.0), "silver": Color(0.8, 0.84, 0.9), "cyan": Color(0.2, 0.9, 1.0),
	"amber": Color(1.0, 0.65, 0.1), "bark": Color(0.42, 0.28, 0.17), "moss": Color(0.3, 0.42, 0.2), "stone": Color(0.52, 0.52, 0.55), "snow": Color(0.96, 0.98, 1.0),
	"bone": Color(0.92, 0.88, 0.76), "sand": Color(0.86, 0.76, 0.5), "ash": Color(0.32, 0.29, 0.31),
	"granite": Color(0.5, 0.5, 0.53), "slate": Color(0.33, 0.36, 0.42), "basalt": Color(0.2, 0.2, 0.23), "sandstone": Color(0.66, 0.56, 0.44), "rust": Color(0.46, 0.38, 0.32),
	"pale": Color(0.72, 0.73, 0.77), "icerock": Color(0.6, 0.66, 0.72),
}
# stones are never bright orange or pure white: the palette names of a rock's patch are swapped for real rock colours
const ROCK_MAP := {"stone": "granite", "grey": "granite", "tan": "sandstone", "brown": "rust", "dark": "basalt", "iron": "slate", "white": "pale", "teal": "slate", "violet": "slate",
	"obsidian": "basalt", "ash": "basalt", "cream": "sandstone", "sand": "sandstone", "moon": "pale", "silver": "pale", "moss": "granite", "olive": "slate", "ice": "icerock",
	"sky": "slate", "bark": "rust", "copper": "rust"}

# kinds: k = DecorMesh kind, w = weight, pal = colour names, size = [lo, hi] scale, glow = emission strength (0 = none)
const SPECS := {
	"flora_forest": {"count": 4400, "kinds": [
		{"k": "daisy", "w": 3, "pal": ["white", "cream", "yellow", "pink"], "size": [1.1, 1.9]},
		{"k": "tulip", "w": 2.5, "pal": ["red", "pink", "orange", "yellow", "purple", "white"], "size": [1.2, 2.0]},
		{"k": "bell", "w": 2, "pal": ["blue", "violet", "sky", "pink", "white"], "size": [1.2, 2.0]},
		{"k": "star", "w": 2, "pal": ["yellow", "white", "orange", "magenta", "sky"], "size": [1.1, 1.9]},
		{"k": "poppy", "w": 1.5, "pal": ["red", "orange", "magenta", "yellow"], "size": [1.2, 1.9]},
		{"k": "puff", "w": 1.2, "pal": ["pink", "white", "violet", "blue"], "size": [1.2, 2.0]},
		{"k": "spike", "w": 1.6, "pal": ["purple", "violet", "pink", "blue", "white"], "size": [1.1, 1.8]},
		{"k": "tuft", "w": 3.5, "pal": ["green", "lime", "dkgreen", "olive"], "size": [1.2, 2.2]},
		{"k": "mushroom", "w": 1.6, "pal": ["red", "brown", "tan", "orange", "cream"], "size": [1.2, 2.2]},
	]},
	"toxic_swamp": {"count": 3800, "kinds": [
		{"k": "bell", "w": 2, "pal": ["lime", "teal", "magenta", "yellow"], "size": [1.2, 2.0], "glow": 0.9},
		{"k": "star", "w": 1.5, "pal": ["lime", "purple", "teal"], "size": [1.1, 1.8], "glow": 0.9},
		{"k": "reed", "w": 3, "pal": ["dkgreen", "olive", "brown", "green"], "size": [1.3, 2.4]},
		{"k": "tuft", "w": 3, "pal": ["dkgreen", "olive", "green"], "size": [1.2, 2.2]},
		{"k": "mushroom", "w": 3, "pal": ["lime", "teal", "orange", "purple", "magenta"], "size": [1.3, 2.4], "glow": 1.0},
		{"k": "mushroom_tall", "w": 1.5, "pal": ["lime", "teal", "magenta"], "size": [1.2, 2.0], "glow": 1.0},
		{"k": "pebbles", "w": 1, "pal": ["grey", "dark", "olive"], "size": [1.0, 2.0]},
	]},
	"underwater_ocean": {"count": 4600, "kinds": [
		{"k": "coral_fan", "w": 3, "pal": ["pink", "orange", "purple", "yellow", "red", "magenta"], "size": [1.4, 2.6]},
		{"k": "coral_branch", "w": 3, "pal": ["pink", "orange", "red", "white", "purple"], "size": [1.4, 2.6]},
		{"k": "seaweed", "w": 3.5, "pal": ["green", "lime", "olive", "teal"], "size": [1.3, 2.4]},
		{"k": "puff", "w": 2, "pal": ["magenta", "orange", "purple", "teal", "pink"], "size": [1.4, 2.4]},
		{"k": "starfish", "w": 1.6, "pal": ["orange", "red", "yellow", "pink", "purple"], "size": [1.5, 2.6]},
		{"k": "shell", "w": 2, "pal": ["white", "cream", "pink", "sky"], "size": [1.5, 2.6]},
		{"k": "pebbles", "w": 1.5, "pal": ["grey", "tan", "dark"], "size": [1.0, 2.0]},
		{"k": "crystals", "w": 0.6, "pal": ["sky", "teal", "violet"], "size": [1.2, 2.0], "glow": 0.8},
	]},
	"frozen_peaks": {"count": 3200, "kinds": [
		{"k": "star", "w": 2, "pal": ["ice", "white", "sky"], "size": [1.2, 2.0], "glow": 0.6},
		{"k": "tuft", "w": 3, "pal": ["white", "ice", "grey", "olive"], "size": [1.2, 2.2]},
		{"k": "crystals", "w": 2.2, "pal": ["ice", "sky", "blue", "white"], "size": [1.2, 2.2], "glow": 0.9},
		{"k": "puff", "w": 1.2, "pal": ["white", "ice", "red"], "size": [1.2, 2.0]},
		{"k": "pebbles", "w": 2, "pal": ["white", "ice", "grey"], "size": [1.0, 2.2]},
		{"k": "spike", "w": 1, "pal": ["ice", "blue", "white"], "size": [1.0, 1.8]},
	]},
	"volcano_forge": {"count": 3000, "kinds": [
		{"k": "poppy", "w": 2, "pal": ["ember", "orange", "red", "yellow"], "size": [1.2, 2.0], "glow": 1.4},
		{"k": "star", "w": 1.5, "pal": ["ember", "yellow", "orange"], "size": [1.1, 1.9], "glow": 1.4},
		{"k": "shard", "w": 3, "pal": ["obsidian", "dark", "purple"], "size": [1.2, 2.6]},
		{"k": "tuft", "w": 2, "pal": ["dark", "grey", "brown", "olive"], "size": [1.1, 2.0]},
		{"k": "pebbles", "w": 2, "pal": ["dark", "brown", "grey"], "size": [1.0, 2.2]},
		{"k": "crystals", "w": 1, "pal": ["ember", "red", "amber"], "size": [1.1, 2.0], "glow": 1.3},
	]},
	"desert_tomb": {"count": 2800, "kinds": [
		{"k": "cactus", "w": 3, "pal": ["green", "lime", "teal", "olive"], "size": [1.1, 2.2]},
		{"k": "tuft", "w": 3, "pal": ["tan", "brown", "cream", "olive"], "size": [1.2, 2.2]},
		{"k": "spike", "w": 1.5, "pal": ["tan", "purple", "sky", "cream"], "size": [1.1, 1.9]},
		{"k": "poppy", "w": 1, "pal": ["red", "orange", "yellow"], "size": [1.1, 1.8]},
		{"k": "pebbles", "w": 3, "pal": ["tan", "brown", "grey", "cream"], "size": [1.0, 2.2]},
		{"k": "shard", "w": 0.6, "pal": ["tan", "brown", "gold"], "size": [1.0, 1.8]},
	]},
	"sky_islands": {"count": 3200, "kinds": [
		{"k": "puff", "w": 2, "pal": ["white", "pink", "sky", "cream", "violet"], "size": [1.3, 2.2]},
		{"k": "bell", "w": 2, "pal": ["white", "sky", "violet", "pink"], "size": [1.2, 2.0]},
		{"k": "daisy", "w": 2, "pal": ["white", "yellow", "pink", "cream"], "size": [1.2, 2.0]},
		{"k": "tuft", "w": 3.5, "pal": ["lime", "green", "olive", "sky"], "size": [1.2, 2.2]},
		{"k": "star", "w": 1.5, "pal": ["yellow", "pink", "white", "sky"], "size": [1.1, 1.9]},
		{"k": "spike", "w": 1, "pal": ["sky", "violet", "white"], "size": [1.1, 1.8]},
	]},
	"shadow_crypt": {"count": 2600, "kinds": [
		{"k": "bell", "w": 2, "pal": ["moon", "ice", "violet"], "size": [1.2, 2.0], "glow": 1.0},
		{"k": "tuft", "w": 3, "pal": ["brown", "dark", "grey", "olive"], "size": [1.1, 2.0]},
		{"k": "mushroom", "w": 2, "pal": ["moon", "violet", "teal", "cream"], "size": [1.2, 2.2], "glow": 0.9},
		{"k": "spike", "w": 1.5, "pal": ["dark", "purple", "brown"], "size": [1.0, 1.8]},
		{"k": "pebbles", "w": 2, "pal": ["grey", "dark", "cream"], "size": [1.0, 2.2]},
		{"k": "shard", "w": 1, "pal": ["dark", "purple", "grey"], "size": [1.0, 2.0]},
	]},
	"crystal_caves": {"count": 3200, "kinds": [
		{"k": "crystals", "w": 4, "pal": ["cyan", "magenta", "violet", "lime", "orange", "blue", "pink"], "size": [1.2, 2.4], "glow": 1.4},
		{"k": "mushroom", "w": 3, "pal": ["teal", "magenta", "sky", "lime", "orange"], "size": [1.2, 2.2], "glow": 1.2},
		{"k": "mushroom_tall", "w": 1.5, "pal": ["sky", "violet", "magenta", "teal"], "size": [1.2, 2.0], "glow": 1.2},
		{"k": "star", "w": 1.5, "pal": ["sky", "pink", "lime", "cyan"], "size": [1.1, 1.8], "glow": 1.1},
		{"k": "pebbles", "w": 1, "pal": ["grey", "dark"], "size": [1.0, 2.0]},
	]},
	"clockwork_mines": {"count": 2600, "kinds": [
		{"k": "gear", "w": 3, "pal": ["brass", "iron", "gold", "copper"], "size": [0.9, 2.2]},
		{"k": "pebbles", "w": 3, "pal": ["dark", "grey", "brown"], "size": [1.0, 2.2]},
		{"k": "crystals", "w": 1.2, "pal": ["amber", "orange", "ember"], "size": [1.1, 2.0], "glow": 1.1},
		{"k": "mushroom", "w": 1.2, "pal": ["tan", "cream", "brown"], "size": [1.1, 2.0]},
		{"k": "shard", "w": 1, "pal": ["iron", "brass", "dark"], "size": [1.0, 1.8]},
	]},
	"moon_sanctuary": {"count": 3400, "kinds": [
		{"k": "bell", "w": 3, "pal": ["moon", "ice", "violet", "silver"], "size": [1.2, 2.0], "glow": 1.0},
		{"k": "star", "w": 2, "pal": ["moon", "sky", "white", "violet"], "size": [1.1, 1.9], "glow": 1.0},
		{"k": "puff", "w": 1.5, "pal": ["white", "moon", "violet"], "size": [1.2, 2.0], "glow": 0.5},
		{"k": "tuft", "w": 3, "pal": ["silver", "ice", "moon", "olive"], "size": [1.2, 2.2]},
		{"k": "spike", "w": 1.5, "pal": ["violet", "sky", "moon"], "size": [1.1, 1.9], "glow": 0.9},
		{"k": "crystals", "w": 1, "pal": ["moon", "sky", "violet"], "size": [1.1, 2.0], "glow": 1.2},
	]},
	"pirate_cove": {"count": 3000, "kinds": [
		{"k": "tuft", "w": 3, "pal": ["lime", "tan", "green", "olive"], "size": [1.2, 2.2]},
		{"k": "poppy", "w": 2, "pal": ["red", "pink", "yellow", "orange"], "size": [1.3, 2.1]},
		{"k": "shell", "w": 3, "pal": ["white", "cream", "pink", "sky"], "size": [1.4, 2.4]},
		{"k": "starfish", "w": 2, "pal": ["orange", "red", "pink", "yellow"], "size": [1.4, 2.4]},
		{"k": "pebbles", "w": 2, "pal": ["tan", "grey", "white", "brown"], "size": [1.0, 2.2]},
		{"k": "star", "w": 1, "pal": ["yellow", "white", "pink"], "size": [1.1, 1.8]},
		{"k": "spike", "w": 1, "pal": ["purple", "pink", "sky"], "size": [1.0, 1.8]},
	]},
}

# bigger things that go with the plants: rocks, bushes, stumps, logs, bones, mounds, ferns, graves, glowing pods and giant blooms
const EXTRA := {
	"flora_forest": [
		{"k": "bush", "w": 2.5, "pal": ["green", "dkgreen", "olive", "lime"], "size": [1.3, 2.4]},
		{"k": "fern", "w": 3, "pal": ["green", "lime", "dkgreen", "teal", "olive"], "size": [1.5, 2.8]},
		{"k": "rock", "w": 0.8, "pal": ["stone", "grey", "brown", "tan"], "size": [1.2, 2.4]},
		{"k": "rock_mossy", "w": 1.8, "pal": ["stone", "grey", "brown", "iron"], "size": [1.2, 2.4]},
		{"k": "boulder_mossy", "w": 0.5, "pal": ["stone", "grey", "brown"], "size": [1.2, 2.5]},
		{"k": "stump", "w": 1, "pal": ["bark", "brown", "tan"], "size": [1.2, 2.2]},
		{"k": "log", "w": 0.8, "pal": ["bark", "brown", "moss"], "size": [1.2, 2.2]},
		{"k": "daisy", "w": 0.5, "pal": ["white", "yellow", "pink", "cream"], "size": [4.0, 7.0]},
		{"k": "tulip", "w": 0.5, "pal": ["red", "pink", "orange", "purple", "yellow"], "size": [4.0, 7.0]},
		{"k": "bell", "w": 0.5, "pal": ["blue", "violet", "pink", "sky"], "size": [4.0, 7.0]},
		{"k": "poppy", "w": 0.4, "pal": ["red", "orange", "magenta", "yellow"], "size": [4.0, 6.5]},
	],
	"toxic_swamp": [
		{"k": "fern", "w": 2.5, "pal": ["dkgreen", "olive", "lime", "teal"], "size": [1.5, 2.8]},
		{"k": "pod", "w": 2, "pal": ["lime", "teal", "magenta", "purple"], "size": [1.4, 2.4], "glow": 1.0},
		{"k": "bush", "w": 1.5, "pal": ["dkgreen", "olive", "purple", "brown"], "size": [1.3, 2.3]},
		{"k": "log", "w": 1.2, "pal": ["bark", "dark", "moss"], "size": [1.2, 2.2]},
		{"k": "stump", "w": 1.2, "pal": ["bark", "dark", "moss"], "size": [1.2, 2.2]},
		{"k": "rock_mossy", "w": 1.6, "pal": ["dark", "olive", "stone", "bark"], "size": [1.2, 2.2]},
		{"k": "boulder_mossy", "w": 0.5, "pal": ["dark", "olive", "stone"], "size": [1.2, 2.5]},
		{"k": "bones", "w": 0.5, "pal": ["bone"], "size": [1.3, 2.0]},
	],
	"underwater_ocean": [
		{"k": "rock", "w": 2, "pal": ["stone", "tan", "dark", "teal", "moss"], "size": [1.2, 2.6]},
		{"k": "boulder", "w": 0.6, "pal": ["stone", "grey", "teal"], "size": [1.2, 2.5]},
		{"k": "mound", "w": 1.5, "pal": ["sand", "tan", "cream"], "size": [1.2, 2.4]},
		{"k": "bones", "w": 0.7, "pal": ["bone"], "size": [1.3, 2.2]},
		{"k": "coral_branch", "w": 0.7, "pal": ["pink", "orange", "purple", "red", "teal"], "size": [3.0, 5.0]},
		{"k": "coral_fan", "w": 0.6, "pal": ["pink", "purple", "orange", "yellow"], "size": [3.0, 5.0]},
		{"k": "pod", "w": 0.8, "pal": ["teal", "sky", "magenta", "lime"], "size": [1.4, 2.4], "glow": 0.8},
	],
	"frozen_peaks": [
		{"k": "rock", "w": 1.0, "pal": ["stone", "grey", "ice"], "size": [1.2, 2.6]},
		{"k": "rock_snowy", "w": 2.4, "pal": ["stone", "grey", "iron", "ice"], "size": [1.2, 2.6]},
		{"k": "boulder_snowy", "w": 0.9, "pal": ["stone", "grey", "iron"], "size": [1.2, 2.5]},
		{"k": "mound", "w": 2.5, "pal": ["snow", "white", "ice"], "size": [1.4, 2.8]},
		{"k": "bush", "w": 1, "pal": ["dkgreen", "olive", "white", "grey"], "size": [1.2, 2.0]},
		{"k": "stump", "w": 0.6, "pal": ["bark", "dark", "grey"], "size": [1.2, 2.0]},
		{"k": "log", "w": 0.5, "pal": ["bark", "dark", "grey"], "size": [1.2, 2.0]},
		{"k": "bones", "w": 0.4, "pal": ["bone"], "size": [1.3, 2.0]},
	],
	"volcano_forge": [
		{"k": "rock", "w": 3, "pal": ["dark", "obsidian", "brown", "ash", "iron"], "size": [1.2, 2.6]},
		{"k": "boulder", "w": 1, "pal": ["dark", "obsidian", "ash", "iron"], "size": [1.2, 2.5]},
		{"k": "mound", "w": 1.5, "pal": ["ash", "dark", "brown"], "size": [1.2, 2.4]},
		{"k": "bones", "w": 0.7, "pal": ["bone", "tan"], "size": [1.3, 2.2]},
		{"k": "stump", "w": 0.8, "pal": ["dark", "ash"], "size": [1.2, 2.0]},
		{"k": "log", "w": 0.6, "pal": ["dark", "ash"], "size": [1.2, 2.0]},
		{"k": "pod", "w": 0.7, "pal": ["ember", "orange", "red"], "size": [1.3, 2.2], "glow": 1.4},
	],
	"desert_tomb": [
		{"k": "rock", "w": 2.5, "pal": ["tan", "brown", "cream", "sand", "stone"], "size": [1.2, 2.6]},
		{"k": "boulder", "w": 0.9, "pal": ["tan", "brown", "sand"], "size": [1.2, 2.5]},
		{"k": "bones", "w": 1.2, "pal": ["bone"], "size": [1.3, 2.4]},
		{"k": "mound", "w": 2, "pal": ["sand", "tan", "cream"], "size": [1.4, 2.8]},
		{"k": "bush", "w": 1.5, "pal": ["olive", "brown", "tan", "dkgreen"], "size": [1.2, 2.2]},
		{"k": "stump", "w": 0.5, "pal": ["bark", "tan", "grey"], "size": [1.1, 1.9]},
		{"k": "grave", "w": 0.5, "pal": ["tan", "sand", "stone"], "size": [1.3, 2.2]},
	],
	"sky_islands": [
		{"k": "rock", "w": 1.5, "pal": ["white", "stone", "grey", "sky", "moon"], "size": [1.2, 2.4]},
		{"k": "bush", "w": 2, "pal": ["lime", "green", "dkgreen", "olive"], "size": [1.3, 2.3]},
		{"k": "fern", "w": 2, "pal": ["lime", "green", "teal", "sky"], "size": [1.5, 2.6]},
		{"k": "mound", "w": 1, "pal": ["white", "cream", "snow"], "size": [1.2, 2.4]},
		{"k": "stump", "w": 0.5, "pal": ["bark", "tan", "brown"], "size": [1.2, 2.0]},
		{"k": "log", "w": 0.4, "pal": ["bark", "tan", "brown"], "size": [1.2, 2.0]},
	],
	"shadow_crypt": [
		{"k": "grave", "w": 4, "pal": ["stone", "grey", "moon", "moss", "dark"], "size": [1.4, 2.4]},
		{"k": "bones", "w": 1.5, "pal": ["bone"], "size": [1.3, 2.4]},
		{"k": "stump", "w": 1.2, "pal": ["dark", "bark", "grey"], "size": [1.2, 2.2]},
		{"k": "log", "w": 1, "pal": ["dark", "bark", "grey"], "size": [1.2, 2.2]},
		{"k": "rock", "w": 0.8, "pal": ["dark", "stone", "grey"], "size": [1.2, 2.4]},
		{"k": "rock_mossy", "w": 1.2, "pal": ["dark", "stone", "grey", "iron"], "size": [1.2, 2.4]},
		{"k": "bush", "w": 1.2, "pal": ["dark", "olive", "purple", "brown"], "size": [1.2, 2.2]},
		{"k": "mound", "w": 1.5, "pal": ["brown", "dark", "bark"], "size": [1.2, 2.4]},
		{"k": "pod", "w": 0.8, "pal": ["moon", "teal", "violet"], "size": [1.3, 2.2], "glow": 1.0},
	],
	"crystal_caves": [
		{"k": "rock", "w": 3, "pal": ["dark", "stone", "obsidian", "iron", "violet"], "size": [1.2, 2.6]},
		{"k": "boulder", "w": 1, "pal": ["dark", "stone", "obsidian"], "size": [1.2, 2.5]},
		{"k": "pod", "w": 2.5, "pal": ["cyan", "magenta", "lime", "violet", "orange"], "size": [1.4, 2.4], "glow": 1.3},
		{"k": "fern", "w": 1.5, "pal": ["teal", "sky", "lime", "magenta"], "size": [1.4, 2.4], "glow": 0.7},
		{"k": "mound", "w": 1, "pal": ["dark", "stone", "obsidian"], "size": [1.2, 2.2]},
		{"k": "bones", "w": 0.4, "pal": ["bone"], "size": [1.3, 2.0]},
	],
	"clockwork_mines": [
		{"k": "rock", "w": 3, "pal": ["dark", "iron", "brown", "stone", "copper"], "size": [1.2, 2.6]},
		{"k": "boulder", "w": 1, "pal": ["iron", "dark", "copper", "stone"], "size": [1.2, 2.5]},
		{"k": "mound", "w": 1.5, "pal": ["dark", "ash", "brown"], "size": [1.2, 2.4]},
		{"k": "log", "w": 1, "pal": ["bark", "brown", "dark"], "size": [1.2, 2.2]},
		{"k": "stump", "w": 0.6, "pal": ["bark", "brown", "dark"], "size": [1.2, 2.0]},
		{"k": "bones", "w": 0.4, "pal": ["bone"], "size": [1.3, 2.0]},
	],
	"moon_sanctuary": [
		{"k": "rock", "w": 2, "pal": ["moon", "silver", "white", "stone"], "size": [1.2, 2.4]},
		{"k": "mound", "w": 1.5, "pal": ["white", "moon", "silver"], "size": [1.2, 2.4]},
		{"k": "bush", "w": 1.8, "pal": ["moon", "silver", "violet", "olive", "dkgreen"], "size": [1.2, 2.2]},
		{"k": "fern", "w": 2, "pal": ["silver", "moon", "teal", "violet"], "size": [1.4, 2.5], "glow": 0.5},
		{"k": "pod", "w": 1.2, "pal": ["moon", "sky", "violet"], "size": [1.3, 2.3], "glow": 1.1},
	],
	"pirate_cove": [
		{"k": "rock", "w": 2, "pal": ["tan", "grey", "brown", "stone", "sand"], "size": [1.2, 2.6]},
		{"k": "boulder", "w": 0.7, "pal": ["tan", "stone", "brown"], "size": [1.2, 2.5]},
		{"k": "log", "w": 1.5, "pal": ["tan", "grey", "bark", "brown"], "size": [1.2, 2.4]},
		{"k": "stump", "w": 0.6, "pal": ["bark", "tan", "grey"], "size": [1.2, 2.0]},
		{"k": "bush", "w": 1.8, "pal": ["green", "lime", "olive", "dkgreen"], "size": [1.3, 2.3]},
		{"k": "fern", "w": 2, "pal": ["lime", "green", "dkgreen"], "size": [1.6, 3.0]},
		{"k": "mound", "w": 1.5, "pal": ["sand", "tan", "cream"], "size": [1.2, 2.4]},
		{"k": "bones", "w": 0.7, "pal": ["bone"], "size": [1.3, 2.2]},
	],
}

# the meshes (kind + shape number) and materials (by glow strength) are made once and shared by every patch
static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}


static func _mesh(kind: String, v: int) -> ArrayMesh:
	var key := "%s%d" % [kind, v]
	if not _meshes.has(key):
		_meshes[key] = DecorMesh.make(kind, v + 1)
	return _meshes[key]


static func _material(glow: float) -> ShaderMaterial:
	var key := snappedf(glow, 0.1)
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/decor.gdshader")
		m.set_shader_parameter("glow", glow)
		_mats[key] = m
	return _mats[key]


## Scatters the decorations of `map_id` under `map_root`. Needs the map's collision bodies, so it waits two physics frames first.
static func scatter(host: Node3D, map_id: String, map_root: Node3D, map_size: Vector2) -> void:
	if not SPECS.has(map_id):
		return
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	if not is_instance_valid(host) or not is_instance_valid(map_root):
		return
	var spec: Dictionary = SPECS[map_id]
	var space := host.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = map_id.hash()
	var half := map_size * 0.5 - Vector2(5, 5)
	var path_cells: Dictionary = map_root.get_meta("path_cells", {})
	var kinds: Array = (spec["kinds"] as Array) + (EXTRA.get(map_id, []) as Array)
	var total_w := 0.0
	for k in kinds:
		total_w += float(k["w"])
	var count: int = int(float(spec["count"]) * [0.35, 0.7, 1.0][Settings.quality()])
	var groups: Dictionary = {}
	var placed := 0
	var tries := 0
	var dbg_done := false
	var cluster_total := int(count * 0.85)
	while placed < count and tries < count * 3:
		# a patch: one kind, two or three colours from its palette, one size factor
		var pick := rng.randf() * total_w
		var kd: Dictionary = kinds[0]
		for k in kinds:
			pick -= float(k["w"])
			if pick <= 0.0:
				kd = k
				break
		var pal: Array = kd["pal"].duplicate()
		pal.shuffle()
		var cols: Array = pal.slice(0, mini(pal.size(), rng.randi_range(2, 3)))
		var centre := Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
		var is_patch: bool = placed < cluster_total
		var n := rng.randi_range(8, 24) if is_patch else 1
		var radius := rng.randf_range(2.0, 6.5)
		var patch_scale := rng.randf_range(0.8, 1.3)
		var vlist: Array = []
		for i in 2:
			vlist.append(rng.randi() % VARIANTS)
		for i in n:
			tries += 1
			var p := centre
			if is_patch:
				p += Vector2(rng.randfn(0.0, radius * 0.5), rng.randfn(0.0, radius * 0.5))
			if absf(p.x) > half.x or absf(p.y) > half.y:
				continue
			if path_cells.has(Vector2i(floori(p.x), floori(p.y))):
				continue
			var hit := _ground(space, p)
			if hit.is_empty():
				continue
			var s := rng.randf_range(float(kd["size"][0]), float(kd["size"][1])) * patch_scale
			var yaw := rng.randf() * TAU
			var up: Vector3 = (hit["normal"] as Vector3).lerp(Vector3.UP, 0.6).normalized()
			var basis := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, yaw)
			var tilt_axis := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
			basis = Basis(tilt_axis, rng.randf_range(0.0, 0.14)) * basis
			basis = basis.scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
			var xf := Transform3D(basis, (hit["position"] as Vector3) - Vector3(0, 0.01, 0))
			var pal_name: String = cols[rng.randi() % cols.size()]
			if String(kd["k"]).begins_with("rock") or String(kd["k"]).begins_with("boulder"):
				pal_name = ROCK_MAP.get(pal_name, pal_name)
			var base_col: Color = PAL[pal_name]
			var hsv_h := base_col.h + rng.randf_range(-0.025, 0.025)
			var col := Color.from_hsv(fposmod(hsv_h, 1.0), clampf(base_col.s * rng.randf_range(0.85, 1.12), 0.0, 1.0), clampf(base_col.v * rng.randf_range(0.85, 1.1), 0.0, 1.0))
			col = col.srgb_to_linear()
			var v: int = vlist[rng.randi() % vlist.size()] if rng.randf() < 0.7 else rng.randi() % VARIANTS
			if OS.get_environment("CRITTER_DEBUG") != "" and String(kd["k"]).begins_with("boulder") and not dbg_done:
				dbg_done = true
				print("DECOR_AT ", kd["k"], " ", (hit["position"] as Vector3).snapped(Vector3(0.1, 0.1, 0.1)))
			var gk := "%s|%d|%d|%d|%.1f" % [kd["k"], v, int(floor((hit["position"] as Vector3).x / CELL)), int(floor((hit["position"] as Vector3).z / CELL)), float(kd.get("glow", 0.0))]
			if not groups.has(gk):
				groups[gk] = {"k": kd["k"], "v": v, "glow": float(kd.get("glow", 0.0)), "xf": [], "col": []}
			groups[gk]["xf"].append(xf)
			groups[gk]["col"].append(Color(col.r, col.g, col.b, rng.randf()))
			placed += 1
	var holder := Node3D.new()
	holder.name = "Decor"
	map_root.add_child(holder)
	for gk in groups:
		var g: Dictionary = groups[gk]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true                       # the engine reads the custom data from after the colour, so both must be on
		mm.use_custom_data = true
		mm.mesh = _mesh(String(g["k"]), int(g["v"]))
		mm.instance_count = g["xf"].size()
		for i in g["xf"].size():
			mm.set_instance_transform(i, g["xf"][i])
			mm.set_instance_color(i, Color.WHITE)
			mm.set_instance_custom_data(i, g["col"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _material(float(g["glow"]))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = [55.0, 70.0, 85.0][Settings.quality()]
		holder.add_child(mmi)
	print("DECOR ", map_id, " placed ", placed, " in ", groups.size(), " groups")


## The ground under (x, z): {position, normal}, or {} where there is none (a wall, a prop, water, steep ground).
static func _ground(space: PhysicsDirectSpaceState3D, p: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 150.0, p.y), Vector3(p.x, -60.0, p.y), 1)
	var r := space.intersect_ray(q)
	if r.is_empty():
		return {}
	var col: Object = r["collider"]
	if not (col is Node) or not (col as Node).has_meta("ground"):
		return {}
	if (r["normal"] as Vector3).y < 0.82:
		return {}
	return r
