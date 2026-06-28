extends Control

@onready var _port_spin:   SpinBox      = %PortSpin
@onready var _wins_spin:   SpinBox      = %WinsSpin
@onready var _hp_spin:     SpinBox      = %HPSpin
@onready var _speed_spin:  SpinBox      = %SpeedSpin
@onready var _bullet_spin: SpinBox      = %BulletSpin
@onready var _vol_slider:  HSlider      = %VolumeSlider
@onready var _vol_val:     Label        = %VolumeVal
@onready var _p1_device:   OptionButton = %P1DeviceOpt
@onready var _p2_device:   OptionButton = %P2DeviceOpt
@onready var _title_label: Label        = %TitleLabel

# キーコンフィグ状態
var _waiting_action: String = ""   # キャプチャー待ち中のアクション名
var _waiting_btn: Button = null    # ハイライト中のボタン

# アクション定義（表示名, GameConfigのプロパティ名, アクション文字列）
const KEYBIND_DEFS = [
	["--- P1 キー設定 ---", "", ""],
	["上移動",  "key_p1_up",    "move_up"],
	["下移動",  "key_p1_down",  "move_down"],
	["左移動",  "key_p1_left",  "move_left"],
	["右移動",  "key_p1_right", "move_right"],
	["射撃",    "key_p1_shoot", "shoot"],
	["--- P2 キー設定 ---", "", ""],
	["上移動",  "key_p2_up",    "move_up_p2"],
	["下移動",  "key_p2_down",  "move_down_p2"],
	["左移動",  "key_p2_left",  "move_left_p2"],
	["右移動",  "key_p2_right", "move_right_p2"],
	["射撃",    "key_p2_shoot", "shoot_p2"],
]

# アクション名 → ボタン（キー表示更新用）
var _key_buttons: Dictionary = {}

func _ready() -> void:
	_build_device_options()
	_load_ui_from_config()
	%SaveBtn.pressed.connect(_on_save)
	%ResetBtn.pressed.connect(_on_reset)
	%BackBtn.pressed.connect(_on_back)
	_vol_slider.value_changed.connect(_on_volume_changed)
	_build_keybind_ui()

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

# --- キーコンフィグUI ---

func _build_keybind_ui() -> void:
	# 既存UIの最後の子として追加（SaveBtn等の前に挿入）
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for row in KEYBIND_DEFS:
		var label_text: String = row[0]
		var prop_name: String  = row[1]
		var action: String     = row[2]

		if prop_name == "":
			# セクションヘッダー
			var sep = Label.new()
			sep.text = label_text
			sep.add_theme_color_override("font_color", Color(0.4, 1.0, 0.9))
			sep.add_theme_font_size_override("font_size", 14)
			vbox.add_child(sep)
			continue

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var lbl = Label.new()
		lbl.text = label_text
		lbl.custom_minimum_size = Vector2(80, 0)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 30)
		btn.text = _keycode_name(GameConfig.get(prop_name))
		btn.add_theme_font_size_override("font_size", 13)
		_key_buttons[action] = btn

		var cap_action = action
		var cap_prop   = prop_name
		btn.pressed.connect(func(): _start_capture(cap_action, cap_prop, btn))
		hbox.add_child(btn)

		vbox.add_child(hbox)

	# ScrollContainer を既存の VBox に挿入（SaveBtn の直前）
	var parent = %SaveBtn.get_parent()
	var save_idx = %SaveBtn.get_index()
	parent.add_child(scroll)
	parent.move_child(scroll, save_idx)

func _keycode_name(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "(なし)"
	var ev = InputEventKey.new()
	ev.keycode = keycode
	var t = ev.as_text()
	# Godot 4 は "Physical KeyCode" などを付けることがある → 簡潔にする
	t = t.replace("Physical ", "").replace("KeyCode ", "")
	return t

func _start_capture(action: String, prop: String, btn: Button) -> void:
	if _waiting_action != "":
		_cancel_capture()
	_waiting_action = action
	_waiting_btn = btn
	btn.text = "キー入力待ち..."
	btn.add_theme_color_override("font_color", Color.YELLOW)

func _cancel_capture() -> void:
	if _waiting_btn:
		var prop = _action_to_prop(_waiting_action)
		_waiting_btn.text = _keycode_name(GameConfig.get(prop))
		_waiting_btn.remove_theme_color_override("font_color")
	_waiting_action = ""
	_waiting_btn = null

func _action_to_prop(action: String) -> String:
	for row in KEYBIND_DEFS:
		if row[2] == action:
			return row[1]
	return ""

func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.keycode
	if kc == KEY_ESCAPE:
		_cancel_capture()
		get_viewport().set_input_as_handled()
		return
	# 反映
	var prop = _action_to_prop(_waiting_action)
	GameConfig.set(prop, kc)
	_waiting_btn.text = _keycode_name(kc)
	_waiting_btn.remove_theme_color_override("font_color")
	GameConfig.apply_keybinds()
	_waiting_action = ""
	_waiting_btn = null
	get_viewport().set_input_as_handled()

# --- 保存・リセット ---

func _on_save() -> void:
	if _waiting_action != "":
		_cancel_capture()
	GameConfig.port         = int(_port_spin.value)
	GameConfig.wins_to_win  = int(_wins_spin.value)
	GameConfig.player_hp    = int(_hp_spin.value)
	GameConfig.player_speed = _speed_spin.value
	GameConfig.bullet_speed = _bullet_spin.value
	GameConfig.volume       = _vol_slider.value
	_apply_device_opt(_p1_device, 1)
	_apply_device_opt(_p2_device, 2)
	GameConfig.save_config()
	_title_label.text = "設定 ✓"
	await get_tree().create_timer(1.0).timeout
	_title_label.text = "設定"

func _apply_device_opt(opt: OptionButton, player: int) -> void:
	if opt.selected == 0:
		if player == 1: GameConfig.p1_device = "keyboard"
		else:           GameConfig.p2_device = "keyboard"
	else:
		if player == 1:
			GameConfig.p1_device     = "gamepad"
			GameConfig.p1_gamepad_id = opt.selected - 1
		else:
			GameConfig.p2_device     = "gamepad"
			GameConfig.p2_gamepad_id = opt.selected - 1

func _on_reset() -> void:
	if _waiting_action != "":
		_cancel_capture()
	GameConfig.reset_to_defaults()
	_load_ui_from_config()
	_refresh_key_buttons()

func _refresh_key_buttons() -> void:
	for row in KEYBIND_DEFS:
		var prop: String   = row[1]
		var action: String = row[2]
		if prop == "":
			continue
		if _key_buttons.has(action):
			_key_buttons[action].text = _keycode_name(GameConfig.get(prop))

func _on_back() -> void:
	if _waiting_action != "":
		_cancel_capture()
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
