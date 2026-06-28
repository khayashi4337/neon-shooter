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

var direction: Vector2 = Vector2.RIGHT
var owner_id: int = 1
var can_pierce: bool = false
var damage: int = 20

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _light: PointLight2D = $PointLight2D
@onready var _col: CollisionShape2D = $CollisionShape2D

var _hit_players: Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_visuals()
	var t := get_tree().create_timer(LIFE_TIME)
	t.timeout.connect(queue_free)

func _setup_visuals() -> void:
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

func _physics_process(delta: float) -> void:
	global_position += direction * GameConfig.bullet_speed * delta

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
			queue_free()
	elif not ("player_id" in body):
		AudioManager.play_wall_hit()
		if not can_pierce:
			queue_free()
