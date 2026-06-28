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

# アクション定義: [表示名, GameConfigプロパティ名, アクション文字列, デフォルトキーコード]
const KEYBIND_DEFS = [
	["--- P1 キー設定 ---", "", "", 0],
	["上移動",  "key_p1_up",    "move_up",       KEY_W],
	["下移動",  "key_p1_down",  "move_down",     KEY_S],
	["左移動",  "key_p1_left",  "move_left",     KEY_A],
	["右移動",  "key_p1_right", "move_right",    KEY_D],
	["射撃",    "key_p1_shoot", "shoot",         KEY_SPACE],
	["--- P2 キー設定 ---", "", "", 0],
	["上移動",  "key_p2_up",    "move_up_p2",    KEY_I],
	["下移動",  "key_p2_down",  "move_down_p2",  KEY_K],
	["左移動",  "key_p2_left",  "move_left_p2",  KEY_J],
	["右移動",  "key_p2_right", "move_right_p2", KEY_L],
	["射撃",    "key_p2_shoot", "shoot_p2",      KEY_ENTER],
]

# キャプチャー状態
var _waiting_action: String = ""
var _waiting_label: Label = null

# action文字列 → 現在のキー表示Label
var _current_labels: Dictionary = {}

func _ready() -> void:
	_build_device_options()
	_load_ui_from_config()
	%SaveBtn.pressed.connect(_on_save)
	%ResetBtn.pressed.connect(_on_reset)
	%BackBtn.pressed.connect(_on_back)
	_vol_slider.value_changed.connect(_on_volume_changed)
	_build_keybind_ui()

# --- デバイス選択 ---

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

# --- キーコンフィグUI構築 ---

func _build_keybind_ui() -> void:
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# テーブルヘッダー
	var header = _make_header()
	vbox.add_child(header)

	for row in KEYBIND_DEFS:
		var label_text: String = row[0]
		var prop_name: String  = row[1]
		var action: String     = row[2]
		var default_kc: int    = row[3]

		if prop_name == "":
			# セクション区切り
			var sep = Label.new()
			sep.text = label_text
			sep.add_theme_color_override("font_color", Color(0.4, 1.0, 0.9))
			sep.add_theme_font_size_override("font_size", 14)
			vbox.add_child(sep)
			# ヘッダー行を再表示
			vbox.add_child(_make_header())
			continue

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)

		# 列1：アクション名
		var lbl_name = Label.new()
		lbl_name.text = label_text
		lbl_name.custom_minimum_size = Vector2(80, 0)
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl_name)

		# 列2：デフォルトキー（固定表示）
		var lbl_default = Label.new()
		lbl_default.text = _keycode_name(default_kc)
		lbl_default.custom_minimum_size = Vector2(100, 0)
		lbl_default.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_default.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		hbox.add_child(lbl_default)

		# 列3：現在の設定（変更後に更新）
		var lbl_current = Label.new()
		lbl_current.text = _keycode_name(GameConfig.get(prop_name))
		lbl_current.custom_minimum_size = Vector2(100, 0)
		lbl_current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_current.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
		_current_labels[action] = lbl_current
		hbox.add_child(lbl_current)

		# 列4：設定ボタン
		var btn = Button.new()
		btn.text = "設定"
		btn.custom_minimum_size = Vector2(60, 26)
		btn.add_theme_font_size_override("font_size", 12)
		var cap_action = action
		var cap_prop   = prop_name
		btn.pressed.connect(func(): _start_capture(cap_action, cap_prop, lbl_current))
		hbox.add_child(btn)

		vbox.add_child(hbox)

	# BtnRow（HBoxContainer）の親 VBox に、BtnRow 直前で挿入
	var btn_row  = %SaveBtn.get_parent()          # HBoxContainer (BtnRow)
	var vbox_par = btn_row.get_parent()            # VBoxContainer
	var btn_idx  = btn_row.get_index()
	vbox_par.add_child(scroll)
	vbox_par.move_child(scroll, btn_idx)

func _make_header() -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	for pair in [["操作", 80], ["デフォルト", 100], ["現在の設定", 100], ["", 60]]:
		var lbl = Label.new()
		lbl.text = pair[0]
		lbl.custom_minimum_size = Vector2(pair[1], 0)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		if pair[1] == 100:
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if pair[0] != "操作":
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)
	return hbox

func _keycode_name(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "(なし)"
	var name = OS.get_keycode_string(keycode)
	if name.is_empty():
		return "Key %d" % keycode
	return name

# --- キャプチャー ---

func _start_capture(action: String, prop: String, lbl: Label) -> void:
	if _waiting_action != "":
		_cancel_capture()
	_waiting_action = action
	_waiting_label  = lbl
	lbl.text = "入力待ち..."
	lbl.add_theme_color_override("font_color", Color.YELLOW)

func _cancel_capture() -> void:
	if _waiting_label:
		var prop = _action_to_prop(_waiting_action)
		_waiting_label.text = _keycode_name(GameConfig.get(prop))
		_waiting_label.remove_theme_color_override("font_color")
		_waiting_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	_waiting_action = ""
	_waiting_label  = null

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
	var prop = _action_to_prop(_waiting_action)
	GameConfig.set(prop, kc)
	_waiting_label.text = _keycode_name(kc)
	_waiting_label.remove_theme_color_override("font_color")
	_waiting_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	GameConfig.apply_keybinds()
	_waiting_action = ""
	_waiting_label  = null
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
	for row in KEYBIND_DEFS:
		var action: String = row[2]
		var prop: String   = row[1]
		if prop == "" or not _current_labels.has(action):
			continue
		_current_labels[action].text = _keycode_name(GameConfig.get(prop))

func _on_back() -> void:
	if _waiting_action != "":
		_cancel_capture()
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
