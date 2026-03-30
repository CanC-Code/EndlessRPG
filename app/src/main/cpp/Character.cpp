#include "Character.h"
#include <cmath>
#include <algorithm>

Character::Character() {
    position = glm::vec3(0.0f, 10.0f, 0.0f); // Start in the air!
    velocity = glm::vec3(0.0f);
}

Character::~Character() {}

void Character::init() {}

void Character::update(float dt, float mx, float my, float yaw, float groundHeight) {
    // 1. Calculate Horizontal Movement
    // Transform local input (forward/strafe) into world-space direction based on Yaw
    float cosY = cosf(yaw);
    float sinY = sinf(yaw);
    
    glm::vec3 moveDir;
    moveDir.x = (mx * cosY + my * sinY);
    moveDir.z = (-my * cosY + mx * sinY);
    moveDir.y = 0.0f;

    // Apply horizontal movement to position
    position.x += moveDir.x * moveSpeed * dt;
    position.z += moveDir.z * moveSpeed * dt;

    // 2. Apply Gravity (What goes up must come down)
    if (!isGrounded) {
        velocity.y += gravity * dt;
    }

    // Apply vertical velocity to position
    position.y += velocity.y * dt;

    // 3. Ground Collision & Constraint
    // The "Feet" of the character is position.y. 
    // The "Eyes" (for the camera) will be position.y + eyeHeight.
    if (position.y < groundHeight) {
        position.y = groundHeight; // Snap to surface
        velocity.y = 0.0f;         // Kill downward velocity
        isGrounded = true;
    } else {
        isGrounded = false;
    }
}
