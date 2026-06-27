extends CanvasLayer

signal resume_pressed
signal quit_pressed

func _ready() -> void:
	$Panel/VBox/ResumeBtn.pressed.connect(func(): resume_pressed.emit())
	$Panel/VBox/QuitBtn.pressed.connect(func(): quit_pressed.emit())
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
