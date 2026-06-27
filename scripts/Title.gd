extends Control

func _ready() -> void:
	$Panel/VBox/InternetBtn.pressed.connect(_on_internet)
	$Panel/VBox/LocalBtn.pressed.connect(_on_local)
	$Panel/VBox/SamePCBtn.pressed.connect(_on_samepc)
	$Panel/VBox/CpuBtn.pressed.connect(_on_cpu)
	$Panel/VBox/SettingsBtn.pressed.connect(_on_settings)
	$Panel/VBox/QuitBtn.pressed.connect(_on_quit)

func _on_internet() -> void:
	Network.game_mode = "internet"
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_local() -> void:
	Network.game_mode = "local"
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_samepc() -> void:
	Network.game_mode = "samepc"
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_cpu() -> void:
	Network.start_cpu_game()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_quit() -> void:
	get_tree().quit()
