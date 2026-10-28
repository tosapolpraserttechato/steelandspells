extends SceneTree
func _init() -> void:
	pass
func _process(_d: float) -> bool:
	var fx = get_root().get_node("Fx")
	var root := Node3D.new()
	get_root().add_child(root)
	var ids := ["burn","chill","freeze","poison","shock","stun","slow","root","bleed","weaken","vulnerable","silence","blind","haste","barrier","regen","empower","cleanse_shield","invisible","marked"]
	for id in ids:
		var n: Node3D = fx.status_effect(id)
		root.add_child(n)
	for k in ["poison","fire","frost","storm","heal","smoke","sand","bone","void","time","water","thorn"]:
		var z: Node3D = fx.zone(Vector3.ZERO, 5.0, k, 2.0)
	for k in ["bolt","arrow","dart","fire","ice","storm","leaf","bone","shadow"]:
		root.add_child(fx.projectile_visual(k, Color(1,0.5,0.2)))
	fx.impact(Vector3.ZERO, Color.RED, true)
	fx.ring(Vector3.ZERO, 3.0, Color.BLUE)
	fx.telegraph(Vector3.ZERO, 4.0, Color.RED, 1.0)
	fx.beam(Vector3.ZERO, Vector3(5,1,0), Color.CYAN)
	fx.lightning_strike(Vector3(2,0,2))
	fx.damage_number(Vector3.ZERO, 55, Color.WHITE, true)
	fx.level_up(root)
	root.add_child(fx.crate_beam("mythic"))
	fx.crate_burst(Vector3.ZERO, "legendary")
	for a in ["gold","flames","stars","void","embers","aurora","mist"]:
		root.add_child(fx.aura(a))
	for h in ["lava","steam","poison_water","quicksand","snow","embers","bubbles","spores","moon_dust","fog_wisp"]:
		root.add_child(fx.hazard(h, 4.0))
	fx.slash_trail(root, Color.WHITE)
	print("FX_TEST_OK")
	quit()
	return true
