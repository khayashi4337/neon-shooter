extends CharacterBody2D

const BULLET_SCENE = preload("res://scenes/Bullet.tscn")

# --- ビジュアル定数 ---
const SPRITE_SIZE:    int   = 48
const SPRITE_RADIUS:  float = 20.0
const SPRITE_EDGE:    float = 3.0
const LIGHT_SIZE:     int   = 128
const COL_RADIUS:     float = 18.0
const GUN_LENGTH:     int   = 18
const GUN_HEIGHT:     int   = 6
const GUN_OFFSET_X:   float = 30.0
const EYE_SIZE:       int   = 8
const EYE_PUPIL_R:   float = 2.5
const EYE_WHITE_R:   float = 3.8
const EYE_OFFSET_X:  float = 11.0
const EYE_OFFSET_Y:  float = 7.0

# --- 入力定数 ---
const PAD_DEADZONE:          float = 0.2
const PAD_TRIGGER_THRESHOLD: float = 0.5

# --- 弾定数 ---
const BULLET_DAMAGE: int  = 20
const AMMO_MAX:    int    = 12
const RELOAD_TIME: float  = 2.5

# --- CPU AI 定数 ---
const CPU_IDEAL_DIST:          float = 260.0
const CPU_DIST_MARGIN:         float = 80.0
const CPU_SPEED_RATIO:         float = 0.82
const CPU_FIRE_RANGE:          float = 450.0
const CPU_JITTER_INTERVAL_MIN: float = 1.2
const CPU_JITTER_INTERVAL_MAX: float = 2.8
const CPU_JITTER_AMP:          float = 0.4
const CPU_ORBIT_FLIP_CHANCE:   float = 0.25

# --- CPU AI 戦術定数 ---
const CPU_EVADE_LATERAL:       float = 70.0   # 射線上とみなす横幅（px）
const CPU_PIERCE_IDEAL_DIST:   float = 380.0  # PIERCE：遠距離ポジション
const CPU_PIERCE_FIRE_RANGE:   float = 600.0  # PIERCE：射程延長
const CPU_SPEED_IDEAL_DIST:    float = 200.0  # SPEED：側面接近
const CPU_RAPID_IDEAL_DIST:    float = 160.0  # RAPID：弾幕接近
const CPU_ARMOR_IDEAL_DIST:    float = 120.0  # ARMOR2回以上：積極突進

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
var _damage_mult: float = 1.0
var _ammo: int = 0
var _reload_timer: float = 0.0

var is_cpu: bool = false
var _cpu_target: Node2D = null
var _cpu_orbit_dir: float = 1.0
var _cpu_jitter_timer: float = 0.0
var _cpu_jitter: Vector2 = Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _light: PointLight2D = $PointLight2D
@onready var _col: CollisionShape2D = $CollisionShape2D
@onready var _hp_bar: ProgressBar = $HPBar

signal died(player_id: int)
signal ammo_changed(player_id: int, ammo: int, is_reloading: bool)

func _ready() -> void:
	SPEED_BASE     = GameConfig.player_speed
	FIRE_RATE_BASE = GameConfig.fire_rate
	hp             = GameConfig.player_hp
	max_hp         = GameConfig.player_hp
	_ammo          = AMMO_MAX
	# CPUプレイヤーは常にサーバー（id=1）が制御
	set_multiplayer_authority(1 if is_cpu else player_id)
	_setup_visuals()

func _setup_visuals() -> void:
	_sprite.texture  = _make_circle_texture(SPRITE_SIZE, SPRITE_RADIUS, SPRITE_EDGE, player_color)
	_light.texture   = _make_light_texture(LIGHT_SIZE)
	_light.color     = player_color
	_light.energy    = 1.8
	_light.texture_scale = 1.0

	var cs = CircleShape2D.new()
	cs.radius = COL_RADIUS
	_col.shape = cs

	# 銃口インジケーター
	var gun = Sprite2D.new()
	gun.texture  = _make_gun_texture()
	gun.position = Vector2(GUN_OFFSET_X, 0.0)
	add_child(gun)

	# 目（前方方向に追従）
	var eye_tex = _make_eye_texture()
	for sign in [-1.0, 1.0]:
		var eye = Sprite2D.new()
		eye.texture  = eye_tex
		eye.position = Vector2(EYE_OFFSET_X, sign * EYE_OFFSET_Y)
		add_child(eye)

	# HPバー
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

# --- テクスチャ生成ヘルパー ---

func _make_circle_texture(size: int, radius: float, edge: float, col: Color) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = size * 0.5
	for x in range(size):
		for y in range(size):
			var d = Vector2(x - center, y - center).length()
			if d < radius:
				var a = clamp((radius - d) / edge, 0.0, 1.0)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)

