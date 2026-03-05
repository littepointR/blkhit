extends Node2D

signal score_updated(score: int)
signal game_over()
signal level_completed()
signal turn_changed(is_player_turn: bool)

@export var brick_rows: int = 5
@export var brick_cols: int = 10

var screen_size: Vector2
var paddle: Paddle
var ball: Ball
var enemy: Enemy
var score: int = 0
var player_hp: int = 100
var max_player_hp: int = 100
var lives: int = 3
var is_game_active: bool = false
var brick_count: int = 0
var is_player_turn: bool = true
var bricks_destroyed_this_turn: int = 0
var enemy_damage_per_brick: int = 5

func _ready() -> void:
	screen_size = get_viewport_rect().size
	_create_walls()
	_create_paddle()
	_create_ball()
	_create_enemy()
	_create_ui()
	_start_game()

func _create_walls() -> void:
	var screen_size = get_viewport_rect().size

	var walls = [
		{pos = Vector2(0, screen_size.y/2), size = Vector2(10, screen_size.y)},
		{pos = Vector2(screen_size.x, screen_size.y/2), size = Vector2(10, screen_size.y)},
		{pos = Vector2(screen_size.x/2, 0), size = Vector2(screen_size.x, 10)},
	]

	for wall_data in walls:
		var wall = StaticBody2D.new()
		wall.position = wall_data.pos

		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = wall_data.size
		collision.shape = shape
		wall.add_child(collision)

		var polygon = Polygon2D.new()
		polygon.polygon = PackedVector2Array([
			Vector2(-wall_data.size.x/2, -wall_data.size.y/2),
			Vector2(wall_data.size.x/2, -wall_data.size.y/2),
			Vector2(wall_data.size.x/2, wall_data.size.y/2),
			Vector2(-wall_data.size.x/2, wall_data.size.y/2)
		])
		polygon.color = Color(0.3, 0.3, 0.3)
		wall.add_child(polygon)

		add_child(wall)

func _create_paddle() -> void:
	paddle = Paddle.new()
	paddle.scored.connect(_on_paddle_scored)
	add_child(paddle)

func _create_ball() -> void:
	ball = Ball.new()
	ball.ball_lost.connect(_on_ball_lost)
	ball.hit_brick.connect(_on_hit_brick)
	add_child(ball)

func _create_enemy() -> void:
	enemy = Enemy.new()
	enemy.damaged.connect(_on_enemy_damaged)
	enemy.defeated.connect(_on_enemy_defeated)
	add_child(enemy)

