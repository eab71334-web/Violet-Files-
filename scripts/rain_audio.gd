extends Node
## Procedural ambience (no audio files needed): rain hiss, dark synth pad,
## rare distant thunder, plus a UI click blip. Generated live with AudioStreamGenerator.

const RATE := 11025.0

var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _lp := 0.0
var _lp2 := 0.0
var _p1 := 0.0
var _p2 := 0.0
var _pc := 0.0
var _lfo := 0.0
var _thunder := 0.0
var _click := 0.0
var _next_thunder := 14.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -4.0
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_fill()


func click() -> void:
	_click = 1.0


func _process(delta: float) -> void:
	_next_thunder -= delta
	if _next_thunder <= 0.0:
		_thunder = 1.0
		_next_thunder = randf_range(18.0, 35.0)
	_fill()


func _fill() -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in range(n):
		var w := randf() * 2.0 - 1.0
		_lp += (w - _lp) * 0.35        # rain hiss
		_lp2 += (w - _lp2) * 0.01      # low rumble
		_lfo += 1.0 / RATE
		_p1 += TAU * 55.0 / RATE
		_p2 += TAU * 82.4 / RATE
		_pc += TAU * 660.0 / RATE
		if _p1 > TAU: _p1 -= TAU
		if _p2 > TAU: _p2 -= TAU
		if _pc > TAU: _pc -= TAU
		var pad := (sin(_p1) + 0.6 * sin(_p2 + sin(_lfo * 0.3))) * 0.035 * (0.7 + 0.3 * sin(_lfo * 1.2))
		_thunder *= 0.99992
		_click *= 0.9986
		var s := _lp * 0.22 + pad + _lp2 * _thunder * 3.0 + sin(_pc) * _click * 0.12
		s = clampf(s, -1.0, 1.0)
		buf[i] = Vector2(s, s)
	_pb.push_buffer(buf)
