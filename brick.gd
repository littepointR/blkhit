extends StaticBody2D
class_name Brick

signal destroyed(points: int)
signal gold_collected()

@export var radius: float = 12.0
@export var points_value: int = 10
@export var color: Color = Color(0.3, 0.8, 0.3)
@export var is_gold: bool = false

var is_destroyed: bool = false

func _ready() -> void:
	collision_layer = 1

	# Create collision shape (circle)
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	add_child(collision_shape)

	# Create visual (circle)
	var sprite = Polygon2D.new()
	var points = PackedVector2Array()
	var segments = 16
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	sprite.polygon = points

	if is_gold:
		sprite.color = Color(1.0, 0.84, 0.0)  # 金色
		# Add shine
		var shine = Polygon2D.new()
		var shine_points = PackedVector2Array()
		for i in range(6):
			var angle = -PI/4 + i * TAU / 12
			shine_points.append(Vector2(cos(angle), sin(angle)) * radius * 0.5)
		shine.polygon = shine_points
		shine.color = Color(1.0, 1.0, 0.8)
		add_child(shine)
	else:
		sprite.color = color
	add_child(sprite)

func hit() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	destroyed.emit(points_value)

	if is_gold:
		gold_collected.emit()

	queue_free()
