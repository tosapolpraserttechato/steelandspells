extends Node
## Sounds made in code: short effects (menu clicks, spells, swings, hits, chimes...) and a slow ambient music loop. Nothing is loaded from a file.
## Effects play on the "SFX" bus and the music on "Music", so the volume sliders in the settings work. `at()` plays a sound in the world: quieter the farther it is from the camera.

const RATE := 22050
const MUSIC_RATE := 11025

var _bank: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _thread: Thread
var _music_data: PackedByteArray


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_bank()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -4.0
	add_child(_music)
	_thread = Thread.new()
	_thread.start(_make_music)
	Game.cards_offered.connect(func(_o: Array) -> void: play("chime"))


func _process(_delta: float) -> void:
	if _thread != null and not _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = MUSIC_RATE
		w.stereo = false
		w.data = _music_data
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = _music_data.size() / 2
		_music.stream = w
		_music.play()


## Plays a sound without a place (menus, your own spells).
func play(name: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if not _bank.has(name) or _pool.is_empty():
		return
	var p := _pool[_next]
	for i in _pool.size():
		var cand := _pool[(_next + i) % _pool.size()]
		if not cand.playing:
			p = cand
			break
	_next = (_next + 1) % _pool.size()
	p.stream = _bank[name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## Plays a sound in the world: quieter with distance from the camera, silent far away.
func at(name: String, pos: Vector3, db: float = 0.0, pitch: float = 1.0) -> void:
	var cam := get_viewport().get_camera_3d()
	var d := 0.0
	if cam != null:
		d = cam.global_position.distance_to(pos)
	if d > 55.0:
		return
	play(name, db - d * 0.5, pitch)


# ----------------------------------------------------------------- the sounds

func _make(duration: float, fn: Callable, rate: int = RATE) -> AudioStreamWAV:
	var n := int(duration * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var s := clampf(float(fn.call(float(i) / rate, float(i) / n)), -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _build_bank() -> void:
	_bank["click"] = _make(0.07, func(t: float, _u: float) -> float: return sin(TAU * 1400.0 * t) * exp(-t * 60.0) * 0.5)
	_bank["hover"] = _make(0.04, func(t: float, _u: float) -> float: return sin(TAU * 2000.0 * t) * exp(-t * 90.0) * 0.22)
	_bank["chime"] = _make(0.7, func(t: float, _u: float) -> float:
		return (sin(TAU * 880.0 * t) + 0.6 * sin(TAU * 1320.0 * t) + 0.3 * sin(TAU * 1760.0 * t)) * exp(-t * 5.0) * 0.32)
	_bank["open"] = _make(0.25, func(t: float, u: float) -> float: return sin(TAU * (600.0 + 300.0 * u) * t) * sin(PI * u) * 0.35)
	_bank["cast"] = _make(0.45, func(t: float, u: float) -> float:
		return (_noise() * 0.18 + sin(TAU * (260.0 + 640.0 * u) * t) * 0.3 + sin(TAU * (520.0 + 1280.0 * u) * t) * 0.12) * sin(PI * u) * (1.0 - u * 0.3))
	var lp := {"y": 0.0}
	_bank["swing"] = _make(0.22, func(_t: float, u: float) -> float:
		lp["y"] = float(lp["y"]) + (_noise() - float(lp["y"])) * 0.35
		return float(lp["y"]) * sin(PI * pow(u, 0.6)) * (1.0 - u) * 0.9)
	_bank["hit"] = _make(0.22, func(t: float, u: float) -> float:
		return sin(TAU * (120.0 - 70.0 * u) * t) * exp(-t * 14.0) * 0.8 + _noise() * exp(-t * 70.0) * 0.45)
	_bank["hurt"] = _make(0.26, func(t: float, u: float) -> float:
		return (fmod(t * 240.0 * (1.0 - 0.45 * u), 1.0) * 2.0 - 1.0) * exp(-t * 9.0) * 0.4)
	_bank["zap"] = _make(0.22, func(t: float, u: float) -> float:
		return sin(TAU * (1500.0 * pow(1.0 - u, 2.0) + 220.0) * t) * exp(-t * 11.0) * 0.45 + _noise() * exp(-t * 40.0) * 0.12)
	_bank["coin"] = _make(0.2, func(t: float, _u: float) -> float:
		return sin(TAU * (900.0 + 700.0 * minf(1.0, t * 14.0)) * t) * exp(-t * 11.0) * 0.4)
	_bank["chest"] = _make(0.9, func(t: float, _u: float) -> float:
		var low := sin(TAU * 150.0 * t) * exp(-t * 6.0) * 0.5
		var bell := 0.0
		if t > 0.25:
			var tt := t - 0.25
			bell = (sin(TAU * 1046.0 * tt) + 0.5 * sin(TAU * 1568.0 * tt)) * exp(-tt * 5.0) * 0.3
		return low + bell)
	_bank["death"] = _make(0.9, func(t: float, u: float) -> float: return sin(TAU * (420.0 * (1.0 - u) + 50.0) * t) * (1.0 - u) * 0.5)
	_bank["step"] = _make(0.09, func(t: float, _u: float) -> float: return _noise() * exp(-t * 40.0) * 0.3)
	_bank["whoosh"] = _make(0.5, func(_t: float, u: float) -> float:
		lp["y"] = float(lp["y"]) + (_noise() - float(lp["y"])) * (0.1 + 0.4 * u)
		return float(lp["y"]) * sin(PI * u) * 0.9)


## Slow ambient music: four soft chords of three notes, each chord lasting six seconds, with a quiet plucked arpeggio on top. Made on a worker thread.
func _make_music() -> void:
	var chords := [[220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [261.6, 329.6, 392.0], [196.0, 246.9, 293.7]]
	var total := 24.0
	var n := int(total * MUSIC_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MUSIC_RATE
		var ci := int(t / 6.0) % 4
		var u := fmod(t, 6.0) / 6.0
		var env := pow(sin(PI * u), 0.5)
		var s := 0.0
		for f in chords[ci]:
			s += sin(TAU * f * t) * 0.07 + sin(TAU * f * 1.004 * t) * 0.05 + sin(TAU * f * 0.5 * t) * 0.04
		s *= env
		var step := fmod(t, 0.75)
		var note: float = chords[ci][int(t / 0.75) % 3] * 2.0
		s += sin(TAU * note * step) * exp(-step * 5.0) * 0.07
		# fade the very ends so the loop does not click
		s *= minf(1.0, minf(t * 8.0, (total - t) * 8.0))
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	_music_data = data
