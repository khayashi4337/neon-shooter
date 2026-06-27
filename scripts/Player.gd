extends CharacterBody2D

const BULLET_SCENE = preload("res://scenes/Bullet.tscn")
var SPEED_BASE: float
var FIRE_RATE_BASE: float

@export var player_id: int = 1
@export var player_color: Color = Color.CYAN

var hp: int
var max_hp: int
var fire_cd: float = 0.0
var speed_mult: float = 1.0
var fire_rate_mult: float = 1.0
var can_pierce: bool = false
var is_dead: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _light: PointLight2D = $PointLight2D
@onready var _col: CollisionShape2D = $CollisionShape2D
@onready var _hp_bar: ProgressBar = $HPBar

signal died(player_id: int)

func _ready() -> void:
	SPEED_BASE     = GameConfig.player_speed
	FIRE_RATE_BASE = GameConfig.fire_rate
	hp             = GameConfig.player_hp
	max_hp         = GameConfig.player_hp
	set_multiplayer_authority(player_id)
	_setup_visuals()

func _setup_visuals() -> void:
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for x in range(48):
		for y in range(48):
			var d = Vector2(x - 24, y - 24).length()
			if d < 20.0:
				var edge = clamp((20.0 - d) / 3.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(player_color.r, player_color.g, player_color.b, edge))
	_sprite.texture = ImageTexture.create_from_image(img)

	var li = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for x in range(128):
		for y in range(128):
			var d = Vector2(x - 64, y - 64).length()
			var a = clamp(1.0 - d / 64.0, 0.0, 1.0) * 0.85
			li.set_pixel(x, y, Color(1, 1, 1, a))
	_light.texture = ImageTexture.create_from_image(li)
	_light.color = player_color
	_light.energy = 1.8
	_light.texture_scale = 1.0

	var cs = CircleShape2D.new()
	cs.radius = 18.0
	_col.shape = cs

	# 銃口インジケーター（rotation方向に自動追従）
	var gun_img = Image.create(18, 6, false, Image.FORMAT_RGBA8)
	for gx in range(18):
		for gy in range(6):
			var alpha = lerp(1.0, 0.3, float(gx) / 18.0)
			gun_img.set_pixel(gx, gy, Color(player_color.r, player_color.g, player_color.b, alpha))
	var gun = Sprite2D.new()
	gun.texture = ImageTexture.create_from_image(gun_img)
	gun.position = Vector2(30, 0)
	add_child(gun)

	# 目（前方方向に自動追従）
	var eye_img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for ex in range(8):
		for ey in range(8):
			var d = Vector2(ex - 4.0, ey - 4.0).length()
			if d < 2.5:
				eye_img.set_pixel(ex, ey, Color(0.05, 0.05, 0.05, 1.0))  # 瞳
			elif d < 3.8:
				eye_img.set_pixel(ex, ey, Color(1.0, 1.0, 1.0, 1.0 - (d - 2.5) / 1.5))  # 白目
	var eye_tex = ImageTexture.create_from_image(eye_img)
	var eye_l = Sprite2D.new()
	eye_l.texture = eye_tex
	eye_l.position = Vector2(11, -7)
	add_child(eye_l)
	var eye_r = Sprite2D.new()
	eye_r.texture = eye_tex
	eye_r.position = Vector2(11, 7)
	add_child(eye_r)

	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.position = Vector2(-30, -38)
	_hp_bar.size = Vector2(60, 8)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = player_color
	_hp_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	_hp_bar.add_theme_stylebox_override("background", bg_style)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	fire_cd -= delta
	if is_multiplayer_authority():
		_handle_input()
		_rpc_sync.rpc(global_position, rotation)

func _handle_input() -> void:
	var use_pad = (GameConfig.p1_device == "gamepad" if player_id == 1 else GameConfig.p2_device == "gamepad")
	var pad_id  = (GameConfig.p1_gamepad_id if player_id == 1 else GameConfig.p2_gamepad_id)

	# 移動
	var dir: Vector2
	if use_pad:
		dir = Vector2(Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_X),
		              Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_Y))
		if dir.length() < 0.2:
			dir = Vector2.ZERO
	else:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED_BASE * speed_mult
	move_and_slide()

	# 照準
	if use_pad:
		var aim = Vector2(Input.get_joy_axis(pad_id, JOY_AXIS_RIGHT_X),
		                  Input.get_joy_axis(pad_id, JOY_AXIS_RIGHT_Y))
		if aim.length() > 0.2:
			rotation = aim.angle()
	else:
		rotation = (get_global_mouse_position() - global_position).angle()

	# 射撃
	var firing: bool
	if use_pad:
		firing = (Input.get_joy_axis(pad_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		          or Input.is_joy_button_pressed(pad_id, JOY_BUTTON_RIGHT_SHOULDER))
	else:
		firing = Input.is_action_pressed("shoot" if player_id == 1 else "shoot_p2")
	if firing and fire_cd <= 0.0:
		fire_cd = FIRE_RATE_BASE / fire_rate_mult
		_rpc_fire.rpc(global_position, rotation)

@rpc("authority", "call_local", "unreliable_ordered")
func _rpc_sync(pos: Vector2, rot: float) -> void:
	if not is_multiplayer_authority():
		global_position = pos
		rotation = rot

@rpc("authority", "call_local", "reliable")
func _rpc_fire(pos: Vector2, angle: float) -> void:
	AudioManager.play_shoot()
	var b = BULLET_SCENE.instantiate()
	b.global_position = pos + Vector2(cos(angle), sin(angle)) * 28.0
	b.direction = Vector2(cos(angle), sin(angle))
	b.owner_id = player_id
	b.can_pierce = can_pierce
	b.damage = 20
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.add_bullet(b)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp = max(0, hp - amount)
	_hp_bar.value = hp
	_flash()
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	visible = false
	died.emit(player_id)

func _flash() -> void:
	var tw = create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.05)
	tw.tween_property(_sprite, "modulate", player_color, 0.08)

func apply_powerup(type: String) -> void:
	match type:
		"SPEED":
			speed_mult += 0.5
		"RAPID":
			fire_rate_mult = min(fire_rate_mult * 2.0, 8.0)
		"ARMOR":
			max_hp = int(max_hp * 1.5)
			hp = max_hp
			_hp_bar.max_value = max_hp
		"PIERCE":
			can_pierce = true

func reset_for_round(start_pos: Vector2) -> void:
	hp = max_hp
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	is_dead = false
	visible = true
	fire_cd = 0.0
	global_position = start_pos
	rotation = 0.0
