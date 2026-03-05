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
var current_level: int = 1

# 金币系统
var gold: int = 0
var gold_per_brick: int = 1

# 弹珠升级
var ball_speed_level: int = 1
var ball_gravity_level: int = 1
var ball_bounce_level: int = 1

# 升级价格
var upgrade_cost: int = 3

# 关卡配置
var level_config = {
	1: {"hp": 80, "min_dmg": 8, "max_dmg": 15, "dmg_per_brick": 5, "rows": 4, "cols": 8},
	2: {"hp": 100, "min_dmg": 10, "max_dmg": 18, "dmg_per_brick": 5, "rows": 5, "cols": 9},
	3: {"hp": 120, "min_dmg": 12, "max_dmg": 20, "dmg_per_brick": 6, "rows": 5, "cols": 10},
	4: {"hp": 150, "min_dmg": 15, "max_dmg": 25, "dmg_per_brick": 6, "rows": 6, "cols": 10},
	5: {"hp": 180, "min_dmg": 18, "max_dmg": 30, "dmg_per_brick": 7, "rows": 6, "cols": 11},
}

var enemy_damage_per_brick: int = 5
var enemy_min_damage: int = 8
var has_upgraded_this_level: bool = false
var enemy_max_damage: int = 15

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
		{"pos": Vector2(0, screen_size.y/2), "size": Vector2(10, screen_size.y)},
		{"pos": Vector2(screen_size.x, screen_size.y/2), "size": Vector2(10, screen_size.y)},
		{"pos": Vector2(screen_size.x/2, 0), "size": Vector2(screen_size.x, 10)},
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

	# Gold label
	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.position = Vector2(150, 20)
	gold_label.text = "Gold: 0"
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	add_child(gold_label)

	# Level label
	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.position = Vector2(20, 50)
	level_label.text = "Level: 1"
	level_label.add_theme_font_size_override("font_size", 18)
	add_child(level_label)

	# Player HP bar background
	var hp_bg = ColorRect.new()
	hp_bg.name = "HPBarBG"
	hp_bg.position = Vector2(20, 80)
	hp_bg.size = Vector2(200, 20)
	hp_bg.color = Color(0.2, 0.2, 0.2)
	add_child(hp_bg)

	# Player HP bar
	var hp_bar = ColorRect.new()
	hp_bar.name = "HPBar"
	hp_bar.position = Vector2(20, 80)
	hp_bar.size = Vector2(200, 20)
	hp_bar.color = Color(0.2, 0.8, 0.2)
	add_child(hp_bar)

	# HP text
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector2(230, 80)
	hp_label.text = "HP: 100/100"
	hp_label.add_theme_font_size_override("font_size", 18)
	add_child(hp_label)

	# Upgrade info
	var upgrade_label = Label.new()
	upgrade_label.name = "UpgradeLabel"
	upgrade_label.position = Vector2(20, 110)
	upgrade_label.text = "Speed Lv.1 | Gravity Lv.1 | Bounce Lv.1"
	upgrade_label.add_theme_font_size_override("font_size", 14)
	add_child(upgrade_label)

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
	turn_label.position = Vector2(screen_size.x / 2 - 50, 80)
	turn_label.text = "YOUR TURN"
	turn_label.add_theme_font_size_override("font_size", 20)
	turn_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	add_child(turn_label)

	# Shop panel (hidden by default)
	_create_shop_panel()

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

