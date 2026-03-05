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
#define SCREEN_WIDTH 900
#define SCREEN_HEIGHT 600
#define GAME_WIDTH 700
#define PANEL_WIDTH 200
#define MAX_BRICKS 100
#define MAX_BALLS 1
#define MAX_LEVELS 5
#define MAX_REFRESH_TOKENS 2

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
    bool launched;
} Ball;

typedef struct {
    Vector2 position;
    float radius;
    int points;
    int value;
    bool is_gold;
    bool is_refresh;
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
    bool level_complete_triggered;
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
void launch_all_balls();
void spawn_refresh_tokens();
void respawn_bricks();
void draw_refresh_panel();
void end_player_turn();
void level_complete();
void game_over();

// Global variables
Ball balls[MAX_BALLS];
Brick bricks[MAX_BRICKS];
Enemy enemy;
GameState game;
int brick_count = 0;
int active_balls = 0;
int refresh_tokens[MAX_REFRESH_TOKENS]; // indices of refresh bricks
int refresh_count = 0;
bool panel_dirty = true;

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
    game.lives = 1; // No lives system anymore
    game.bricks_destroyed = 0;
    game.is_player_turn = true;
    game.has_upgraded = false;
    game.level_complete_triggered = false;
    game.ball_speed_level = 1;
    game.ball_bounce_level = 1;

    // Initialize balls
    for (int i = 0; i < MAX_BALLS; i++) {
        balls[i].position = (Vector2){0, 0};
        balls[i].velocity = (Vector2){0, 0};
        balls[i].radius = 10;
        balls[i].gravity = 980.0f;
        balls[i].bounce = 0.75f;
        balls[i].friction = 0.99f;
        balls[i].speed = 400.0f;
        balls[i].active = false;
        balls[i].launched = false;
    }

    // Initialize enemy in right panel
    enemy.position = (Vector2){GAME_WIDTH + PANEL_WIDTH / 2.0f, 150};
    enemy.width = 120;
    enemy.height = 30;
    enemy.hp = levels[game.level - 1].enemy_hp;
    enemy.max_hp = levels[game.level - 1].enemy_hp;

    // Spawn refresh tokens
    refresh_count = 0;
    panel_dirty = true;

    init_level_bricks(game.level);
    reset_ball();
}

void reset_ball() {
    // Reset all balls to launch position
    for (int i = 0; i < MAX_BALLS; i++) {
        // Spread balls around launch position
        float offset = (i - 1) * 30.0f;
        balls[i].position = (Vector2){GAME_WIDTH / 2.0f + offset, 60};
        balls[i].velocity = (Vector2){0, 0};
        balls[i].active = false;
        balls[i].launched = false;
    }
    active_balls = 0;
}

void launch_all_balls() {
    Vector2 mouse = GetMousePosition();
    Vector2 base_launch = (Vector2){GAME_WIDTH / 2.0f, 60};

    for (int i = 0; i < MAX_BALLS; i++) {
        if (!balls[i].launched) {
            // Calculate direction towards mouse from ball position
            Vector2 direction = {mouse.x - balls[i].position.x, mouse.y - balls[i].position.y};
            float length = sqrtf(direction.x * direction.x + direction.y * direction.y);
            if (length > 0) {
                direction.x /= length;
                direction.y /= length;
            }

            float speed = 400.0f + (game.ball_speed_level - 1) * 50;
            balls[i].velocity = (Vector2){direction.x * speed, direction.y * speed};
            balls[i].active = true;
            balls[i].launched = true;
            active_balls++;
        }
    }
}

void spawn_refresh_tokens() {
    // Clear old refresh tokens
    refresh_count = 0;

    // Randomly select 2 bricks to be refresh tokens
    int available[MAX_BRICKS];
    int avail_count = 0;

    for (int i = 0; i < brick_count; i++) {
        if (!bricks[i].destroyed && !bricks[i].is_refresh) {
            available[avail_count] = i;
            avail_count++;
        }
    }

    // Select 2 random bricks
    for (int i = 0; i < 2 && avail_count > 0; i++) {
        int idx = GetRandomValue(0, avail_count - 1);
        int brick_idx = available[idx];

        bricks[brick_idx].is_refresh = true;
        bricks[brick_idx].value = 0; // Special value
        refresh_tokens[refresh_count] = brick_idx;
        refresh_count++;

        // Remove from available
        available[idx] = available[avail_count - 1];
        avail_count--;
    }

    panel_dirty = false;
}

