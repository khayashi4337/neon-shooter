extends Node2D

const PLAYER_SCENE = preload("res://scenes/Player.tscn")
const POWERUP_SHOW_DELAY = 1.2

const P1_START = Vector2(260, 360)
const P2_START = Vector2(1020, 360)
const P1_COLOR = Color(0.0, 1.0, 1.0)
const P2_COLOR = Color(1.0, 0.0, 1.0)

var _players: Dictionary = {}
var _wins: Dictionary = {}
var _current_round: int = 1
var _round_active: bool = false
var _game_over: bool = false

@onready var _players_node: Node2D = $PlayersNode
@onready var _bullets_node: Node2D = $BulletsNode
@onready var _powerup_menu: CanvasLayer = $PowerupMenu
@onready var _pause_menu: CanvasLayer = $PauseMenu
@onready var _p1_score: Label = $UI/ScoreBar/P1Score
@onready var _p2_score: Label = $UI/ScoreBar/P2Score
@onready var _round_label: Label = $UI/RoundLabel
@onready var _center_msg: Label = $UI/CenterMsg

func _ready() -> void:
	add_to_group("game")
	_powerup_menu.chosen.connect(_on_powerup_chosen_local)
	_pause_menu.resume_pressed.connect(_on_resume)
	_pause_menu.quit_pressed.connect(_on_quit_to_title)
	_center_msg.text = ""
	_create_environment()
	_create_map()
	_setup_players.call_deferred()

func _input(event: InputEvent) -> void:
	if _game_over:
		if event.is_action_pressed("ui_accept"):
			_restart_game()
		elif event.is_action_pressed("ui_cancel"):
			_on_quit_to_title()
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _toggle_pause() -> void:
	get_tree().paused = !get_tree().paused
	if get_tree().paused:
		_pause_menu.show()
	else:
		_pause_menu.hide()

func _on_resume() -> void:
	get_tree().paused = false
	_pause_menu.hide()

func _on_quit_to_title() -> void:
	get_tree().paused = false
	Network.stop_ngrok()
	multiplayer.multiplayer_peer = null
	Network.players.clear()
	get_tree().change_scene_to_file("res://scenes/Title.tscn")

func add_bullet(bullet: Node) -> void:
	_bullets_node.add_child(bullet)

# --- 環境・マップ生成 ---

func _create_environment() -> void:
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.06)
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 1.4
	env.glow_bloom = 0.35
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.7
	for i in range(1, 8):
		env.set_glow_level(i, 1.0)
	world_env.environment = env
	add_child(world_env)

func _create_map() -> void:
	var neon_wall = Color(0.05, 0.05, 0.35)
	var neon_bright = Color(0.1, 0.1, 0.7)
	# 外周
	_make_wall(Vector2(640, -10),  Vector2(1280, 20),  neon_wall)
	_make_wall(Vector2(640, 730),  Vector2(1280, 20),  neon_wall)
	_make_wall(Vector2(-10, 360),  Vector2(20, 720),   neon_wall)
	_make_wall(Vector2(1290, 360), Vector2(20, 720),   neon_wall)
	# 中央縦壁（隠れられる）
	_make_wall(Vector2(640, 290),  Vector2(22, 200),   neon_bright)
	_make_wall(Vector2(640, 430),  Vector2(22, 200),   neon_bright)
	# 左右の横壁
	_make_wall(Vector2(320, 200),  Vector2(140, 22),   neon_bright)
	_make_wall(Vector2(320, 520),  Vector2(140, 22),   neon_bright)
	_make_wall(Vector2(960, 200),  Vector2(140, 22),   neon_bright)
	_make_wall(Vector2(960, 520),  Vector2(140, 22),   neon_bright)

func _make_wall(pos: Vector2, size: Vector2, col: Color) -> void:
	var body = StaticBody2D.new()
	body.global_position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var shape_node = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	body.add_child(shape_node)

	var spr = Sprite2D.new()
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, col)
	spr.texture = ImageTexture.create_from_image(img)
	spr.scale = size
	body.add_child(spr)

	add_child(body)

# --- プレイヤー生成 ---

func _setup_players() -> void:
	var ids = Network.get_sorted_ids()
	if ids.size() < 2:
		return
	var id0 = ids[0]
	var id1 = ids[1]
	_wins[id0] = 0
	_wins[id1] = 0

	_spawn_player(id0, P1_COLOR, P1_START)
	_spawn_player(id1, P2_COLOR, P2_START)

	_update_score_ui()
	_start_round_countdown()

