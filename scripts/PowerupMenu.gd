extends CanvasLayer

const POWERUPS = ["SPEED", "RAPID", "ARMOR", "PIERCE"]
const DESCRIPTIONS = {
	"SPEED": "移動速度 +50%",
	"RAPID": "連射速度 2倍",
	"ARMOR": "最大HP +50%",
	"PIERCE": "弾が壁を貫通",
}
const PW_COLORS = {
	"SPEED": Color(1.0, 1.0, 0.0),
	"RAPID": Color(1.0, 0.4, 0.0),
	"ARMOR": Color(0.2, 1.0, 0.2),
	"PIERCE": Color(1.0, 0.2, 1.0),
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
		btn.text = pw + "\n" + DESCRIPTIONS[pw]
		btn.add_theme_color_override("font_color", PW_COLORS[pw])
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 18)
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