func _create_ui() -> void:
	# Score label
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(20, 20)
	score_label.text = "Score: 0"
	score_label.add_theme_font_size_override("font_size", 24)
	add_child(score_label)

	# Player HP bar background
	var hp_bg = ColorRect.new()
	hp_bg.name = "HPBarBG"
	hp_bg.position = Vector2(20, 55)
	hp_bg.size = Vector2(200, 20)
	hp_bg.color = Color(0.2, 0.2, 0.2)
	add_child(hp_bg)

	# Player HP bar
	var hp_bar = ColorRect.new()
	hp_bar.name = "HPBar"
	hp_bar.position = Vector2(20, 55)
	hp_bar.size = Vector2(200, 20)
	hp_bar.color = Color(0.2, 0.8, 0.2)
	add_child(hp_bar)

	# HP text
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector2(230, 55)
	hp_label.text = "HP: 100/100"
	hp_label.add_theme_font_size_override("font_size", 18)
	add_child(hp_label)

	# Enemy HP bar background
	var enemy_hp_bg = ColorRect.new()
	enemy_hp_bg.name = "EnemyHPBarBG"
	enemy_hp_bg.position = Vector2(screen_size.x - 220, 20)
	enemy_hp_bg.size = Vector2(200, 15)
	enemy_hp_bg.color = Color(0.2, 0.2, 0.2)
	add_child(enemy_hp_bg)

	# Enemy HP bar
	var enemy_hp_bar = ColorRect.new()
	enemy_hp_bar.name = "EnemyHPBar"
	enemy_hp_bar.position = Vector2(screen_size.x - 220, 20)
	enemy_hp_bar.size = Vector2(200, 15)
	enemy_hp_bar.color = Color(0.8, 0.2, 0.2)
	add_child(enemy_hp_bar)

	# Lives label
	var lives_label = Label.new()
	lives_label.name = "LivesLabel"
	lives_label.position = Vector2(screen_size.x - 100, 40)
	lives_label.text = "Balls: 3"
	lives_label.add_theme_font_size_override("font_size", 18)
	add_child(lives_label)

	# Turn indicator
	var turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.position = Vector2(screen_size.x / 2 - 50, 55)
	turn_label.text = "YOUR TURN"
	turn_label.add_theme_font_size_override("font_size", 20)
	turn_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	add_child(turn_label)

	# Game over label
	var game_over_label = Label.new()
	game_over_label.name = "GameOverLabel"
	game_over_label.position = Vector2(screen_size.x/2 - 150, screen_size.y/2)
	game_over_label.text = "GAME OVER\nPress SPACE to restart"
	game_over_label.visible = false
	game_over_label.add_theme_font_size_override("font_size", 32)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(game_over_label)

	# Win label
	var win_label = Label.new()
	win_label.name = "WinLabel"
	win_label.position = Vector2(screen_size.x/2 - 100, screen_size.y/2)
	win_label.text = "YOU WIN!\nPress SPACE to restart"
	win_label.visible = false
	win_label.add_theme_font_size_override("font_size", 32)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(win_label)

	# Start prompt
	var start_label = Label.new()
	start_label.name = "StartLabel"
	start_label.position = Vector2(screen_size.x/2 - 120, screen_size.y/2 + 80)
	start_label.text = "Press SPACE to start"
	start_label.add_theme_font_size_override("font_size", 24)
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(start_label)

func _start_game() -> void:
	_create_bricks()
	_reset_ball()
	_update_enemy_hp_bar()
	is_player_turn = true
	_update_turn_label()

func _create_bricks() -> void:
	var screen_size = get_viewport_rect().size
	var brick_width = 60.0
	var brick_height = 25.0
	var spacing = 8.0
	var start_x = (screen_size.x - (brick_cols * (brick_width + spacing))) / 2 + brick_width / 2
	var start_y = screen_size.y - 250.0

	var colors = [
		Color(0.9, 0.3, 0.3),
		Color(0.9, 0.6, 0.3),
		Color(0.9, 0.9, 0.3),
		Color(0.3, 0.9, 0.3),
		Color(0.3, 0.6, 0.9)
	]

	brick_count = 0

	for row in range(brick_rows):
		for col in range(brick_cols):
			var brick = Brick.new()
			brick.position = Vector2(
				start_x + col * (brick_width + spacing),
				start_y + row * (brick_height + spacing)
			)
			brick.color = colors[row % colors.size()]
			brick.points_value = (brick_rows - row) * 10
			brick.destroyed.connect(_on_brick_destroyed)
			add_child(brick)
			brick_count += 1

func _reset_ball() -> void:
	ball.reset()
	ball.position = paddle.position + Vector2(0, 30)

func _on_brick_destroyed(points: int) -> void:
	score += points
	brick_count -= 1
	bricks_destroyed_this_turn += 1
	_update_score_label()

	if brick_count <= 0:
		_level_completed()

func _on_enemy_damaged(amount: int) -> void:
	_update_enemy_hp_bar()

func _on_enemy_defeated() -> void:
	_level_completed()

func _on_ball_lost() -> void:
	# End player turn after ball is lost
	_end_player_turn()

func _on_hit_brick(brick: Brick) -> void:
	# Damage enemy for each brick hit
	if enemy and is_instance_valid(enemy):
		enemy.take_damage(enemy_damage_per_brick)

func _on_paddle_scored(points: int) -> void:
	pass