func _make_light_texture(size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = size * 0.5
	for x in range(size):
		for y in range(size):
			var d = Vector2(x - center, y - center).length()
			var a = clamp(1.0 - d / center, 0.0, 1.0) * 0.85
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _make_gun_texture() -> ImageTexture:
	var img = Image.create(GUN_LENGTH, GUN_HEIGHT, false, Image.FORMAT_RGBA8)
	for gx in range(GUN_LENGTH):
		for gy in range(GUN_HEIGHT):
			var alpha = lerp(1.0, 0.3, float(gx) / GUN_LENGTH)
			img.set_pixel(gx, gy, Color(player_color.r, player_color.g, player_color.b, alpha))
	return ImageTexture.create_from_image(img)

func _make_eye_texture() -> ImageTexture:
	var img = Image.create(EYE_SIZE, EYE_SIZE, false, Image.FORMAT_RGBA8)
	var center = EYE_SIZE * 0.5
	for ex in range(EYE_SIZE):
		for ey in range(EYE_SIZE):
			var d = Vector2(ex - center, ey - center).length()
			if d < EYE_PUPIL_R:
				img.set_pixel(ex, ey, Color(0.05, 0.05, 0.05, 1.0))
			elif d < EYE_WHITE_R:
				img.set_pixel(ex, ey, Color(1.0, 1.0, 1.0, 1.0 - (d - EYE_PUPIL_R) / (EYE_WHITE_R - EYE_PUPIL_R)))
	return ImageTexture.create_from_image(img)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	fire_cd -= delta
	if is_multiplayer_authority() and _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_reload_timer = 0.0
			_ammo = AMMO_MAX
			ammo_changed.emit(player_id, _ammo, false)
	if is_cpu:
		if is_multiplayer_authority():
			_handle_cpu(delta)
			_rpc_sync.rpc(global_position, rotation)
	elif is_multiplayer_authority():
		_handle_input()
		_rpc_sync.rpc(global_position, rotation)

func _handle_input() -> void:
	var cfg_device = GameConfig.p1_device if player_id == 1 else GameConfig.p2_device
	var pad_id     = GameConfig.p1_gamepad_id if player_id == 1 else GameConfig.p2_gamepad_id
	# パッドが接続されていなければキーボードにフォールバック
	var use_pad = (cfg_device == "gamepad" and pad_id in Input.get_connected_joypads())

	# 移動
	var dir: Vector2
	if use_pad:
		dir = Vector2(Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_X),
		              Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_Y))
		if dir.length() < PAD_DEADZONE:
			dir = Vector2.ZERO
	else:
		# WASD（move_*）+ カーソルキー（ui_*）の両方を受け付ける
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED_BASE * speed_mult
	move_and_slide()

	# 照準
	if use_pad:
		var aim = Vector2(Input.get_joy_axis(pad_id, JOY_AXIS_RIGHT_X),
		                  Input.get_joy_axis(pad_id, JOY_AXIS_RIGHT_Y))
		if aim.length() > PAD_DEADZONE:
			rotation = aim.angle()
	else:
		rotation = (get_global_mouse_position() - global_position).angle()

	# 射撃
	var firing: bool
	if use_pad:
		firing = (Input.get_joy_axis(pad_id, JOY_AXIS_TRIGGER_RIGHT) > PAD_TRIGGER_THRESHOLD
		          or Input.is_joy_button_pressed(pad_id, JOY_BUTTON_RIGHT_SHOULDER))
	else:
		firing = Input.is_action_pressed("shoot" if player_id == 1 else "shoot_p2")
	if firing and fire_cd <= 0.0:
		if _ammo <= 0 or _reload_timer > 0.0:
			AudioManager.play_dry_fire()
			fire_cd = 0.4
		else:
			fire_cd = FIRE_RATE_BASE / fire_rate_mult
			_ammo -= 1
			_rpc_fire.rpc(global_position, rotation)
			if _ammo <= 0:
				_reload_timer = RELOAD_TIME
				ammo_changed.emit(player_id, 0, true)
			else:
				ammo_changed.emit(player_id, _ammo, false)

