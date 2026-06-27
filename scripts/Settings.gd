extends Control

@onready var _port_spin:    SpinBox  = $Panel/VBox/PortRow/PortSpin
@onready var _wins_spin:    SpinBox  = $Panel/VBox/WinsRow/WinsSpin
@onready var _hp_spin:      SpinBox  = $Panel/VBox/HPRow/HPSpin
@onready var _speed_spin:   SpinBox  = $Panel/VBox/SpeedRow/SpeedSpin
@onready var _bullet_spin:  SpinBox  = $Panel/VBox/BulletRow/BulletSpin
@onready var _vol_slider:   HSlider  = $Panel/VBox/VolumeRow/VolumeSlider
@onready var _vol_val:      Label    = $Panel/VBox/VolumeRow/VolumeVal

func _ready() -> void:
	_load_ui_from_config()
	$Panel/VBox/BtnRow/SaveBtn.pressed.connect(_on_save)
	$Panel/VBox/BtnRow/ResetBtn.pressed.connect(_on_reset)
	$Panel/VBox/BtnRow/BackBtn.pressed.connect(_on_back)
	_vol_slider.value_changed.connect(_on_volume_changed)

func _load_ui_from_config() -> void:
	_port_spin.value   = GameConfig.port
	_wins_spin.value   = GameConfig.wins_to_win
	_hp_spin.value     = GameConfig.player_hp
	_speed_spin.value  = GameConfig.player_speed
	_bullet_spin.value = GameConfig.bullet_speed
	_vol_slider.value  = GameConfig.volume
	_vol_val.text      = str(int(GameConfig.volume * 100)) + "%"

func _on_volume_changed(val: float) -> void:
	_vol_val.text = str(int(val * 100)) + "%"
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"), linear_to_db(val)
	)

func _on_save() -> void:
	GameConfig.port         = int(_port_spin.value)
	GameConfig.wins_to_win  = int(_wins_spin.value)
	GameConfig.player_hp    = int(_hp_spin.value)
	GameConfig.player_speed = _speed_spin.value
	GameConfig.bullet_speed = _bullet_spin.value
	GameConfig.volume       = _vol_slider.value
	GameConfig.save_config()
	$Panel/VBox/TitleLabel.text = "設定 ✓"
	await get_tree().create_timer(1.0).timeout
	$Panel/VBox/TitleLabel.text = "設定"

func _on_reset() -> void:
	GameConfig.reset_to_defaults()
	_load_ui_from_config()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
