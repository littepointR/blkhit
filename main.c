/**
 * Breakout Game with Raylib
 * A gravity-based breakout game with enemy combat
 */

#include "raylib.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

// Constants
#define SCREEN_WIDTH 800
#define SCREEN_HEIGHT 600
#define MAX_BRICKS 100
#define MAX_LEVELS 5

// Game structures
typedef struct {
    Vector2 position;
    Vector2 velocity;
    float radius;
    float gravity;
    float bounce;
    float friction;
    float speed;
    bool active;
} Ball;

typedef struct {
    Vector2 position;
    float width;
    float height;
    float speed;
} Paddle;

typedef struct {
    Vector2 position;
    float radius;
    int points;
    int value;
    bool is_gold;
    bool destroyed;
} Brick;

typedef struct {
    Vector2 position;
    float width;
    float height;
    int hp;
    int max_hp;
} Enemy;

typedef struct {
    int hp;
    int max_hp;
    int score;
    int gold;
    int level;
    int lives;
    int bricks_destroyed;
    bool is_player_turn;
    bool has_upgraded;
    int ball_speed_level;
    int ball_bounce_level;
} GameState;

typedef struct {
    int enemy_hp;
    int min_damage;
    int max_damage;
    int damage_per_brick;
    int brick_count;
} LevelConfig;

// Forward declarations
void init_level_bricks(int level);
void reset_ball();
void launch_ball();
void end_player_turn();
void level_complete();
void game_over();
void draw_game();

// Global variables
Ball ball;
Paddle paddle;
Brick bricks[MAX_BRICKS];
Enemy enemy;
GameState game;
int brick_count = 0;

// Level configurations
LevelConfig levels[MAX_LEVELS] = {
    {80, 8, 15, 5, 24},
    {100, 10, 18, 5, 30},
    {120, 12, 20, 6, 40},
    {150, 15, 25, 6, 48},
    {180, 18, 30, 7, 60}
};

void init_game() {
    // Initialize game state
    game.hp = 100;
    game.max_hp = 100;
    game.score = 0;
    game.gold = 0;
    game.level = 1;
    game.lives = 3;
    game.bricks_destroyed = 0;
    game.is_player_turn = true;
    game.has_upgraded = false;
    game.ball_speed_level = 1;
    game.ball_bounce_level = 1;

    // Initialize paddle
    paddle.position = (Vector2){SCREEN_WIDTH / 2.0f, 50};
    paddle.width = 100;
    paddle.height = 20;
    paddle.speed = 500;

    // Initialize ball
    ball.position = (Vector2){SCREEN_WIDTH / 2.0f, 100};
    ball.velocity = (Vector2){0, 0};
    ball.radius = 10;
    ball.gravity = 980.0f;
    ball.bounce = 0.75f;
    ball.friction = 0.99f;
    ball.speed = 200.0f;
    ball.active = false;

    // Initialize enemy
    enemy.position = (Vector2){SCREEN_WIDTH / 2.0f, SCREEN_HEIGHT - 80};
    enemy.width = 200;
    enemy.height = 30;
    enemy.hp = levels[game.level - 1].enemy_hp;
    enemy.max_hp = levels[game.level - 1].enemy_hp;

    init_level_bricks(game.level);
}

void reset_ball() {
    ball.position = (Vector2){paddle.position.x, paddle.position.y + 30};
    ball.velocity = (Vector2){0, 0};
    ball.active = false;
}

void launch_ball() {
    ball.active = true;
    ball.velocity = (Vector2){(float)GetRandomValue(-20, 20), 10};
}

// Collision detection
bool check_circle_rect(Vector2 circle, float radius, Rectangle rect) {
    float testX = circle.x;
    float testY = circle.y;

    if (circle.x < rect.x) testX = rect.x;
    else if (circle.x > rect.x + rect.width) testX = rect.x + rect.width;

    if (circle.y < rect.y) testY = rect.y;
    else if (circle.y > rect.y + rect.height) testY = rect.y + rect.height;

    float distX = circle.x - testX;
    float distY = circle.y - testY;
    float distance = sqrtf(distX * distX + distY * distY);

    return distance <= radius;
}

bool check_circle_circle(Vector2 c1, float r1, Vector2 c2, float r2) {
    float dx = c1.x - c2.x;
    float dy = c1.y - c2.y;
    float dist = sqrtf(dx * dx + dy * dy);
    return dist <= r1 + r2;
}