func _create_shop_panel() -> void:
	var panel = PanelContainer.new()
	panel.name = "ShopPanel"
	panel.position = Vector2(screen_size.x/2 - 200, screen_size.y/2 - 100)
	panel.size = Vector2(400, 200)
	panel.visible = false

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "SHOP - Choose Upgrade"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# Upgrade speed button
	var speed_btn = Button.new()
	speed_btn.name = "SpeedBtn"
	speed_btn.text = "Upgrade Speed (3 Gold)"
	speed_btn.pressed.connect(_on_upgrade_speed)
	vbox.add_child(speed_btn)

	# Upgrade gravity button
	var gravity_btn = Button.new()
	gravity_btn.name = "GravityBtn"
	gravity_btn.text = "Upgrade Bounce (3 Gold)"
	gravity_btn.pressed.connect(_on_upgrade_bounce)
	vbox.add_child(gravity_btn)

	# Heal button
	var heal_btn = Button.new()
	heal_btn.name = "HealBtn"
	heal_btn.text = "Heal 25% HP (3 Gold)"
	heal_btn.pressed.connect(_on_heal)
	vbox.add_child(heal_btn)

	# Skip button
	var skip_btn = Button.new()
	skip_btn.name = "SkipBtn"
	skip_btn.text = "Skip (Start Next Level)"
	skip_btn.pressed.connect(_on_skip_upgrade)
	vbox.add_child(skip_btn)

	add_child(panel)

func _start_game() -> void:
	_apply_level_config()
	_create_bricks()
	_reset_ball()
	_update_enemy_hp_bar()
	is_player_turn = true
	_update_turn_label()

func _apply_level_config() -> void:
	var config = level_config.get(current_level, level_config[5])
	enemy.max_hp = config.hp
	enemy.current_hp = config.hp
	enemy_min_damage = config.min_dmg
	enemy_max_damage = config.max_dmg
	enemy_damage_per_brick = config.dmg_per_brick
	brick_rows = config.rows
	brick_cols = config.cols

	_update_level_label()
	_apply_ball_upgrades()

func _apply_ball_upgrades() -> void:
	# Speed upgrade: +50 per level
	ball.speed = 200.0 + (ball_speed_level - 1) * 50
	# Gravity upgrade: -50 per level (lower = less gravity = slower fall)
	ball.gravity = 980.0 - (ball_gravity_level - 1) * 50
	# Bounce upgrade: +0.05 per level
	ball.bounce_coefficient = 0.75 + (ball_bounce_level - 1) * 0.05

func _create_bricks() -> void:
	var screen_size = get_viewport_rect().size
	var center_x = screen_size.x / 2
	var start_y = screen_size.y - 250.0
	var spacing = 30.0

	var colors = [
		Color(0.9, 0.3, 0.3),
		Color(0.9, 0.6, 0.3),
		Color(0.9, 0.9, 0.3),
		Color(0.3, 0.9, 0.3),
		Color(0.3, 0.6, 0.9),
		Color(0.6, 0.3, 0.9)
	]

	brick_count = 0

	# Different layouts for each level
	match current_level:
		1: _create_level1_bricks(center_x, start_y, spacing, colors)
		2: _create_level2_bricks(center_x, start_y, spacing, colors)
		3: _create_level3_bricks(center_x, start_y, spacing, colors)
		4: _create_level4_bricks(center_x, start_y, spacing, colors)
		5: _create_level5_bricks(center_x, start_y, spacing, colors)

func _create_level1_bricks(cx: float, start_y: float, spacing: float, colors: Array) -> void:
	# 简单的网格布局
	for row in range(3):
		for col in range(8):
			_spawn_brick(cx - 3.5 * spacing + col * spacing, start_y + row * spacing, colors[row % 3], 30 - row * 5)

func _create_level2_bricks(cx: float, start_y: float, spacing: float, colors: Array) -> void:
	# 菱形布局
	for row in range(5):
		var cols = 6 if row % 2 == 0 else 5
		var offset = spacing / 2 if row % 2 == 1 else 0
		for col in range(cols):
			_spawn_brick(cx - (cols - 1) * spacing / 2 + col * spacing + offset, start_y + row * spacing, colors[row % 5], 40 - row * 5)

func _create_level3_bricks(cx: float, start_y: float, spacing: float, colors: Array) -> void:
	# V形布局
	for row in range(5):
		for col in range(8 - row):
			var offset = row * spacing / 2
			_spawn_brick(cx - (8 - row - 1) * spacing / 2 + col * spacing, start_y + row * spacing, colors[row % 5], 50 - row * 5)

