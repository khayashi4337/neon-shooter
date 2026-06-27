extends Control

@onready var _port_spin:   SpinBox      = $Panel/ScrollContainer/VBox/PortRow/PortSpin
@onready var _wins_spin:   SpinBox      = $Panel/ScrollContainer/VBox/WinsRow/WinsSpin
@onready var _hp_spin:     SpinBox      = $Panel/ScrollContainer/VBox/HPRow/HPSpin
@onready var _speed_spin:  SpinBox      = $Panel/ScrollContainer/VBox/SpeedRow/SpeedSpin
@onready var _bullet_spin: SpinBox      = $Panel/ScrollContainer/VBox/BulletRow/BulletSpin
@onready var _vol_slider:  HSlider      = $Panel/ScrollContainer/VBox/VolumeRow/VolumeSlider
@onready var _vol_val:     Label        = $Panel/ScrollContainer/VBox/VolumeRow/VolumeVal
@onready var _p1_device:   OptionButton = $Panel/ScrollContainer/VBox/P1DeviceRow/P1DeviceOpt
@onready var _p2_device:   OptionButton = $Panel/ScrollContainer/VBox/P2DeviceRow/P2DeviceOpt
@onready var _title_label: Label        = $Panel/ScrollContainer/VBox/TitleLabel

func _ready() -> void:
	_build_device_options()
	_load_ui_from_config()
	$Panel/ScrollContainer/VBox/BtnRow/SaveBtn.pressed.connect(_on_save)
	$Panel/ScrollContainer/VBox/BtnRow/ResetBtn.pressed.connect(_on_reset)
	$Panel/ScrollContainer/VBox/BtnRow/BackBtn.pressed.connect(_on_back)
	_vol_slider.value_changed.connect(_on_volume_changed)

func _build_device_options() -> void:
	var pads = Input.get_connected_joypads()
	for opt in [_p1_device, _p2_device]:
		opt.add_item("キーボード / マウス")
		for pid in pads:
			opt.add_item("ゲームパッド %d: %s" % [pid, Input.get_joy_name(pid)])
		if pads.is_empty():
			opt.add_item("ゲームパッド 0 (未接続)")

func _load_ui_from_config() -> void:
	_port_spin.value   = GameConfig.port
	_wins_spin.value   = GameConfig.wins_to_win
	_hp_spin.value     = GameConfig.player_hp
	_speed_spin.value  = GameConfig.player_speed
	_bullet_spin.value = GameConfig.bullet_speed
	_vol_slider.value  = GameConfig.volume
	_vol_val.text      = str(int(GameConfig.volume * 100)) + "%"
	_p1_device.selected = 0 if GameConfig.p1_device == "keyboard" else GameConfig.p1_gamepad_id + 1
	_p2_device.selected = 0 if GameConfig.p2_device == "keyboard" else GameConfig.p2_gamepad_id + 1

func _on_volume_changed(val: float) -> void:
	_vol_val.text = str(int(val * 100)) + "%"
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(val))

func _on_save() -> void:
	GameConfig.port         = int(_port_spin.value)
	GameConfig.wins_to_win  = int(_wins_spin.value)
	GameConfig.player_hp    = int(_hp_spin.value)
	GameConfig.player_speed = _speed_spin.value
	GameConfig.bullet_speed = _bullet_spin.value
	GameConfig.volume       = _vol_slider.value
	if _p1_device.selected == 0:
		GameConfig.p1_device = "keyboard"
	else:
		GameConfig.p1_device = "gamepad"
		GameConfig.p1_gamepad_id = _p1_device.selected - 1
	if _p2_device.selected == 0:
		GameConfig.p2_device = "keyboard"
	else:
		GameConfig.p2_device = "gamepad"
		GameConfig.p2_gamepad_id = _p2_device.selected - 1
	GameConfig.save_config()
	_title_label.text = "設定 ✓"
	await get_tree().create_timer(1.0).timeout
	_title_label.text = "設定"

func _on_reset() -> void:
	GameConfig.reset_to_defaults()
	_load_ui_from_config()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
