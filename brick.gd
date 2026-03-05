extends StaticBody2D
class_name Brick

signal destroyed(points: int)

@export var width: float = 60.0
@export var height: float = 25.0
@export var points_value: int = 10
@export var color: Color = Color(0.3, 0.8, 0.3)

var is_destroyed: bool = false

func _ready() -> void:
	# Create collision shape
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width - 2, height - 2)
	collision_shape.shape = shape
	add_child(collision_shape)

	# Create visual
	var sprite = Polygon2D.new()
	var points_arr = PackedVector2Array([
		Vector2(-width/2, -height/2),
		Vector2(width/2, -height/2),
		Vector2(width/2 - 2, height/2 - 2),
		Vector2(-width/2 + 2, height/2 - 2)
	])
	sprite.polygon = points_arr
	sprite.color = color
	add_child(sprite)

	# Add border
	var border = Line2D.new()
	border.add_point(Vector2(-width/2, -height/2))
	border.add_point(Vector2(width/2, -height/2))
	border.add_point(Vector2(width/2 - 2, height/2 - 2))
	border.add_point(Vector2(-width/2 + 2, height/2 - 2))
	border.add_point(Vector2(-width/2, -height/2))
	border.width = 2
	border.default_color = Color(0.1, 0.1, 0.1)
	add_child(border)

func hit() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	destroyed.emit(points_value)
	queue_free()
