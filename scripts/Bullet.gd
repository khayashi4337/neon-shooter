extends Area2D

const SPEED = 520.0

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
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(queue_free)

func _setup_visuals() -> void:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for x in range(32):
		for y in range(32):
			var d = Vector2(x - 16, y - 16).length()
			var a = clamp(1.0 - d / 12.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 0.3, a))
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.scale = Vector2(0.8, 0.8)

	var light_img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var d = Vector2(x - 32, y - 32).length()
			var a = clamp(1.0 - d / 32.0, 0.0, 1.0)
			light_img.set_pixel(x, y, Color(1.0, 1.0, 0.2, a))
	_light.texture = ImageTexture.create_from_image(light_img)
	_light.color = Color(1.0, 1.0, 0.2, 1.0)
	_light.energy = 2.5
	_light.texture_scale = 0.6

	var shape = CircleShape2D.new()
	shape.radius = 6.0
	_col.shape = shape

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta

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
		if not can_pierce:
			queue_free()
