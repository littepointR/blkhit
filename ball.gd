extends CharacterBody2D
class_name Ball

signal ball_lost()
signal hit_brick(brick: Brick)

@export var radius: float = 10.0
@export var gravity: float = 800.0
@export var bounce_restitution: float = 0.85  # 反弹系数，1为完全弹性
@export var min_bounce_speed: float = 100.0  # 最小反弹速度

var screen_size: Vector2
var is_active: bool = false

func _ready() -> void:
	screen_size = get_viewport_rect().size
	visible = false

	# Create collision shape with physics material
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	add_child(collision_shape)

	# Create visual
	var sprite = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(8):
		var angle = i * TAU / 8
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	sprite.polygon = points
	sprite.color = Color(1.0, 0.4, 0.4)
	add_child(sprite)

func launch(paddle_pos: Vector2) -> void:
	is_active = true
	visible = true
	position = paddle_pos + Vector2(0, 30)
	# Initial velocity downward
	velocity = Vector2(randf_range(-30, 30), 20)

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Apply gravity (constant acceleration)
	velocity.y += gravity * delta

	# Move and handle collisions
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		var normal = collision.get_normal()

		# Calculate reflection with restitution
		var dot = velocity.dot(normal)
		velocity = velocity - 2 * dot * normal
		velocity *= bounce_restitution

		# Ensure minimum bounce speed
		if abs(velocity.y) < min_bounce_speed:
			velocity.y = sign(velocity.y) * min_bounce_speed if velocity.y != 0 else min_bounce_speed

		if collider is Brick:
			collider.hit()
			hit_brick.emit(collider)
		elif collider is Paddle:
			_apply_paddle_bounce(collider.position.x - position.x)

	# Wall bouncing with restitution
	if position.x - radius < 0:
		position.x = radius
		velocity.x = abs(velocity.x) * bounce_restitution
	elif position.x + radius > screen_size.x:
		position.x = screen_size.x - radius
		velocity.x = -abs(velocity.x) * bounce_restitution

	if position.y - radius < 0:
		position.y = radius
		velocity.y = abs(velocity.y) * bounce_restitution

	# Ball lost - fell below screen
	if position.y - radius > screen_size.y:
		is_active = false
		visible = false
		ball_lost.emit()

func _apply_paddle_bounce(offset: float) -> void:
	# Adjust horizontal velocity based on where ball hit paddle
	var max_angle = PI / 4
	var angle_factor = clamp(offset / 50.0, -1.0, 1.0)

	# Convert angle factor to horizontal velocity
	var current_speed = velocity.length()
	var new_horizontal = sin(angle_factor * max_angle) * current_speed
	velocity.x = new_horizontal

func reset() -> void:
	is_active = false
	visible = false
	position = Vector2(screen_size.x / 2, 50)
	velocity = Vector2.ZERO
