extends Area2D

const SPRITE_SIZE:   int   = 32
const SPRITE_RADIUS: float = 12.0
const SPRITE_SCALE:  float = 0.8
const LIGHT_SIZE:    int   = 64
const LIGHT_ENERGY:  float = 2.5
const LIGHT_SCALE:   float = 0.6
const COL_RADIUS:    float = 6.0
const LIFE_TIME:     float = 3.0
const COLOR_BODY:    Color = Color(1.0, 1.0, 0.3)
const COLOR_LIGHT:   Color = Color(1.0, 1.0, 0.2)

# レーザービーム定数
const LASER_W:     int   = 40
const LASER_H:     int   = 6
const LASER_COLOR: Color = Color(0.3, 1.0, 1.0)
const LASER_LIGHT_ENERGY: float = 3.5
const TRAIL_MAX:   int   = 14

var direction: Vector2 = Vector2.RIGHT
var owner_id: int = 1
var can_pierce: bool = false
var damage: int = 20
var is_laser: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _light: PointLight2D = $PointLight2D
@onready var _col: CollisionShape2D = $CollisionShape2D

var _hit_players: Array = []
var _trail: Line2D = null
var _trail_pts: Array[Vector2] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_visuals()
	var t := get_tree().create_timer(LIFE_TIME)
	t.timeout.connect(_cleanup)
	if is_laser:
		_setup_trail()

func _setup_visuals() -> void:
	if is_laser:
		_setup_laser_visuals()
	else:
		_setup_normal_visuals()

func _setup_normal_visuals() -> void:
	var img = Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	var half = SPRITE_SIZE * 0.5
	for x in range(SPRITE_SIZE):
		for y in range(SPRITE_SIZE):
			var d = Vector2(x - half, y - half).length()
			var a = clamp(1.0 - d / SPRITE_RADIUS, 0.0, 1.0)
			img.set_pixel(x, y, Color(COLOR_BODY.r, COLOR_BODY.g, COLOR_BODY.b, a))
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)

	var light_img = Image.create(LIGHT_SIZE, LIGHT_SIZE, false, Image.FORMAT_RGBA8)
	var light_half = LIGHT_SIZE * 0.5
	for x in range(LIGHT_SIZE):
		for y in range(LIGHT_SIZE):
			var d = Vector2(x - light_half, y - light_half).length()
			var a = clamp(1.0 - d / light_half, 0.0, 1.0)
			light_img.set_pixel(x, y, Color(COLOR_LIGHT.r, COLOR_LIGHT.g, COLOR_LIGHT.b, a))
	_light.texture = ImageTexture.create_from_image(light_img)
	_light.color   = COLOR_LIGHT
	_light.energy  = LIGHT_ENERGY
	_light.texture_scale = LIGHT_SCALE

	var shape = CircleShape2D.new()
	shape.radius = COL_RADIUS
	_col.shape = shape

func _setup_laser_visuals() -> void:
	# 細長いビーム形状（弾方向に回転）
	rotation = direction.angle()
	var img = Image.create(LASER_W, LASER_H, false, Image.FORMAT_RGBA8)
	var cy = LASER_H * 0.5
	for x in range(LASER_W):
		for y in range(LASER_H):
			var dy = abs(y - cy)
			var fade = clamp(1.0 - float(x) / float(LASER_W) * 0.25, 0.75, 1.0)
			var a = clamp(1.0 - dy / cy, 0.0, 1.0) * fade
			img.set_pixel(x, y, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, a))
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.scale = Vector2.ONE

	var light_img = Image.create(LIGHT_SIZE, LIGHT_SIZE, false, Image.FORMAT_RGBA8)
	var lh = LIGHT_SIZE * 0.5
	for x in range(LIGHT_SIZE):
		for y in range(LIGHT_SIZE):
			var d = Vector2(x - lh, y - lh).length()
			var a = clamp(1.0 - d / lh, 0.0, 1.0)
			light_img.set_pixel(x, y, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, a))
	_light.texture = ImageTexture.create_from_image(light_img)
	_light.color   = LASER_COLOR
	_light.energy  = LASER_LIGHT_ENERGY
	_light.texture_scale = 0.9

	var shape = CircleShape2D.new()
	shape.radius = COL_RADIUS
	_col.shape = shape

func _setup_trail() -> void:
	_trail = Line2D.new()
	_trail.width = 3.5
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode   = Line2D.LINE_CAP_NONE
	var grad = Gradient.new()
	grad.set_color(0, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.85))
	grad.set_color(1, Color(LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, 0.0))
	_trail.gradient = grad
	get_parent().add_child(_trail)

func _physics_process(delta: float) -> void:
	global_position += direction * GameConfig.bullet_speed * delta
	if is_instance_valid(_trail):
		_trail_pts.push_front(global_position)
		if _trail_pts.size() > TRAIL_MAX:
			_trail_pts.pop_back()
		_trail.points = PackedVector2Array(_trail_pts)

func _cleanup() -> void:
	if is_instance_valid(_trail):
		_trail.queue_free()
	queue_free()

func _on_body_entered(body: Node) -> void:
	if body == self:
		return
	if "player_id" in body and body.has_method("take_damage") and body.player_id != owner_id:
		if body in _hit_players:
			return
		_hit_players.append(body)
		body.take_damage(damage)
		AudioManager.play_hit()
		if not can_pierce:
			_cleanup()
	elif not ("player_id" in body):
		AudioManager.play_wall_hit()
		if not can_pierce:
			_cleanup()
