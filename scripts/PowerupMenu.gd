extends CanvasLayer

const POWERUPS = ["SPEED", "RAPID", "ARMOR", "PIERCE"]
const DESCRIPTIONS = {
	"SPEED": "移動速度 +50%",
	"RAPID": "連射速度 2倍",
	"ARMOR": "最大HP +50%",
	"PIERCE": "弾が壁を貫通",
}
const PW_COLORS = {
	"SPEED":  Color(1.0, 0.9, 0.0),   # 黄（攻撃系）
	"RAPID":  Color(1.0, 0.85, 0.1),  # 黄（攻撃系）
	"ARMOR":  Color(0.0, 0.85, 1.0),  # 水色（防御系）
	"PIERCE": Color(1.0, 0.95, 0.0),  # 黄（攻撃系）
}
const PW_TYPES = {
	"SPEED": "atk", "RAPID": "atk", "ARMOR": "def", "PIERCE": "atk"
}

var _loser_id: int = -1

signal chosen(loser_id: int, powerup: String)

@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/VBox/Title
@onready var _btn_container: HBoxContainer = $Panel/VBox/Buttons

func _ready() -> void:
	hide()
	_build_buttons()

func _build_buttons() -> void:
	for pw in POWERUPS:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 100)
		var type_label = "[攻撃]" if PW_TYPES[pw] == "atk" else "[防御]"
		btn.text = type_label + " " + pw + "\n" + DESCRIPTIONS[pw]
		btn.add_theme_color_override("font_color", PW_COLORS[pw])
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 18)
		# 背景色を薄く着色
		var bg = StyleBoxFlat.new()
		bg.bg_color = PW_COLORS[pw] * 0.15
		bg.border_width_left = 2; bg.border_width_right = 2
		bg.border_width_top = 2;  bg.border_width_bottom = 2
		bg.border_color = PW_COLORS[pw] * 0.6
		btn.add_theme_stylebox_override("normal", bg)
		var p = pw
		btn.pressed.connect(func(): _on_chosen(p))
		_btn_container.add_child(btn)

func show_menu(loser_id: int, is_local: bool) -> void:
	_loser_id = loser_id
	_title.text = "POWER UP" if is_local else "相手がパワーアップ選択中..."
	for child in _btn_container.get_children():
		child.disabled = not is_local
	show()

func _on_chosen(pw: String) -> void:
	hide()
	chosen.emit(_loser_id, pw)

func hide_menu() -> void:
	hide()