void update_game(float delta) {
    if (!game.is_player_turn) return;

    // Paddle movement
    if (IsKeyDown(KEY_LEFT) || IsKeyDown(KEY_A)) {
        paddle.position.x -= paddle.speed * delta;
    }
    if (IsKeyDown(KEY_RIGHT) || IsKeyDown(KEY_D)) {
        paddle.position.x += paddle.speed * delta;
    }
    paddle.position.x = fmaxf(paddle.width / 2, fminf(SCREEN_WIDTH - paddle.width / 2, paddle.position.x));

    // Ball launch
    if (!ball.active && IsKeyPressed(KEY_SPACE)) {
        launch_ball();
    }

    if (!ball.active) {
        ball.position.x = paddle.position.x;
        return;
    }

    // Apply gravity
    ball.velocity.y += ball.gravity * delta;

    // Apply friction
    ball.velocity.x *= ball.friction;

    // Move ball
    ball.position.x += ball.velocity.x * delta;
    ball.position.y += ball.velocity.y * delta;

    // Wall collisions
    if (ball.position.x - ball.radius < 0) {
        ball.position.x = ball.radius;
        ball.velocity.x = fabsf(ball.velocity.x) * ball.bounce;
    }
    if (ball.position.x + ball.radius > SCREEN_WIDTH) {
        ball.position.x = SCREEN_WIDTH - ball.radius;
        ball.velocity.x = -fabsf(ball.velocity.x) * ball.bounce;
    }
    if (ball.position.y - ball.radius < 0) {
        ball.position.y = ball.radius;
        ball.velocity.y = fabsf(ball.velocity.y) * ball.bounce;
    }

    // Ball lost
    if (ball.position.y - ball.radius > SCREEN_HEIGHT) {
        end_player_turn();
        return;
    }

    // Paddle collision
    Rectangle paddle_rect = {paddle.position.x - paddle.width / 2, paddle.position.y - paddle.height / 2, paddle.width, paddle.height};
    if (check_circle_rect(ball.position, ball.radius, paddle_rect)) {
        float offset = ball.position.x - paddle.position.x;
        float normalized = fmaxf(-1.0f, fminf(1.0f, offset / 50.0f));
        ball.velocity.x = normalized * ball.speed * 0.8f;
        ball.velocity.y = fabsf(ball.velocity.y) * ball.bounce;
        ball.position.y = paddle.position.y - paddle.height / 2 - ball.radius - 1;
    }

    // Brick collisions
    for (int i = 0; i < brick_count; i++) {
        if (bricks[i].destroyed) continue;

        if (check_circle_circle(ball.position, ball.radius, bricks[i].position, bricks[i].radius)) {
            bricks[i].destroyed = true;
            game.score += bricks[i].points;
            game.bricks_destroyed++;

            if (bricks[i].is_gold) {
                game.gold += bricks[i].value;
            }

            // Bounce
            ball.velocity.y = -ball.velocity.y;
            ball.velocity.x *= ball.bounce;
            ball.velocity.y *= ball.bounce;

            break;
        }
    }

    // Check level complete
    int remaining = 0;
    for (int i = 0; i < brick_count; i++) {
        if (!bricks[i].destroyed) remaining++;
    }
    if (remaining == 0) {
        level_complete();
    }
}

void end_player_turn() {
    if (!game.is_player_turn) return;
    game.is_player_turn = false;

    // Damage enemy
    int damage = game.bricks_destroyed * levels[game.level - 1].damage_per_brick;
    enemy.hp -= damage;
    game.bricks_destroyed = 0;

    if (enemy.hp <= 0) {
        level_complete();
        return;
    }

    // Enemy turn
    BeginDrawing();
    ClearBackground((Color){20, 20, 20, 255});
    DrawText("ENEMY TURN", SCREEN_WIDTH / 2 - 70, SCREEN_HEIGHT / 2, 20, (Color){200, 50, 50, 255});
    EndDrawing();
    WaitTime(1.0);

    // Enemy attacks
    int enemy_damage = GetRandomValue(levels[game.level - 1].min_damage, levels[game.level - 1].max_damage);
    game.hp -= enemy_damage;

    if (game.hp <= 0) {
        game_over();
        return;
    }

    WaitTime(1.0);
    game.is_player_turn = true;
    reset_ball();
}