func _create_level4_bricks(cx: float, start_y: float, spacing: float, colors: Array) -> void:
	# 圆形/环形布局
	for i in range(12):
		var angle = i * TAU / 12 - PI / 2
		var radius = 80.0
		_spawn_brick(cx + cos(angle) * radius, start_y + sin(angle) * radius * 0.6 + 50, colors[i % 5], 40)

	# 中心
	_spawn_brick(cx, start_y + 50, colors[0], 50)

func _create_level5_bricks(cx: float, start_y: float, spacing: float, colors: Array) -> void:
	# 波浪形布局
	for row in range(6):
		for col in range(10):
			var wave_offset = sin(col * 0.6) * 20
			_spawn_brick(cx - 4.5 * spacing + col * spacing, start_y + row * spacing + wave_offset, colors[row % 5], 60 - row * 5)

func _spawn_brick(x: float, y: float, color: Color, points: int) -> void:
	var brick = Brick.new()
	brick.position = Vector2(x, y)
	brick.color = color
	brick.points_value = points
	brick.is_gold = randf() < 0.15
	brick.destroyed.connect(_on_brick_destroyed)
	if brick.is_gold:
		brick.gold_collected.connect(_on_gold_collected)
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

func _on_gold_collected() -> void:
	gold += gold_per_brick
	_update_gold_label()

func _on_enemy_damaged(amount: int) -> void:
	_update_enemy_hp_bar()

func _on_enemy_defeated() -> void:
	_level_completed()

func _on_ball_lost() -> void:
	_end_player_turn()

func _on_hit_brick(brick: Brick) -> void:
	pass

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
	var damage = randi_range(enemy_min_damage, enemy_max_damage)
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

func _update_gold_label() -> void:
	var label = get_node("GoldLabel")
	if label:
		label.text = "Gold: " + str(gold)

func _update_level_label() -> void:
	var label = get_node("LevelLabel")
	if label:
		label.text = "Level: " + str(current_level)

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

func _update_upgrade_label() -> void:
	var label = get_node("UpgradeLabel")
	if label:
		label.text = "Speed Lv.%d | Bounce Lv.%d" % [ball_speed_level, ball_bounce_level]

func _get_hp_color(percentage: float) -> Color:
	if percentage > 0.6:
		return Color(0.2, 0.8, 0.2)
	elif percentage > 0.3:
		return Color(0.8, 0.8, 0.2)
	else:
		return Color(0.8, 0.2, 0.2)

func _game_over() -> void:
	is_game_active = false
	current_level = 1
	var label = get_node("GameOverLabel")
	if label:
		label.visible = true

func _level_completed() -> void:
	is_game_active = false

	# Show shop if there are more levels and hasn't upgraded yet
	if current_level < 5 and not has_upgraded_this_level:
		_show_shop()
	else:
		# Skip to next level or win
		if current_level < 5:
			_start_next_level()
		else:
			var label = get_node("WinLabel")
			if label:
				label.visible = true

func _show_shop() -> void:
	var panel = get_node("ShopPanel")
	if panel:
		var vbox = panel.get_child(0)
		# Update button texts with current costs
		var speed_btn = vbox.get_node("SpeedBtn")
		var bounce_btn = vbox.get_node("GravityBtn")
		var heal_btn = vbox.get_node("HealBtn")

		if speed_btn:
			speed_btn.text = "Upgrade Speed Lv.%d (3 Gold)" % (ball_speed_level + 1)
		if bounce_btn:
			bounce_btn.text = "Upgrade Bounce Lv.%d (3 Gold)" % (ball_bounce_level + 1)

		var heal_percent = int(0.25 * max_player_hp)
		if heal_btn:
			heal_btn.text = "Heal %d HP (%d Gold)" % [heal_percent, upgrade_cost]

		panel.visible = true

func _on_upgrade_speed() -> void:
	if gold >= upgrade_cost:
		gold -= upgrade_cost
		ball_speed_level += 1
		_apply_ball_upgrades()
		_update_gold_label()
		_update_upgrade_label()
		_mark_upgrade_done()