func _end_player_turn() -> void:
	if not is_player_turn:
		return

	is_player_turn = false

	# Damage enemy based on bricks destroyed this turn
	if enemy and is_instance_valid(enemy):
		var total_damage = bricks_destroyed_this_turn * enemy_damage_per_brick
		if total_damage > 0:
			enemy.take_damage(total_damage)

	bricks_destroyed_this_turn = 0

	# Start enemy turn
	_start_enemy_turn()

func _start_enemy_turn() -> void:
	_update_turn_label()

	# Enemy attacks after delay
	await get_tree().create_timer(1.0).timeout

	# Enemy deals damage to player
	var damage = randi_range(10, 20)
	player_hp -= damage
	if player_hp < 0:
		player_hp = 0

	_update_player_hp_bar()

	if player_hp <= 0:
		_game_over()
		return

	# End enemy turn, start player turn
	await get_tree().create_timer(1.0).timeout
	_start_player_turn()

func _start_player_turn() -> void:
	is_player_turn = true
	_reset_ball()
	_update_turn_label()

func _update_turn_label() -> void:
	var label = get_node("TurnLabel")
	if label:
		if is_player_turn:
			label.text = "YOUR TURN"
			label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		else:
			label.text = "ENEMY TURN"
			label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))

func _update_score_label() -> void:
	var label = get_node("ScoreLabel")
	if label:
		label.text = "Score: " + str(score)

func _update_player_hp_bar() -> void:
	var hp_bar = get_node("HPBar")
	var hp_label = get_node("HPLabel")
	if hp_bar:
		var hp_percentage = float(player_hp) / float(max_player_hp)
		hp_bar.size.x = 200 * hp_percentage
		hp_bar.color = _get_hp_color(hp_percentage)
	if hp_label:
		hp_label.text = "HP: " + str(player_hp) + "/" + str(max_player_hp)

func _update_enemy_hp_bar() -> void:
	var hp_bar = get_node("EnemyHPBar")
	if hp_bar and enemy and is_instance_valid(enemy):
		var hp_percentage = enemy.get_hp_percentage()
		hp_bar.size.x = 200 * hp_percentage

func _get_hp_color(percentage: float) -> Color:
	if percentage > 0.6:
		return Color(0.2, 0.8, 0.2)
	elif percentage > 0.3:
		return Color(0.8, 0.8, 0.2)
	else:
		return Color(0.8, 0.2, 0.2)

func _game_over() -> void:
	is_game_active = false
	var label = get_node("GameOverLabel")
	if label:
		label.visible = true

func _level_completed() -> void:
	is_game_active = false
	var label = get_node("WinLabel")
	if label:
		label.visible = true

func _restart_game() -> void:
	score = 0
	player_hp = max_player_hp
	lives = 3
	is_game_active = true
	bricks_destroyed_this_turn = 0

	# Remove old bricks
	var bricks = get_tree().get_nodes_in_group("bricks")
	for brick in bricks:
		brick.queue_free()

	# Recreate enemy if needed
	if not enemy or not is_instance_valid(enemy):
		_create_enemy()
	else:
		enemy.current_hp = enemy.max_hp

	_create_bricks()
	_reset_ball()

	# Hide game over/win labels
	var game_over_label = get_node("GameOverLabel")
	if game_over_label:
		game_over_label.visible = false

	var win_label = get_node("WinLabel")
	if win_label:
		win_label.visible = false

	_update_score_label()
	_update_player_hp_bar()
	_update_enemy_hp_bar()

	is_player_turn = true
	_update_turn_label()

func _input(event: InputEvent) -> void:
	if not is_player_turn:
		return

	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		if not ball.is_active and lives > 0:
			ball.launch(paddle.position)
			_update_start_label(false)

	if event.is_action_pressed("ui_accept"):  # SPACE key
		if player_hp <= 0 or (enemy and enemy.current_hp <= 0):
			_restart_game()
		elif not ball.is_active:
			ball.launch(paddle.position)
			_update_start_label(false)

func _update_start_label(visible: bool) -> void:
	var label = get_node("StartLabel")
	if label:
		label.visible = visible
