extends Node

const SFX   = "res://assets/sounds/sci-fi-sounds/Audio/"
const IMP   = "res://assets/sounds/impact-sounds/Audio/"
const INF   = "res://assets/sounds/interface-sounds/Audio/"
const GAME  = "res://assets/sounds/game-sounds/"
const DEATH = "res://assets/sounds/death-sounds/"

var _players: Array[AudioStreamPlayer] = []
var _snd: Dictionary = {}

const CFG_PATH = "res://assets/sounds/sfx_config.json"

func _ready() -> void:
	for i in range(16):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	if not _load_from_config():
		_preload_default()

func _load_from_config() -> bool:
	if not FileAccess.file_exists(CFG_PATH):
		return false
	var f := FileAccess.open(CFG_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return false
	var data = json.get_data()
	if not data is Dictionary:
		return false
	for cat in data:
		_snd[cat] = []
		for entry in data[cat]:
			var path: String = entry["path"]
			if ResourceLoader.exists(path):
				_snd[cat].append(load(path))
	return true

func _preload_default() -> void:
	# 0始まり (000, 001, ...)
	_snd["shoot"]       = _load_group(GAME, "pop_gun_%d.ogg", 5, 1)
	_snd["laser_shoot"] = _load_group(SFX, "laserLarge_%03d.ogg",    5, 0)
	_snd["hit"]      = _load_group(IMP, "impactPunch_heavy_%03d.ogg", 5, 0)
	_snd["wall_hit"] = _load_group(IMP, "impactMetal_heavy_%03d.ogg", 5, 0)
	_snd["death"]    = _load_group(DEATH, "splat_%02d.ogg", 8, 1)
	# 1始まり (001, 002, ...)
	_snd["dry_fire"] = _load_group(INF, "error_%03d.ogg",      8, 1)
	_snd["powerup"]  = _load_group(INF, "confirmation_%03d.ogg", 4, 1)
	_snd["countdown"]= _load_group(INF, "tick_%03d.ogg",       4, 1)  # 003は欠番のため4まで試みる
	_snd["win"]      = _load_group(INF, "maximize_%03d.ogg",    9, 1)
	_snd["lose"]     = _load_group(INF, "minimize_%03d.ogg",    9, 1)

func _load_group(base: String, pattern: String, count: int, start: int) -> Array:
	var arr: Array = []
	for i in range(start, start + count):
		var path = base + (pattern % i)
		if ResourceLoader.exists(path):
			arr.append(load(path))
	return arr

func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func _play_random(category: String, vol_db: float = 0.0) -> void:
	var arr: Array = _snd.get(category, [])
	if arr.is_empty():
		return
	var p = _get_free_player()
	p.stream = arr[randi() % arr.size()]
	p.volume_db = vol_db
	p.play()

# --- 公開API ---

func play_shoot() -> void:
	_play_random("shoot", -2.0)

func play_laser_shoot() -> void:
	_play_random("laser_shoot", -4.0)

func play_hit() -> void:
	_play_random("hit", 0.0)

func play_wall_hit() -> void:
	_play_random("wall_hit", -8.0)

func play_death() -> void:
	_play_random("death", 2.0)

func play_dry_fire() -> void:
	_play_random("dry_fire", -2.0)

func play_powerup() -> void:
	_play_random("powerup", 0.0)

func play_countdown() -> void:
	_play_random("countdown", 0.0)

func play_round_win() -> void:
	_play_random("win", 0.0)

func play_round_lose() -> void:
	_play_random("lose", 0.0)
