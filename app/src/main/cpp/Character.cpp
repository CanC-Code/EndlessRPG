#include "Character.h"
#include <cmath>

Character::Character() : position(0.0f, 10.0f, 0.0f), velocity(0.0f, 0.0f, 0.0f) {}

Character::~Character() {}

void Character::update(float dt, float mx, float my, float yaw, float groundHeight) {
    // 1. Horizontal Movement
    float cosY = cosf(yaw);
    float sinY = sinf(yaw);
    
    position.x += (mx * cosY + my * sinY) * moveSpeed * dt;
    position.z += (-my * cosY + mx * sinY) * moveSpeed * dt;

    // 2. Vertical Physics (Gravity)
    if (!isGrounded) {
        velocity.y += gravity * dt;
    }
    position.y += velocity.y * dt;

    // 3. Ground Collision & Constraint
    if (position.y < groundHeight) {
        position.y = groundHeight; 
        velocity.y = 0.0f;         
        isGrounded = true;
    } else {
        isGrounded = false;
    }
}
