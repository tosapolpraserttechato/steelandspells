class_name NpcNode
extends Node3D
## A neutral NPC spot from the map's npc markers. Mission NPCs (npc_type "mission") are always there: they give a mission for XP and a full heal.
## The quest NPC (npc_type "quest_skill") shows up only some of the time and offers a quest for a quest skill.

var npc_type := "mission"
var marker_name := ""
var available := true
var match_ref: Match = null
var _mark: Sprite3D
var _t := 0.0
var _roll_timer := 0.0
var current_quest_skill := ""


func setup(marker: Dictionary, ref: Match) -> void:
	match_ref = ref
	npc_type = String(marker.get("npc_type", "mission"))
	marker_name = String(marker["name"])
	position = marker["pos"]
	_mark = Sprite3D.new()
	_mark.texture = Fx.TEX["star"]
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.modulate = Color(1.0, 0.85, 0.3) if npc_type == "mission" else Color(0.7, 0.5, 1.0)
	_mark.pixel_size = 0.018
	_mark.shaded = false
	_mark.transparent = true
	_mark.position = Vector3(0, 3.1, 0)
	add_child(_mark)
	add_child(Fx.particles({"tex": "star", "amount": 6, "life": 1.4, "shape": "sphere", "radius": 0.5, "dir": Vector3.UP, "spread": 5, "vel": [0.3, 0.7], "size": [0.1, 0.2],
		"colors": [Color(1, 0.9, 0.4, 0), Color(1, 0.9, 0.4, 0.9), Color(1, 0.9, 0.4, 0)]}))
	if npc_type == "quest_skill":
		_reroll_presence()


func _reroll_presence() -> void:
	# the quest NPC appears only some of the time: pick a skill, appear with that skill's chance
	var pool: Array = []
	for q in Data.quest_skills:
		if q["id"] != Game.quest_skill:
			pool.append(q)
	if pool.is_empty():
		available = false
	else:
		var q: Dictionary = pool[randi() % pool.size()]
		current_quest_skill = String(q["id"])
		available = randf() * 100.0 < float(q["npc_appear_chance_percent"])
	_roll_timer = 75.0
	visible = available


func _process(delta: float) -> void:
	_t += delta
	if _mark != null:
		_mark.position.y = 3.1 + sin(_t * 2.5) * 0.15
	if npc_type == "quest_skill":
		_roll_timer -= delta
		if _roll_timer <= 0.0 and not (match_ref != null and match_ref.quests.is_busy()):
			_reroll_presence()


func can_interact(_p: Node) -> bool:
	return available and not (match_ref != null and match_ref.quests.is_busy())


func prompt_text() -> String:
	if npc_type == "mission":
		return "Press G to talk: mission for XP and a full heal"
	return "Press G to talk to the wandering sage (quest skill)"


func interact(player: Node) -> void:
	if npc_type == "mission":
		match_ref.quests.offer_mission(self)
	else:
		match_ref.quests.offer_quest(self, current_quest_skill)
