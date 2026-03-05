extends StaticBody2D
class_name Enemy

signal damaged(amount: int)
signal defeated()

@export var max_hp: int = 100
@export var width: float = 200.0
@export var height: float = 30.0

var current_hp: int
var screen_size: Vector2
var target_position: Vector2
var is_moving: bool = false

func _ready() -> void:
	screen_size = get_viewport_rect().size
	current_hp = max_hp

	# Create collision shape
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision_shape.shape = shape
	add_child(collision_shape)

	# Create visual (enemy ship)
	_create_ship_visual()

	# Position at bottom
	position = Vector2(screen_size.x / 2, screen_size.y - 80)

func _create_ship_visual() -> void:
	# Main body
	var body = Polygon2D.new()
	var points = PackedVector2Array([
		Vector2(-width/2, -height/2),
		Vector2(width/2, -height/2),
		Vector2(width/2 - 20, height/2),
		Vector2(-width/2 + 20, height/2)
	])
	body.polygon = points
	body.color = Color(0.8, 0.2, 0.2)
	add_child(body)

	# Cockpit
	var cockpit = Polygon2D.new()
	var cockpit_points = PackedVector2Array([
		Vector2(-20, -height/2 + 5),
		Vector2(20, -height/2 + 5),
		Vector2(15, height/2 - 5),
		Vector2(-15, height/2 - 5)
	])
	cockpit.polygon = cockpit_points
	cockpit.color = Color(0.3, 0.3, 0.8)
	add_child(cockpit)

func take_damage(amount: int) -> void:
	current_hp -= amount
	damaged.emit(amount)
	_flash_damage()

	if current_hp <= 0:
		current_hp = 0
		defeated.emit()
		queue_free()

func _flash_damage() -> void:
	var sprite = get_child(1) as Polygon2D
	if sprite:
		var original_color = sprite.color
		sprite.color = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		sprite.color = original_color

func get_hp_percentage() -> float:
	return float(current_hp) / float(max_hp)