void respawn_bricks() {
    // Reset all bricks
    for (int i = 0; i < brick_count; i++) {
        bricks[i].destroyed = false;
    }

    // Re-randomize refresh tokens
    spawn_refresh_tokens();
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

    // Ball launch
    if (IsKeyPressed(KEY_SPACE)) {
        launch_all_balls();
    }

    // Update each ball
    int all_lost = 0;
    for (int b = 0; b < MAX_BALLS; b++) {
        if (!balls[b].active) continue;

        // Apply gravity
        balls[b].velocity.y += balls[b].gravity * delta;

        // Apply friction
        balls[b].velocity.x *= balls[b].friction;

        // Move ball
        balls[b].position.x += balls[b].velocity.x * delta;
        balls[b].position.y += balls[b].velocity.y * delta;

        // Wall collisions (within game area)
        if (balls[b].position.x - balls[b].radius < 0) {
            balls[b].position.x = balls[b].radius;
            balls[b].velocity.x = fabsf(balls[b].velocity.x) * balls[b].bounce;
        }
        if (balls[b].position.x + balls[b].radius > GAME_WIDTH) {
            balls[b].position.x = GAME_WIDTH - balls[b].radius;
            balls[b].velocity.x = -fabsf(balls[b].velocity.x) * balls[b].bounce;
        }
        if (balls[b].position.y - balls[b].radius < 0) {
            balls[b].position.y = balls[b].radius;
            balls[b].velocity.y = fabsf(balls[b].velocity.y) * balls[b].bounce;
        }

        // Ball lost
        if (balls[b].position.y - balls[b].radius > SCREEN_HEIGHT) {
            balls[b].active = false;
            all_lost++;
        }

        // Brick collisions
        for (int i = 0; i < brick_count; i++) {
            if (bricks[i].destroyed) continue;

            if (check_circle_circle(balls[b].position, balls[b].radius, bricks[i].position, bricks[i].radius)) {
                bricks[i].destroyed = true;
                game.score += bricks[i].points;
                game.bricks_destroyed++;

                if (bricks[i].is_gold) {
                    game.gold += 1;
                }

                // Check if refresh token was hit - respawn all bricks
                if (bricks[i].is_refresh) {
                    respawn_bricks();
                    // Don't count this as destroying a brick for damage
                    game.bricks_destroyed = 0;
                }

                // Bounce
                balls[b].velocity.y = -balls[b].velocity.y;
                balls[b].velocity.x *= balls[b].bounce;
                balls[b].velocity.y *= balls[b].bounce;

                break;
            }
        }
    }

    // Check if all balls lost - only when at least one was launched
    if (all_lost == MAX_BALLS) {
        // Check if any ball was launched
        bool any_launched = false;
        for (int b = 0; b < MAX_BALLS; b++) {
            if (balls[b].launched) {
                any_launched = true;
                break;
            }
        }

        // Only end turn if balls were actually launched
        if (any_launched) {
            end_player_turn();
            return;
        }
    }

    // Spawn refresh tokens if needed - only when level starts
    // Removed per-frame check to fix performance

    // Check level complete (only once)
    if (!game.level_complete_triggered) {
        int remaining = 0;
        for (int i = 0; i < brick_count; i++) {
            if (!bricks[i].destroyed) remaining++;
        }
        if (remaining == 0) {
            game.level_complete_triggered = true;
            level_complete();
        }
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
    game.level_complete_triggered = false;

    panel_dirty = true;
    init_level_bricks(game.level);
    reset_ball();
    game.is_player_turn = true;
}

void game_over() {
    init_game();
}

void init_level_bricks(int level) {
    float spacing = 35.0f;
    float start_y = SCREEN_HEIGHT - 300.0f;
    float center_x = GAME_WIDTH / 2.0f;
    brick_count = 0;

    switch(level) {
        case 1: // Grid layout
            for (int row = 0; row < 3; row++) {
                for (int col = 0; col < 8; col++) {
                    bricks[brick_count].position = (Vector2){center_x - 3.5f * spacing + col * spacing, start_y + row * spacing};
                    bricks[brick_count].radius = 12.0f;
                    bricks[brick_count].points = 30 - row * 5;
                    bricks[brick_count].is_gold = (GetRandomValue(0, 100) < 10);
                    bricks[brick_count].is_refresh = false;
                    bricks[brick_count].destroyed = false;
                    brick_count++;
                }
            }
            break;
        case 2: // Scattered
            for (int i = 0; i < 30; i++) {
                bricks[brick_count].position = (Vector2){
                    GetRandomValue(50, GAME_WIDTH - 50),
                    GetRandomValue(100, SCREEN_HEIGHT - 150)
                };
                bricks[brick_count].radius = 12.0f;
                bricks[brick_count].points = GetRandomValue(10, 30);
                bricks[brick_count].is_gold = (GetRandomValue(0, 100) < 10);
                bricks[brick_count].is_refresh = false;
                bricks[brick_count].destroyed = false;
                brick_count++;
            }
            break;
        case 3: // Multiple clusters
            for (int cluster = 0; cluster < 3; cluster++) {
                float cx = 100.0f + cluster * 250.0f;
                float cy = 150.0f + cluster * 80.0f;
                for (int row = 0; row < 4; row++) {
                    for (int col = 0; col < 5; col++) {
                        bricks[brick_count].position = (Vector2){cx + col * spacing * 0.8f, cy + row * spacing * 0.8f};
                        bricks[brick_count].radius = 12.0f;
                        bricks[brick_count].points = 40 - row * 5;
                        bricks[brick_count].is_gold = (GetRandomValue(0, 100) < 10);
                        bricks[brick_count].is_refresh = false;
                        bricks[brick_count].destroyed = false;
                        brick_count++;
                    }
                }
            }
            break;
        case 4: // Circle layout
            for (int i = 0; i < 16; i++) {
                float angle = i * 2 * PI / 16.0f - PI / 2.0f;
                float radius = 120.0f;
                bricks[brick_count].position = (Vector2){center_x + cosf(angle) * radius, start_y + sinf(angle) * radius * 0.7f};
                bricks[brick_count].radius = 12.0f;
                bricks[brick_count].points = 30;
                bricks[brick_count].is_gold = (GetRandomValue(0, 100) < 10);
                bricks[brick_count].is_refresh = false;
                bricks[brick_count].destroyed = false;
                brick_count++;
            }
            // Center
            bricks[brick_count].position = (Vector2){center_x, start_y};
            bricks[brick_count].radius = 15.0f;
            bricks[brick_count].points = 50;
            bricks[brick_count].is_gold = true;
            bricks[brick_count].is_refresh = false;
            bricks[brick_count].destroyed = false;
            brick_count++;
            break;
        case 5: // Wave scattered
            for (int i = 0; i < 50; i++) {
                float x = 50.0f + (i % 10) * 65.0f;
                float y = 100.0f + (i / 10) * 45.0f + sinf(i * 0.5f) * 20.0f;
                bricks[brick_count].position = (Vector2){x, y};
                bricks[brick_count].radius = 11.0f;
                bricks[brick_count].points = 50 - (i / 10) * 5;
                bricks[brick_count].is_gold = (GetRandomValue(0, 100) < 12);
                bricks[brick_count].is_refresh = false;
                bricks[brick_count].destroyed = false;
                brick_count++;
            }
            break;
    }

    // Mark refresh tokens
    spawn_refresh_tokens();
}

void draw_refresh_panel() {
    // Panel background
    DrawRectangle(GAME_WIDTH, 0, PANEL_WIDTH, SCREEN_HEIGHT, (Color){30, 30, 35, 255});

    // Enemy section
    DrawText("ENEMY", GAME_WIDTH + 60, 30, 20, WHITE);

    // Enemy HP bar
    DrawRectangle(GAME_WIDTH + 20, 60, 160, 15, (Color){40, 40, 40, 255});
    DrawRectangle(GAME_WIDTH + 20, 60, 160 * enemy.hp / enemy.max_hp, 15, (Color){200, 50, 50, 255});

    // Enemy HP text
    char buffer[50];
    sprintf(buffer, "%d/%d", enemy.hp, enemy.max_hp);
    DrawText(buffer, GAME_WIDTH + 70, 80, 14, GRAY);

    // Draw enemy ship
    float ex = enemy.position.x;
    float ey = enemy.position.y;
    DrawRectanglePro((Rectangle){ex - enemy.width/2, ey - enemy.height/2, enemy.width, enemy.height},
                     (Vector2){enemy.width/2, enemy.height/2}, 0, (Color){200, 50, 50, 255});
    DrawRectanglePro((Rectangle){ex - 15, ey - enemy.height/2 + 5, 30, enemy.height - 10},
                     (Vector2){15, enemy.height/2 - 5}, 0, (Color){80, 80, 200, 255});

    // Divider
    DrawLine(GAME_WIDTH, 120, SCREEN_WIDTH, 120, (Color){50, 50, 50, 255});

    // Refresh tokens section
    DrawText("REFRESH", GAME_WIDTH + 65, 140, 20, WHITE);
    DrawText("(Destroy to", GAME_WIDTH + 55, 165, 12, GRAY);
    DrawText("respawn bricks)", GAME_WIDTH + 45, 180, 12, GRAY);

    // Draw refresh brick indicators
    for (int i = 0; i < refresh_count; i++) {
        int idx = refresh_tokens[i];
        if (idx >= 0 && idx < brick_count && !bricks[idx].destroyed) {
            // Draw indicator at brick position (in game area)
            DrawCircleV(bricks[idx].position, 18, (Color){255, 100, 255, 100});
            DrawCircleV(bricks[idx].position, 14, (Color){255, 100, 255, 200});

            // Draw label
            char label[20];
            sprintf(label, "R%d", i + 1);
            DrawText(label, bricks[idx].position.x - 8, bricks[idx].position.y - 6, 10, WHITE);
        }
    }

    // Also show in panel
    int panel_y = 210;
    for (int i = 0; i < refresh_count; i++) {
        int idx = refresh_tokens[i];
        if (idx >= 0 && idx < brick_count && !bricks[idx].destroyed) {
            char label[20];
            sprintf(label, "Refresh #%d", i + 1);
            DrawText(label, GAME_WIDTH + 30, panel_y, 14, (Color){255, 150, 255, 255});
            panel_y += 25;
        }
    }

    // Divider 2
    DrawLine(GAME_WIDTH, panel_y + 20, SCREEN_WIDTH, panel_y + 20, (Color){50, 50, 50, 255});

    // Stats
    int stats_y = panel_y + 40;
    sprintf(buffer, "Score: %d", game.score);
    DrawText(buffer, GAME_WIDTH + 30, stats_y, 18, WHITE);

    sprintf(buffer, "Gold: %d", game.gold);
    DrawText(buffer, GAME_WIDTH + 30, stats_y + 30, 18, (Color){255, 215, 0, 255});

    sprintf(buffer, "Level: %d", game.level);
    DrawText(buffer, GAME_WIDTH + 30, stats_y + 60, 16, GRAY);

    // HP bar
    DrawRectangle(GAME_WIDTH + 20, stats_y + 90, 160, 20, (Color){40, 40, 40, 255});
    DrawRectangle(GAME_WIDTH + 20, stats_y + 90, 160 * game.hp / game.max_hp, 20, (Color){50, 200, 50, 255});
    sprintf(buffer, "HP: %d/%d", game.hp, game.max_hp);
    DrawText(buffer, GAME_WIDTH + 30, stats_y + 115, 14, WHITE);
}

void draw_game() {
    ClearBackground((Color){20, 20, 20, 255});

    // Draw game area border
    DrawRectangle(GAME_WIDTH - 2, 0, 2, SCREEN_HEIGHT, (Color){50, 50, 50, 255});

    // Draw bricks
    for (int i = 0; i < brick_count; i++) {
        if (bricks[i].destroyed) continue;

        Color color;
        if (bricks[i].is_refresh) {
            color = (Color){255, 100, 255, 255}; // Purple for refresh
        } else if (bricks[i].is_gold) {
            color = (Color){255, 215, 0, 255};
        } else {
            color = (Color){100 + i * 5, 150, 200, 255};
        }

        DrawCircleV(bricks[i].position, bricks[i].radius, color);

        // Gold shine
        if (bricks[i].is_gold) {
            DrawCircleV((Vector2){bricks[i].position.x - 3, bricks[i].position.y - 3}, 4, (Color){255, 255, 200, 255});
        }

        // Refresh indicator
        if (bricks[i].is_refresh) {
            DrawCircleV(bricks[i].position, bricks[i].radius + 4, (Color){255, 100, 255, 100});
        }
    }

    // Draw balls
    for (int i = 0; i < MAX_BALLS; i++) {
        if (balls[i].active) {
            DrawCircleV(balls[i].position, balls[i].radius, (Color){255, 100, 100, 255});
        } else if (!balls[i].launched && game.is_player_turn) {
            // Draw ball at launch position
            DrawCircleV(balls[i].position, balls[i].radius, (Color){255, 150, 150, 200});
        }
    }

    // Draw launch position
    Vector2 launch_pos = (Vector2){GAME_WIDTH / 2.0f, 60};
    DrawCircleV(launch_pos, 15, (Color){50, 150, 255, 255});
    DrawCircleV(launch_pos, 10, (Color){80, 180, 255, 255});

    // Draw trajectory preview when balls not launched
    bool any_launched = false;
    for (int i = 0; i < MAX_BALLS; i++) {
        if (balls[i].launched) {
            any_launched = true;
            break;
        }
    }

    if (!any_launched && game.is_player_turn) {
        Vector2 mouse = GetMousePosition();

        // Draw line from first ball to mouse
        DrawLineV(balls[0].position, mouse, (Color){80, 180, 255, 100});

        // Draw trajectory from first ball
        Vector2 direction = {mouse.x - balls[0].position.x, mouse.y - balls[0].position.y};
        float length = sqrtf(direction.x * direction.x + direction.y * direction.y);
        if (length > 0) {
            direction.x /= length;
            direction.y /= length;
        }

        float speed = 400.0f + (game.ball_speed_level - 1) * 50;
        Vector2 vel = {direction.x * speed, direction.y * speed};

        Vector2 pos = balls[0].position;
        Vector2 grav = {0, balls[0].gravity};

        for (int i = 0; i < 60; i++) {
            vel.x *= balls[0].friction;
            vel.y += grav.y * 0.016f;
            pos.x += vel.x * 0.016f;
            pos.y += vel.y * 0.016f;

            if (pos.y > SCREEN_HEIGHT || pos.x < 0 || pos.x > GAME_WIDTH) break;
            if (i % 3 == 0) {
                DrawCircleV(pos, 2, (Color){100, 100, 100, 150});
            }
        }
    }

    // Draw right panel
    draw_refresh_panel();

    // Turn indicator
    const char* turn_text = game.is_player_turn ? "YOUR TURN" : "ENEMY TURN";
    Color turn_color = game.is_player_turn ? (Color){50, 200, 50, 255} : (Color){200, 50, 50, 255};
    DrawText(turn_text, GAME_WIDTH / 2 - 50, 20, 20, turn_color);

    // Start prompt
    bool any_active = false;
    for (int i = 0; i < MAX_BALLS; i++) {
        if (balls[i].launched) {
            any_active = true;
            break;
        }
    }

    if (!any_active && game.is_player_turn) {
        DrawText("Press SPACE to launch", GAME_WIDTH / 2 - 80, SCREEN_HEIGHT / 2 + 50, 18, (Color){150, 150, 150, 255});
    }

    // Enemy turn overlay
    if (!game.is_player_turn) {
        DrawRectangle(0, 0, GAME_WIDTH, SCREEN_HEIGHT, (Color){0, 0, 0, 150});
        DrawText("ENEMY TURN", GAME_WIDTH / 2 - 70, SCREEN_HEIGHT / 2, 30, (Color){200, 50, 50, 255});
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
