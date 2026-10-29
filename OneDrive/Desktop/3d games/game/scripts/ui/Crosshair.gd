class_name Crosshair
extends Control
## The aiming cross in the middle of the screen (where the camera's aim ray goes). Four ticks and a dot with a dark outline, so it shows on snow as well as in a cave.
## The gap opens while you move, sprint or fire and closes while you aim; it turns red when the aim ray is on an enemy; a ring fills while a ranged weapon charges a sniper shot;
## a cross flashes when you hit (a red one for a kill). Hidden while dead or in a menu.

const OUTLINE := Color(0, 0, 0, 0.75)
const NORMAL := Color(1, 1, 1, 0.95)
const ENEMY := Color(1.0, 0.25, 0.2, 1.0)

var p: Player
var m: Match
var _gap := 7.0
var _kick := 0.0                         # a shot just went off: the gap jumps open
var _hit := 0.0                          # seconds left of the hit marker
var _kill := false
var _on_enemy := false
var _enemy_t := 0.0


func setup(player: Player, match_ref: Match) -> void:
	p = player
	m = match_ref
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.attacked.connect(func() -> void: _kick = 1.0)
	p.skill_used.connect(func(_s: String, _k: Dictionary) -> void: _kick = 1.0)
	p.dealt.connect(func(victim: Node, _a: float, _i: Dictionary) -> void:
		_hit = 0.22
		_kill = victim is Combatant and (victim as Combatant).health <= 0.0)


func _process(delta: float) -> void:
	if p == null or not is_instance_valid(p):
		return
	var moving := Vector2(p.velocity.x, p.velocity.z).length()
	var target := 8.0 + clampf(moving * 0.9, 0.0, 7.0) + _kick * 9.0
	if p.aiming:
		target = 4.0 + _kick * 5.0
	if not p.is_on_floor():
		target += 4.0
	_gap = lerpf(_gap, target, clampf(delta * 14.0, 0.0, 1.0))
	_kick = maxf(0.0, _kick - delta * 5.0)
	_hit = maxf(0.0, _hit - delta)
	_enemy_t -= delta
	if _enemy_t <= 0.0:
		_enemy_t = 0.06
		_on_enemy = _aim_on_enemy()
	queue_redraw()


## Is the point under the crosshair on (or right next to) a living enemy?
func _aim_on_enemy() -> bool:
	if m == null or p.dead:
		return false
	for e in m.enemies_of(p.team):
		if e.dead or not e.is_visible_to(p):
			continue
		if e.chest_position().distance_to(p.aim_point) < 1.1 * float(e.stats.value("size", 1.0)):
			return true
	return false


func _tick(c: Vector2, dir: Vector2, from: float, length: float, col: Color) -> void:
	draw_line(c + dir * (from - 1.3), c + dir * (from + length + 1.3), OUTLINE, 5.2)
	draw_line(c + dir * from, c + dir * (from + length), col, 2.6)


func _draw() -> void:
	if p == null or not is_instance_valid(p) or p.dead or p.ui_blocked or not bool(Settings.v.get("crosshair", true)):
		return
	var c := size * 0.5
	var col := ENEMY if _on_enemy else NORMAL
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_tick(c, d, _gap, 11.0, col)
	draw_circle(c, 3.0, OUTLINE)
	draw_circle(c, 1.7, col)
	# a sniper shot is charging: a ring closes around the cross
	if p.aiming and p.snipe_charge > 0.05:
		var f := clampf(p.snipe_charge / Player.SNIPE_READY, 0.0, 1.0)
		var r := _gap + 17.0
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * f, 40, OUTLINE, 5.0, true)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Color(1.0, 0.85, 0.35) if f < 1.0 else Color(1.0, 0.4, 0.3), 2.6, true)
	# hit marker: four short diagonal strokes
	if _hit > 0.0:
		var a := clampf(_hit / 0.22, 0.0, 1.0)
		var hc := (Color(1.0, 0.25, 0.2) if _kill else Color(1, 1, 1)) * Color(1, 1, 1, a)
		var g := 7.0 + (1.0 - a) * 5.0
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var n: Vector2 = d.normalized()
			draw_line(c + n * g, c + n * (g + 8.0), OUTLINE * Color(1, 1, 1, a), 4.6)
			draw_line(c + n * g, c + n * (g + 8.0), hc, 2.4)
