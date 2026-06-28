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

# 入力デバイス（"keyboard" or "gamepad"）
var p1_device: String = "gamepad"
var p2_device: String = "gamepad"
var p1_gamepad_id: int = 0
var p2_gamepad_id: int = 1

# キーバインド（keycode整数値。KEY_*定数と同値）
var key_p1_up:    int = KEY_W
var key_p1_down:  int = KEY_S
var key_p1_left:  int = KEY_A
var key_p1_right: int = KEY_D
var key_p1_shoot: int = KEY_SPACE

var key_p2_up:    int = KEY_I
var key_p2_down:  int = KEY_K
var key_p2_left:  int = KEY_J
var key_p2_right: int = KEY_L
var key_p2_shoot: int = KEY_ENTER

# 内部設定（設定ファイルのみで管理）
var ngrok_poll_interval: float = 1.0
var ngrok_max_retries: int = 20
var ngrok_startup_wait: float = 5.0

const CONFIG_PATH = "user://config.cfg"

func _ready() -> void:
	load_config()
	_apply_volume()
	apply_keybinds()

# --- キーバインド ---

func apply_keybinds() -> void:
	_set_action("move_up",       [key_p1_up])
	_set_action("move_down",     [key_p1_down])
	_set_action("move_left",     [key_p1_left])
	_set_action("move_right",    [key_p1_right])
	_set_action("shoot",         [key_p1_shoot])
	# P1 射撃はマウス左ボタンも常時有効
	var mouse_ev = InputEventMouseButton.new()
	mouse_ev.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", mouse_ev)
	_set_action("move_up_p2",    [key_p2_up])
	_set_action("move_down_p2",  [key_p2_down])
	_set_action("move_left_p2",  [key_p2_left])
	_set_action("move_right_p2", [key_p2_right])
	_set_action("shoot_p2",      [key_p2_shoot])

func _set_action(action: String, keycodes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for kc in keycodes:
		var ev = InputEventKey.new()
		ev.keycode = kc
		InputMap.action_add_event(action, ev)

# --- 設定の保存・ロード ---

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
	p1_device         = cfg.get_value("input",   "p1_device",          p1_device)
	p2_device         = cfg.get_value("input",   "p2_device",          p2_device)
	p1_gamepad_id     = cfg.get_value("input",   "p1_gamepad_id",      p1_gamepad_id)
	p2_gamepad_id     = cfg.get_value("input",   "p2_gamepad_id",      p2_gamepad_id)
	ngrok_poll_interval = cfg.get_value("advanced", "ngrok_poll_interval", ngrok_poll_interval)
	ngrok_max_retries   = cfg.get_value("advanced", "ngrok_max_retries",   ngrok_max_retries)
	ngrok_startup_wait  = cfg.get_value("advanced", "ngrok_startup_wait",  ngrok_startup_wait)
	key_p1_up    = cfg.get_value("keybinds", "p1_up",    key_p1_up)
	key_p1_down  = cfg.get_value("keybinds", "p1_down",  key_p1_down)
	key_p1_left  = cfg.get_value("keybinds", "p1_left",  key_p1_left)
	key_p1_right = cfg.get_value("keybinds", "p1_right", key_p1_right)
	key_p1_shoot = cfg.get_value("keybinds", "p1_shoot", key_p1_shoot)
	key_p2_up    = cfg.get_value("keybinds", "p2_up",    key_p2_up)
	key_p2_down  = cfg.get_value("keybinds", "p2_down",  key_p2_down)
	key_p2_left  = cfg.get_value("keybinds", "p2_left",  key_p2_left)
	key_p2_right = cfg.get_value("keybinds", "p2_right", key_p2_right)
	key_p2_shoot = cfg.get_value("keybinds", "p2_shoot", key_p2_shoot)

func save_config() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("network", "port",              port)
	cfg.set_value("game",    "wins_to_win",       wins_to_win)
	cfg.set_value("game",    "player_hp",         player_hp)
	cfg.set_value("game",    "player_speed",      player_speed)
	cfg.set_value("game",    "bullet_speed",      bullet_speed)
	cfg.set_value("game",    "fire_rate",         fire_rate)
	cfg.set_value("audio",   "volume",            volume)
	cfg.set_value("input",   "p1_device",         p1_device)
	cfg.set_value("input",   "p2_device",         p2_device)
	cfg.set_value("input",   "p1_gamepad_id",     p1_gamepad_id)
	cfg.set_value("input",   "p2_gamepad_id",     p2_gamepad_id)
	cfg.set_value("advanced", "ngrok_poll_interval", ngrok_poll_interval)
	cfg.set_value("advanced", "ngrok_max_retries",   ngrok_max_retries)
	cfg.set_value("advanced", "ngrok_startup_wait",  ngrok_startup_wait)
	cfg.set_value("keybinds", "p1_up",    key_p1_up)
	cfg.set_value("keybinds", "p1_down",  key_p1_down)
	cfg.set_value("keybinds", "p1_left",  key_p1_left)
	cfg.set_value("keybinds", "p1_right", key_p1_right)
	cfg.set_value("keybinds", "p1_shoot", key_p1_shoot)
	cfg.set_value("keybinds", "p2_up",    key_p2_up)
	cfg.set_value("keybinds", "p2_down",  key_p2_down)
	cfg.set_value("keybinds", "p2_left",  key_p2_left)
	cfg.set_value("keybinds", "p2_right", key_p2_right)
	cfg.set_value("keybinds", "p2_shoot", key_p2_shoot)
	cfg.save(CONFIG_PATH)

func reset_to_defaults() -> void:
	port             = 7777
	wins_to_win      = 3
	player_hp        = 100
	player_speed     = 210.0
	bullet_speed     = 520.0
	fire_rate        = 0.28
	volume           = 0.8
	p1_device        = "gamepad"
	p2_device        = "gamepad"
	p1_gamepad_id    = 0
	p2_gamepad_id    = 1
	ngrok_poll_interval = 1.0
	ngrok_max_retries   = 20
	ngrok_startup_wait  = 5.0
	key_p1_up    = KEY_W
	key_p1_down  = KEY_S
	key_p1_left  = KEY_A
	key_p1_right = KEY_D
	key_p1_shoot = KEY_SPACE
	key_p2_up    = KEY_I
	key_p2_down  = KEY_K
	key_p2_left  = KEY_J
	key_p2_right = KEY_L
	key_p2_shoot = KEY_ENTER
	save_config()
	_apply_volume()
	apply_keybinds()

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume))