func _on_upgrade_bounce() -> void:
	if gold >= upgrade_cost:
		gold -= upgrade_cost
		ball_bounce_level += 1
		_apply_ball_upgrades()
		_update_gold_label()
		_update_upgrade_label()
		_mark_upgrade_done()

func _on_heal() -> void:
	if gold >= upgrade_cost and player_hp < max_player_hp:
		gold -= upgrade_cost
		var heal_amount = int(0.25 * max_player_hp)
		player_hp = min(player_hp + heal_amount, max_player_hp)
		_update_gold_label()
		_update_player_hp_bar()
		_mark_upgrade_done()

func _mark_upgrade_done() -> void:
	has_upgraded_this_level = true
	# Disable all shop buttons
	var panel = get_node("ShopPanel")
	if panel:
		var vbox = panel.get_child(0)
		var speed_btn = vbox.get_node("SpeedBtn")
		var bounce_btn = vbox.get_node("GravityBtn")
		var heal_btn = vbox.get_node("HealBtn")
		var skip_btn = vbox.get_node("SkipBtn")
		if speed_btn:
			speed_btn.disabled = true
		if bounce_btn:
			bounce_btn.disabled = true
		if heal_btn:
			heal_btn.disabled = true
		if skip_btn:
			skip_btn.text = "Continue..."

func _on_skip_upgrade() -> void:
	# Hide shop and start next level
	var panel = get_node("ShopPanel")
	if panel:
		panel.visible = false
	_start_next_level()

func _start_next_level() -> void:
	current_level += 1
	# Show level up message
	var label = Label.new()
	label.name = "LevelUpLabel"
	label.position = Vector2(screen_size.x/2 - 100, screen_size.y/2)
	label.text = "LEVEL " + str(current_level) + "!\nGet Ready!"
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

	await get_tree().create_timer(2.0).timeout

	# Remove level up label
	var old_label = get_node("LevelUpLabel")
	if old_label:
		old_label.queue_free()

	_restart_level()

func _restart_level() -> void:
	has_upgraded_this_level = false

	# Remove old bricks
	var bricks = get_children().filter(func(node): return node is Brick)
	for brick in bricks:
		brick.queue_free()

	# Recreate enemy if needed
	if not enemy or not is_instance_valid(enemy):
		_create_enemy()
	else:
		enemy.current_hp = enemy.max_hp

	_apply_level_config()
	_create_bricks()
	_reset_ball()

	_update_enemy_hp_bar()

	is_player_turn = true
	_update_turn_label()

func _restart_game() -> void:
	score = 0
	gold = 0
	player_hp = max_player_hp
	lives = 3
	current_level = 1
	ball_speed_level = 1
	ball_bounce_level = 1
	is_game_active = true
	bricks_destroyed_this_turn = 0

	# Remove old bricks
	var bricks = get_children().filter(func(node): return node is Brick)
	for brick in bricks:
		brick.queue_free()

	# Hide shop
	var shop = get_node("ShopPanel")
	if shop:
		shop.visible = false

	# Remove level up label if exists
	var level_label = get_node("LevelUpLabel")
	if level_label:
		level_label.queue_free()

	# Recreate enemy if needed
	if not enemy or not is_instance_valid(enemy):
		_create_enemy()
	else:
		enemy.current_hp = enemy.max_hp

	_apply_level_config()
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
	_update_gold_label()
	_update_player_hp_bar()
	_update_enemy_hp_bar()
	_update_upgrade_label()

	is_player_turn = true
	_update_turn_label()

func _input(event: InputEvent) -> void:
	# Disable input when shop is open
	var shop = get_node("ShopPanel")
	if shop and shop.visible:
		if event.is_action_pressed("ui_accept"):
			_on_skip_upgrade()
		return

	if not is_player_turn:
		return

	if event.is_action_pressed("ui_accept"):  # SPACE key
		if player_hp <= 0 or (current_level > 5):
			_restart_game()
		elif not ball.is_active:
			ball.launch(paddle.position)
			_update_start_label(false)

func _update_start_label(visible: bool) -> void:
	var label = get_node("StartLabel")
	if label:
		label.visible = visible