void level_complete() {
    if (game.level >= MAX_LEVELS) {
        return;
    }

    if (!game.has_upgraded) {
        game.has_upgraded = true;
    }

    // Next level
    game.level++;
    enemy.hp = levels[game.level - 1].enemy_hp;
    enemy.max_hp = levels[game.level - 1].enemy_hp;
    game.has_upgraded = false;

    init_level_bricks(game.level);
    reset_ball();
    game.is_player_turn = true;
}

void game_over() {
    init_game();
}

void init_level_bricks(int level) {
    float spacing = 30.0f;
    float start_y = SCREEN_HEIGHT - 250.0f;
    float center_x = SCREEN_WIDTH / 2.0f;
    brick_count = 0;

    switch(level) {
        case 1: // Grid layout
            for (int row = 0; row < 3; row++) {
                for (int col = 0; col < 8; col++) {
                    bricks[brick_count].position = (Vector2){center_x - 3.5f * spacing + col * spacing, start_y + row * spacing};
                    bricks[brick_count].radius = 12.0f;
                    bricks[brick_count].points = 30 - row * 5;
                    bricks[brick_count].value = 1;
                    bricks[brick_count].is_gold = (GetRandomValue(0, 100) < 15);
                    bricks[brick_count].destroyed = false;
                    brick_count++;
                }
            }
            break;
        case 2: // Diamond layout
            for (int row = 0; row < 5; row++) {
                int cols = (row % 2 == 0) ? 6 : 5;
                float offset = (row % 2 == 1) ? spacing / 2.0f : 0;
                for (int col = 0; col < cols; col++) {
                    bricks[brick_count].position = (Vector2){center_x - (cols - 1) * spacing / 2.0f + col * spacing + offset, start_y + row * spacing};
                    bricks[brick_count].radius = 12.0f;
                    bricks[brick_count].points = 40 - row * 5;
                    bricks[brick_count].value = 1;
                    bricks[brick_count].is_gold = (GetRandomValue(0, 100) < 15);
                    bricks[brick_count].destroyed = false;
                    brick_count++;
                }
            }
            break;
        case 3: // V shape layout
            for (int row = 0; row < 5; row++) {
                for (int col = 0; col < 8 - row; col++) {
                    float offset = row * spacing / 2.0f;
                    bricks[brick_count].position = (Vector2){center_x - (8 - row - 1) * spacing / 2.0f + col * spacing, start_y + row * spacing + offset};
                    bricks[brick_count].radius = 12.0f;
                    bricks[brick_count].points = 50 - row * 5;
                    bricks[brick_count].value = 1;
                    bricks[brick_count].is_gold = (GetRandomValue(0, 100) < 15);
                    bricks[brick_count].destroyed = false;
                    brick_count++;
                }
            }
            break;
        case 4: // Circle layout
            for (int i = 0; i < 12; i++) {
                float angle = i * 2 * PI / 12.0f - PI / 2.0f;
                float radius = 80.0f;
                bricks[brick_count].position = (Vector2){center_x + cosf(angle) * radius, start_y + sinf(angle) * radius * 0.6f + 50};
                bricks[brick_count].radius = 12.0f;
                bricks[brick_count].points = 40;
                bricks[brick_count].value = 1;
                bricks[brick_count].is_gold = (GetRandomValue(0, 100) < 15);
                bricks[brick_count].destroyed = false;
                brick_count++;
            }
            // Center brick
            bricks[brick_count].position = (Vector2){center_x, start_y + 50};
            bricks[brick_count].radius = 12.0f;
            bricks[brick_count].points = 50;
            bricks[brick_count].value = 1;
            bricks[brick_count].is_gold = false;
            bricks[brick_count].destroyed = false;
            brick_count++;
            break;
        case 5: // Wave layout
            for (int row = 0; row < 6; row++) {
                for (int col = 0; col < 10; col++) {
                    float wave_offset = sinf(col * 0.6f) * 20.0f;
                    bricks[brick_count].position = (Vector2){center_x - 4.5f * spacing + col * spacing, start_y + row * spacing + wave_offset};
                    bricks[brick_count].radius = 12.0f;
                    bricks[brick_count].points = 60 - row * 5;
                    bricks[brick_count].value = 1;
                    bricks[brick_count].is_gold = (GetRandomValue(0, 100) < 15);
                    bricks[brick_count].destroyed = false;
                    brick_count++;
                }
            }
            break;
    }
}

