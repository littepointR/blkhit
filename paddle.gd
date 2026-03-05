extends StaticBody2D
class_name Paddle

signal scored(points: int)

@export var speed: float = 500.0
@export var width: float = 100.0
@export var height: float = 20.0

var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport_rect().size
	collision_layer = 1

	# Create collision shape
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision_shape.shape = shape
	add_child(collision_shape)

	# Create visual
	var sprite = Polygon2D.new()
	var points = PackedVector2Array([
		Vector2(-width/2, -height/2),
		Vector2(width/2, -height/2),
		Vector2(width/2, height/2),
		Vector2(-width/2, height/2)
	])
	sprite.polygon = points
	sprite.color = Color(0.2, 0.6, 1.0)
	add_child(sprite)

	position = Vector2(screen_size.x / 2, 50)

func _physics_process(delta: float) -> void:
	var direction = 0.0

	if Input.is_action_pressed("move_left"):
		direction = -1.0
	elif Input.is_action_pressed("move_right"):
		direction = 1.0

	position.x += direction * speed * delta
	position.x = clamp(position.x, width/2, screen_size.x - width/2)