func _spawn_player(pid: int, color: Color, start_pos: Vector2) -> void:
	var p = PLAYER_SCENE.instantiate()
	p.name = "P_%d" % pid
	p.player_id = pid
	p.player_color = color
	p.global_position = start_pos
	if Network.game_mode == "cpu" and pid == 2:
		p.is_cpu = true
		p.set_multiplayer_authority(1)
	_players_node.add_child(p)
	p.died.connect(_on_player_died)
	_players[pid] = p

# --- ラウンド制御 ---

func _start_round_countdown() -> void:
	_round_label.text = "Round %d" % _current_round
	for i in [3, 2, 1]:
		_center_msg.text = str(i)
		_center_msg.modulate = Color.WHITE
		AudioManager.play_countdown()
		await get_tree().create_timer(1.0).timeout
	_center_msg.text = "FIGHT!"
	_center_msg.modulate = Color.YELLOW
	AudioManager.play_countdown()
	await get_tree().create_timer(0.7).timeout
	_center_msg.text = ""
	_round_active = true

func _on_player_died(dead_id: int) -> void:
	if not _round_active:
		return
	_round_active = false

	var winner_id = _resolve_round_winner(dead_id)
	_wins[winner_id] = _wins.get(winner_id, 0) + 1
	_update_score_ui()
	_show_round_result(winner_id)

	if _check_game_over():
		_enter_game_over()
		return

	await get_tree().create_timer(POWERUP_SHOW_DELAY).timeout
	_center_msg.text = ""

	var my_id = multiplayer.get_unique_id()
	if Network.game_mode == "cpu" and dead_id != my_id:
		_handle_cpu_powerup(dead_id)
	else:
		_powerup_menu.show_menu(dead_id, dead_id == my_id)

func _resolve_round_winner(dead_id: int) -> int:
	for pid in _players:
		if pid != dead_id:
			return pid
	return -1

func _show_round_result(winner_id: int) -> void:
	var my_id = multiplayer.get_unique_id()
	if winner_id == my_id:
		_center_msg.text = "WIN"
		_center_msg.modulate = Color.CYAN
		AudioManager.play_round_win()
	else:
		_center_msg.text = "LOSE"
		_center_msg.modulate = Color.MAGENTA
		AudioManager.play_round_lose()

func _handle_cpu_powerup(dead_id: int) -> void:
	var cpu_node = _players.get(dead_id)
	var pick: String
	if is_instance_valid(cpu_node) and cpu_node.hp < cpu_node.max_hp * 0.4:
		pick = "ARMOR"
	else:
		var pool = _powerup_menu.POWERUPS
		pick = pool[randi() % pool.size()]
	_rpc_apply_powerup.rpc(dead_id, pick)

func _on_powerup_chosen_local(loser_id: int, pw: String) -> void:
	_powerup_menu.hide_menu()
	_rpc_apply_powerup.rpc(loser_id, pw)

@rpc("any_peer", "call_local", "reliable")
func _rpc_apply_powerup(loser_id: int, pw: String) -> void:
	if _players.has(loser_id):
		_players[loser_id].apply_powerup(pw)
	_powerup_menu.hide_menu()
	AudioManager.play_powerup()
	await get_tree().create_timer(0.5).timeout
	_next_round()

func _next_round() -> void:
	_current_round += 1
	var ids = Network.get_sorted_ids()
	_players[ids[0]].reset_for_round(P1_START)
	_players[ids[1]].reset_for_round(P2_START)
	for b in _bullets_node.get_children():
		b.queue_free()
	_start_round_countdown()

func _check_game_over() -> bool:
	for pid in _wins:
		if _wins[pid] >= GameConfig.wins_to_win:
			var my_id = multiplayer.get_unique_id()
			if pid == my_id:
				_center_msg.text = "VICTORY!"
				_center_msg.modulate = Color.GOLD
			else:
				_center_msg.text = "DEFEATED"
				_center_msg.modulate = Color(0.5, 0.5, 0.5)
			return true
	return false

func _enter_game_over() -> void:
	_game_over = true
	await get_tree().create_timer(2.0).timeout
	_center_msg.text += "\n[Enter] もう一度  [Esc] タイトルへ"
	_center_msg.modulate = Color.WHITE

func _restart_game() -> void:
	var ids = Network.get_sorted_ids()
	if ids.size() < 2:
		return
	_game_over = false
	_current_round = 1
	for pid in ids:
		_wins[pid] = 0
	_update_score_ui()
	for b in _bullets_node.get_children():
		b.queue_free()
	_players[ids[0]].reset_for_new_game(P1_START)
	_players[ids[1]].reset_for_new_game(P2_START)
	_center_msg.text = ""
	_start_round_countdown()

func _update_score_ui() -> void:
	var ids = Network.get_sorted_ids()
	if ids.size() < 2:
		return
	_p1_score.text = str(_wins.get(ids[0], 0))
	_p2_score.text = str(_wins.get(ids[1], 0))
