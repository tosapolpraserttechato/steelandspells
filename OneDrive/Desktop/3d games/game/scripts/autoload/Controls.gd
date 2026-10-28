extends Node
## Registers all input actions in code (so the project file stays small).
## Keys: WASD move, Space jump, Shift sprint, Ctrl slide/crouch, mouse 1 attack, mouse 2 aim,
## Q/E/R skills, F signature skill, X ultimate, C class meter, G interact, Z potion, 1/2/3 pick cards,
## Tab hide/show the level-up cards, B scoreboard, I armory, Esc menu.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"slide": [KEY_CTRL],
	"skill_1": [KEY_Q],
	"skill_2": [KEY_E],
	"skill_3": [KEY_R],
	"skill_sig": [KEY_F],
	"ultimate": [KEY_X],
	"meter": [KEY_C],
	"interact": [KEY_G],
	"potion": [KEY_Z],
	"weapon_wheel": [KEY_H],
	"quest_skill": [KEY_V],
	"card_1": [KEY_1],
	"card_2": [KEY_2],
	"card_3": [KEY_3],
	"card_4": [KEY_4],
	"card_toggle": [KEY_TAB],
	"card_reroll": [KEY_T],
	"scoreboard": [KEY_B],
	"armory": [KEY_I],
	"menu": [KEY_ESCAPE],
	"skip": [KEY_SPACE],
}
const MOUSE := {"attack": [MOUSE_BUTTON_LEFT], "aim": [MOUSE_BUTTON_RIGHT]}


func _ready() -> void:
	for action in KEYS:
		_add(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for action in MOUSE:
		_add(action)
		for b in MOUSE[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = b
			InputMap.action_add_event(action, ev)


func _add(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
