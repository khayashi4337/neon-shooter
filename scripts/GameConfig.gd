extends Node

# ネットワーク
var port: int = 7777

# ゲーム
var wins_to_win: int = 3
var player_hp: int = 100
var player_speed: float = 210.0
var bullet_speed: float = 520.0
var fire_rate: float = 0.28

# 音量（0.0〜1.0）
var volume: float = 0.8

# 内部設定（設定ファイルのみで管理）
var ngrok_poll_interval: float = 1.0
var ngrok_max_retries: int = 20
var ngrok_startup_wait: float = 5.0

const CONFIG_PATH = "user://config.cfg"

func _ready() -> void:
	load_config()
	_apply_volume()

func load_config() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	port              = cfg.get_value("network", "port",              port)
	wins_to_win       = cfg.get_value("game",    "wins_to_win",       wins_to_win)
	player_hp         = cfg.get_value("game",    "player_hp",         player_hp)
	player_speed      = cfg.get_value("game",    "player_speed",      player_speed)
	bullet_speed      = cfg.get_value("game",    "bullet_speed",      bullet_speed)
	fire_rate         = cfg.get_value("game",    "fire_rate",         fire_rate)
	volume            = cfg.get_value("audio",   "volume",            volume)
	ngrok_poll_interval = cfg.get_value("advanced", "ngrok_poll_interval", ngrok_poll_interval)
	ngrok_max_retries   = cfg.get_value("advanced", "ngrok_max_retries",   ngrok_max_retries)
	ngrok_startup_wait  = cfg.get_value("advanced", "ngrok_startup_wait",  ngrok_startup_wait)

func save_config() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("network", "port",              port)
	cfg.set_value("game",    "wins_to_win",       wins_to_win)
	cfg.set_value("game",    "player_hp",         player_hp)
	cfg.set_value("game",    "player_speed",      player_speed)
	cfg.set_value("game",    "bullet_speed",      bullet_speed)
	cfg.set_value("game",    "fire_rate",         fire_rate)
	cfg.set_value("audio",   "volume",            volume)
	cfg.set_value("advanced", "ngrok_poll_interval", ngrok_poll_interval)
	cfg.set_value("advanced", "ngrok_max_retries",   ngrok_max_retries)
	cfg.set_value("advanced", "ngrok_startup_wait",  ngrok_startup_wait)
	cfg.save(CONFIG_PATH)

func reset_to_defaults() -> void:
	port             = 7777
	wins_to_win      = 3
	player_hp        = 100
	player_speed     = 210.0
	bullet_speed     = 520.0
	fire_rate        = 0.28
	volume           = 0.8
	ngrok_poll_interval = 1.0
	ngrok_max_retries   = 20
	ngrok_startup_wait  = 5.0
	save_config()
	_apply_volume()

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume))