func _handle_cpu(delta: float) -> void:
	# ターゲット（相手）を探す
	if not is_instance_valid(_cpu_target) or _cpu_target.is_dead:
		var game = get_tree().get_first_node_in_group("game")
		if game:
			for p in game._players.values():
				if p != self and not p.is_dead:
					_cpu_target = p
					break
	if not is_instance_valid(_cpu_target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target = _cpu_target.global_position - global_position
	var dist = to_target.length()

	# 照準：常に相手を向く
	rotation = to_target.angle()

	# ジッター：一定間隔で動きをランダムに変える（予測不能に）
	_cpu_jitter_timer -= delta
	if _cpu_jitter_timer <= 0.0:
		_cpu_jitter_timer = randf_range(CPU_JITTER_INTERVAL_MIN, CPU_JITTER_INTERVAL_MAX)
		_cpu_jitter = Vector2(randf_range(-CPU_JITTER_AMP, CPU_JITTER_AMP),
		                      randf_range(-CPU_JITTER_AMP, CPU_JITTER_AMP))
		if randf() < CPU_ORBIT_FLIP_CHANCE:
			_cpu_orbit_dir *= -1.0

	# --- パワーアップ別の理想距離と射程 ---
	var ideal_dist: float = CPU_IDEAL_DIST
	var fire_range: float = CPU_FIRE_RANGE
	if can_pierce:
		# PIERCE：遠距離から壁越し射撃 → 射程延長・遠距離ポジション
		ideal_dist = CPU_PIERCE_IDEAL_DIST
		fire_range = CPU_PIERCE_FIRE_RANGE
	elif max_hp > GameConfig.player_hp:
		# ARMOR：取得回数が多いほど積極的、HP瀕死時のみ守り
		var hp_ratio = float(hp) / float(max_hp)
		var armor_level = max_hp / GameConfig.player_hp  # 2=1回, 4=2回
		if hp_ratio < 0.3:
			ideal_dist = CPU_PIERCE_IDEAL_DIST  # HP瀕死 → 遠距離で守り
		elif armor_level >= 4:
			ideal_dist = CPU_ARMOR_IDEAL_DIST  # 2回以上ARMOR → 要塞化して積極突進
		else:
			ideal_dist = CPU_IDEAL_DIST  # 1回ARMOR → 通常距離
	elif fire_rate_mult > 1.0:
		# RAPID：接近して弾幕を張る
		ideal_dist = CPU_RAPID_IDEAL_DIST
	elif speed_mult > 1.0:
		# SPEED：素早く側面に回り込む
		ideal_dist = CPU_SPEED_IDEAL_DIST

	# --- 射線回避（プレイヤーの照準を読んで横にステップ） ---
	var aim_dir       = Vector2.from_angle(_cpu_target.rotation)
	var to_cpu_rel    = global_position - _cpu_target.global_position
	var cross_val     = aim_dir.cross(to_cpu_rel)
	var on_aim_line   = (abs(cross_val) < CPU_EVADE_LATERAL
	                     and aim_dir.dot(to_cpu_rel) > 0.0)

	# --- 移動 ---
	var dir: Vector2
	if on_aim_line:
		# 射線上 → 横にステップして回避
		var side = sign(cross_val) if cross_val != 0.0 else _cpu_orbit_dir
		dir = aim_dir.rotated(PI * 0.5 * side)
	elif dist > ideal_dist + CPU_DIST_MARGIN:
		dir = to_target.normalized()
	elif dist < ideal_dist - CPU_DIST_MARGIN:
		dir = -to_target.normalized()
	else:
		dir = to_target.normalized().rotated(PI * 0.5 * _cpu_orbit_dir)

	velocity = (dir + _cpu_jitter).normalized() * SPEED_BASE * speed_mult * CPU_SPEED_RATIO
	move_and_slide()

	# --- 射撃：偏差打ち + フェイント ---
	if dist < fire_range and fire_cd <= 0.0 and _ammo > 0 and _reload_timer <= 0.0:
		fire_cd = FIRE_RATE_BASE / fire_rate_mult
		_ammo -= 1
		var aim_angle: float
		var roll = randf()
		if roll < 0.15:
			# フェイント：狙いをわずかにずらす（約20度以内）
			aim_angle = rotation + randf_range(-0.35, 0.35)
		elif roll < 0.50 and is_instance_valid(_cpu_target):
			# 予測射撃：プレイヤーの移動先を狙う
			var time_to_hit = dist / GameConfig.bullet_speed
			var predicted = _cpu_target.global_position + _cpu_target.velocity * time_to_hit * 0.6
			aim_angle = (predicted - global_position).angle()
		else:
			# 通常：現在位置を狙う
			aim_angle = rotation
		_rpc_fire.rpc(global_position, aim_angle)
		if _ammo <= 0:
			_reload_timer = RELOAD_TIME
			ammo_changed.emit(player_id, 0, true)
		else:
			ammo_changed.emit(player_id, _ammo, false)

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
	b.damage = max(1, int(BULLET_DAMAGE * _damage_mult))
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
	AudioManager.play_death()
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
			max_hp = max_hp * 2
			hp = max_hp
			_hp_bar.max_value = max_hp
			_damage_mult = max(0.25, _damage_mult * 0.75)
		"PIERCE":
			can_pierce = true

func reset_for_round(start_pos: Vector2) -> void:
	hp = max_hp
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	is_dead = false
	visible = true
	fire_cd = 0.0
	_ammo = AMMO_MAX
	_reload_timer = 0.0
	global_position = start_pos
	rotation = 0.0
	ammo_changed.emit(player_id, _ammo, false)

func reset_for_new_game(start_pos: Vector2) -> void:
	max_hp        = GameConfig.player_hp
	hp            = max_hp
	speed_mult    = 1.0
	fire_rate_mult = 1.0
	can_pierce    = false
	_damage_mult  = 1.0
	_ammo         = AMMO_MAX
	_reload_timer = 0.0
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	is_dead = false
	visible = true
	fire_cd = 0.0
	global_position = start_pos
	rotation = 0.0
	ammo_changed.emit(player_id, _ammo, false)
