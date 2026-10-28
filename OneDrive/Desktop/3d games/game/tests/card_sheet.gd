extends Control
## Cards of every rarity, a crate result card and inventory slots: godot --path game --resolution 1280x720 res://tests/card_sheet.tscn
var _t := 0.0

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.16)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	var picks := [["sharp_eyes", "common"], ["iron_skin", "uncommon"], ["swift_feet", "rare"], ["arcane_surge", "epic"], ["vampiric_touch", "legendary"], ["fate_weaver", "mythic"]]
	var x := 12.0
	var shown := 0
	for pr in picks:
		var card: Dictionary = Data.card_by_id.get(pr[0], {})
		if card.is_empty():
			card = Data.cards[shown * 17 % Data.cards.size()]
		var w := RarityFrame.new()
		w.size = Vector2(200, 300)
		w.position = Vector2(x, 12)
		var st := 1 + shown
		w.set_data(pr[1], String(card["name"]), String(card["category"]).capitalize(), String(card["effect_by_stack"][mini(st, 6) - 1]), "New card" if st == 1 else "Upgrade: stack %d of 6" % st)
		w.set_art(IconArt.glyph_for_card(card), String(card["category"]))
		w.hotkey = str(shown + 1)
		w.badge = "Stack %d/6" % st if st > 1 else ""
		add_child(w)
		x += 212.0
		shown += 1
	# crate result
	var item := {"kind": "weapon", "id": "longsword", "rarity": "epic"}
	var wc := RarityFrame.new()
	wc.size = Vector2(420, 235)
	wc.position = Vector2(12, 330)
	wc.set_data("legendary", "Phoenix Bow", "Brand new", "+12% damage\nBurns enemies on hit\nFires flaming arrows", "")
	wc.set_art("bow", "offense")
	add_child(wc)
	# inventory slots
	var slots := [["sword", "offense", "rare", "Longsword", "Weapon"], ["crown", "defense", "epic", "Helm of the Ember King", "Helmet | new"], ["shield", "defense", "common", "Wooden Shield", "Shield"],
		["boot", "defense", "legendary", "Frostwalkers", "Boots"], ["rune", "skill", "mythic", "Rune of Ruin", "Rune"], ["staff", "offense", "uncommon", "Ash Staff", "Weapon"]]
	var i := 0
	for s in slots:
		var w := RarityFrame.new()
		w.compact = true
		w.size = Vector2(184, 84)
		w.position = Vector2(450 + (i % 2) * 196, 330 + (i / 2) * 94)
		w.set_data(s[2], s[3], s[4], "")
		w.set_art(s[0], s[1])
		add_child(w)
		i += 1
	# skill row
	var ids := ["flame_lord_fireball", "frost_mage_frost_nova", "thunder_god_chain_lightning", "necromancer_raise_skeleton", "pirate_captain_broadside"]
	var j := 0
	for id in ids:
		var b := UiKit.SkillSlot.new()
		b.size = Vector2(70, 70)
		b.position = Vector2(870 + j * 80, 340)
		b.set_skill(Data.skills[id])
		b.letter = ["Q", "E", "R", "F", "X"][j]
		b.special = (j == 3)
		b.ult = (j == 4)
		b.ready_glow = true
		add_child(b)
		j += 1

func _process(delta: float) -> void:
	_t += delta
	if _t > 1.5:
		get_viewport().get_texture().get_image().save_png("res://shots/card_sheet.png")
		get_tree().quit()
