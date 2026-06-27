extends Node

const SAMPLE_RATE = 22050.0
var _players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in range(8):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func play_shoot() -> void:
	_play_tone(880.0, 0.06, 0.35)

func play_hit() -> void:
	_play_noise(0.08, 0.5)

func play_round_win() -> void:
	_play_sequence_async([523, 659, 784, 1047], 0.13)

func play_round_lose() -> void:
	_play_sequence_async([523, 440, 349, 261], 0.13)

func play_powerup() -> void:
	_play_sequence_async([440, 660, 880, 1320], 0.09)

func play_countdown() -> void:
	_play_tone(440.0, 0.12, 0.4)

func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func _play_tone(freq: float, duration: float, volume: float = 0.4) -> void:
	var p = _get_free_player()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = duration + 0.05
	p.stream = gen
	p.volume_db = linear_to_db(volume)
	p.play()
	var pb := p.get_stream_playback() as AudioStreamGeneratorPlayback
	if not pb:
		return
	var frames = int(SAMPLE_RATE * duration)
	var phase = 0.0
	for i in range(frames):
		var t = float(i) / float(frames)
		var env = sin(t * PI)
		var sample = sin(phase * TAU) * env
		pb.push_frame(Vector2(sample, sample))
		phase = fmod(phase + freq / SAMPLE_RATE, 1.0)

func _play_noise(duration: float, volume: float = 0.5) -> void:
	var p = _get_free_player()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = duration + 0.05
	p.stream = gen
	p.volume_db = linear_to_db(volume)
	p.play()
	var pb := p.get_stream_playback() as AudioStreamGeneratorPlayback
	if not pb:
		return
	var frames = int(SAMPLE_RATE * duration)
	for i in range(frames):
		var t = float(i) / float(frames)
		var env = pow(1.0 - t, 1.5)
		var sample = (randf() * 2.0 - 1.0) * env
		pb.push_frame(Vector2(sample, sample))

func _play_sequence_async(freqs: Array, note_dur: float) -> void:
	for freq in freqs:
		_play_tone(float(freq), note_dur, 0.4)
		await get_tree().create_timer(note_dur).timeout
