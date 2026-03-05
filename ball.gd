extends CharacterBody2D
class_name Ball

signal ball_lost()
signal hit_brick(brick: Brick)

@export var radius: float = 10.0
@export var gravity: float = 980.0  # 接近真实重力
@export var bounce_coefficient: float = 0.75  # 反弹系数（能量保留）
@export var friction: float = 0.99  # 空气阻力
@export var speed: float = 200.0  # 弹珠速度上限

var screen_size: Vector2
var is_active: bool = false

func _ready() -> void:
	screen_size = get_viewport_rect().size
	visible = false
	# 只与 Brick 和 Paddle 碰撞，不与 Enemy 碰撞
	collision_layer = 1
	collision_mask = 1  # 只检测 layer 1

	# Create collision shape
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
	# 初始向下发射，带微小水平偏移
	velocity = Vector2(randf_range(-20, 20), 10)

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# 应用重力
	velocity.y += gravity * delta

	# 应用空气阻力
	velocity *= friction

	# 移动并处理碰撞
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		var normal = collision.get_normal()

		# 计算相对速度在碰撞法线方向的分量
		var relative_velocity = velocity.dot(normal)

		# 只在朝向碰撞体运动时反弹
		if relative_velocity < 0:
			# 反弹公式: v' = v - (1 + e) * (v · n) * n
			# e 是恢复系数
			var impulse = -(1 + bounce_coefficient) * relative_velocity
			velocity += normal * impulse

			# 碰撞时能量损失
			velocity *= bounce_coefficient

		if collider is Brick:
			collider.hit()
			hit_brick.emit(collider)
		elif collider is Paddle:
			_apply_paddle_bounce(collider.position.x - position.x)

	# 墙壁反弹（带能量损失）
	if position.x - radius < 0:
		position.x = radius
		velocity.x = abs(velocity.x) * bounce_coefficient
	elif position.x + radius > screen_size.x:
		position.x = screen_size.x - radius
		velocity.x = -abs(velocity.x) * bounce_coefficient

	if position.y - radius < 0:
		position.y = radius
		velocity.y = abs(velocity.y) * bounce_coefficient

	# 球掉出屏幕
	if position.y - radius > screen_size.y:
		is_active = false
		visible = false
		ball_lost.emit()

func _apply_paddle_bounce(offset: float) -> void:
	# 根据击中挡板的位置调整水平速度
	var max_offset = 50.0
	var normalized_offset = clamp(offset / max_offset, -1.0, 1.0)

	# 击中挡板边缘会产生更大的水平速度
	var current_speed = velocity.length()
	# 确保最小反弹速度
	current_speed = max(current_speed, speed)

	velocity.x = normalized_offset * current_speed * 0.8
	# 确保向下反弹
	velocity.y = abs(velocity.y) * bounce_coefficient

func reset() -> void:
	is_active = false
	visible = false
	position = Vector2(screen_size.x / 2, 50)
	velocity = Vector2.ZERO
