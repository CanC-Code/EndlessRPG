#include "Character.h"
#include <cmath>

// Terrain generation parameters (Must match terrain.vert!)
const float TERRAIN_AMPLITUDE = 2.5f;
const float TERRAIN_FREQUENCY = 0.2f;

// The distance from the center of your character model to its feet
// Adjust this value based on the scale of your character!
const float CHARACTER_HALF_HEIGHT = 1.0f; 

Character::Character() {
    position = {0.0f, 0.0f, 0.0f};
    velocity = {0.0f, 0.0f, 0.0f};
    speed = 5.0f; // Now correctly recognized by the header
}

Character::~Character() {
    // Cleanup if necessary
}

// Replicate the exact mathematical formula used in terrain.vert
float Character::getTerrainHeight(float x, float z) {
    return TERRAIN_AMPLITUDE * std::sin(x * TERRAIN_FREQUENCY) * std::cos(z * TERRAIN_FREQUENCY);
}

void Character::update(float deltaTime, float joystickX, float joystickY) {
    // 1. Update horizontal movement based on joystick input
    position.x += joystickX * speed * deltaTime;
    position.z += joystickY * speed * deltaTime;
    
    // 2. Calculate the ground height at the new X and Z coordinates
    float groundHeight = getTerrainHeight(position.x, position.z);
    
    // 3. Set the character's Y position to the ground height 
    // PLUS the offset so the model stands directly on top of the terrain
    position.y = groundHeight + CHARACTER_HALF_HEIGHT;
}

// Standard getters (These no longer conflict with the header)
float Character::getX() const { return position.x; }
float Character::getY() const { return position.y; }
float Character::getZ() const { return position.z; }
