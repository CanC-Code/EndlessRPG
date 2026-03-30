#include "Character.h"
#include <cmath>

// Terrain generation parameters (Must match terrain.vert!)
const float TERRAIN_AMPLITUDE = 2.5f;
const float TERRAIN_FREQUENCY = 0.2f;

// Bounding box offset so the character stands on the ground
const float CHARACTER_HALF_HEIGHT = 1.0f; 

Character::Character() {
    position = {0.0f, 0.0f, 0.0f};
    velocity = {0.0f, 0.0f, 0.0f};
    speed = 5.0f;
}

Character::~Character() {
}

float Character::getTerrainHeight(float x, float z) {
    return TERRAIN_AMPLITUDE * std::sin(x * TERRAIN_FREQUENCY) * std::cos(z * TERRAIN_FREQUENCY);
}

// FIXED: Added camYaw and camPitch parameters
void Character::update(float deltaTime, float joystickX, float joystickY, float camYaw, float camPitch) {
    
    // Calculate movement direction relative to camera yaw
    // (Assuming camYaw is in radians. If your engine uses degrees, you will need to multiply it by PI/180 here)
    float moveX = joystickX * std::cos(camYaw) - joystickY * std::sin(camYaw);
    float moveZ = joystickX * std::sin(camYaw) + joystickY * std::cos(camYaw);

    // 1. Update horizontal position
    position.x += moveX * speed * deltaTime;
    position.z += moveZ * speed * deltaTime;
    
    // 2. Calculate the ground height at the new X and Z coordinates
    float groundHeight = getTerrainHeight(position.x, position.z);
    
    // 3. Prevent clipping by applying the exact ground height + half-height offset
    position.y = groundHeight + CHARACTER_HALF_HEIGHT;
}

float Character::getX() const { return position.x; }
float Character::getY() const { return position.y; }
float Character::getZ() const { return position.z; }