void draw_game() {
    ClearBackground((Color){20, 20, 20, 255});

    // Draw walls
    DrawRectangle(0, 0, 10, SCREEN_HEIGHT, (Color){50, 50, 50, 255});
    DrawRectangle(SCREEN_WIDTH - 10, 0, 10, SCREEN_HEIGHT, (Color){50, 50, 50, 255});
    DrawRectangle(0, 0, SCREEN_WIDTH, 10, (Color){50, 50, 50, 255});

    // Draw bricks
    for (int i = 0; i < brick_count; i++) {
        if (bricks[i].destroyed) continue;

        Color color = bricks[i].is_gold ? (Color){255, 215, 0, 255} : (Color){100 + i * 10, 150, 200, 255};
        DrawCircleV(bricks[i].position, bricks[i].radius, color);

        // Gold shine
        if (bricks[i].is_gold) {
            DrawCircleV((Vector2){bricks[i].position.x - 3, bricks[i].position.y - 3}, 4, (Color){255, 255, 200, 255});
        }
    }

    // Draw paddle
    DrawRectanglePro((Rectangle){paddle.position.x - paddle.width / 2, paddle.position.y - paddle.height / 2, paddle.width, paddle.height},
                     (Vector2){paddle.width / 2, paddle.height / 2}, 0, (Color){50, 150, 255, 255});

    // Draw ball
    if (ball.active || !game.is_player_turn) {
        DrawCircleV(ball.position, ball.radius, (Color){255, 100, 100, 255});
    }

    // Draw enemy
    DrawRectanglePro((Rectangle){enemy.position.x - enemy.width / 2, enemy.position.y - enemy.height / 2, enemy.width, enemy.height},
                     (Vector2){enemy.width / 2, enemy.height / 2}, 0, (Color){200, 50, 50, 255});
    // Enemy cockpit
    DrawRectanglePro((Rectangle){enemy.position.x - 20, enemy.position.y - enemy.height / 2 + 5, 40, enemy.height - 10},
                     (Vector2){20, enemy.height / 2 - 5}, 0, (Color){80, 80, 200, 255});

    // UI
    char buffer[100];

    // Score
    sprintf(buffer, "Score: %d", game.score);
    DrawText(buffer, 20, 20, 20, WHITE);

    // Gold
    sprintf(buffer, "Gold: %d", game.gold);
    DrawText(buffer, 150, 20, 20, (Color){255, 215, 0, 255});

    // Level
    sprintf(buffer, "Level: %d", game.level);
    DrawText(buffer, 20, 45, 16, GRAY);

    // HP bar
    DrawRectangle(20, 70, 200, 15, (Color){40, 40, 40, 255});
    DrawRectangle(20, 70, 200 * game.hp / game.max_hp, 15, (Color){50, 200, 50, 255});
    sprintf(buffer, "HP: %d/%d", game.hp, game.max_hp);
    DrawText(buffer, 230, 70, 14, WHITE);

    // Enemy HP bar
    DrawRectangle(SCREEN_WIDTH - 220, 20, 200, 12, (Color){40, 40, 40, 255});
    DrawRectangle(SCREEN_WIDTH - 220, 20, 200 * enemy.hp / enemy.max_hp, 12, (Color){200, 50, 50, 255});

    // Lives
    sprintf(buffer, "Balls: %d", game.lives);
    DrawText(buffer, SCREEN_WIDTH - 100, 40, 16, GRAY);

    // Turn indicator
    const char* turn_text = game.is_player_turn ? "YOUR TURN" : "ENEMY TURN";
    Color turn_color = game.is_player_turn ? (Color){50, 200, 50, 255} : (Color){200, 50, 50, 255};
    DrawText(turn_text, SCREEN_WIDTH / 2 - 50, 70, 18, turn_color);

    // Upgrade info
    sprintf(buffer, "Speed Lv.%d | Bounce Lv.%d", game.ball_speed_level, game.ball_bounce_level);
    DrawText(buffer, 20, 95, 14, GRAY);

    // Start prompt
    if (!ball.active && game.is_player_turn) {
        DrawText("Press SPACE to launch", SCREEN_WIDTH / 2 - 90, SCREEN_HEIGHT / 2 + 50, 20, (Color){150, 150, 150, 255});
    }
}

int main() {
    InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Breakout - Raylib");
    SetTargetFPS(60);

    init_game();

    while (!WindowShouldClose()) {
        float delta = GetFrameTime();
        update_game(delta);

        BeginDrawing();
        draw_game();
        EndDrawing();
    }

    CloseWindow();
    return 0;
}
