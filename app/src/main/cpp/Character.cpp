#include "Character.h"
#include <cmath>
#include <algorithm> // FIXED: Required for std::max

// THE WORLD TRUTH: This math must match Renderer.cpp exactly
float getPhysicsGroundHeight(float x, float z) {
    float h = sinf(x * 0.04f) * 4.0f;
    h += cosf(z * 0.03f) * 3.0f;
    h += sinf((x + z) * 0.1f) * 1.5f;
    return h;
}

Character::Character() : position(0.0f, 10.0f, 0.0f), velocity(0.0f, 0.0f, 0.0f) {}

Character::~Character() {}

void Character::update(float dt, float mx, float my, float yaw, float groundHeightInput) {
    // 1. Horizontal Movement
    float cosY = cosf(yaw);
    float sinY = sinf(yaw);

    // Apply movement relative to camera yaw
    position.x += (mx * cosY + my * sinY) * moveSpeed * dt;
    position.z += (-my * cosY + mx * sinY) * moveSpeed * dt;

    // 2. Probing the Ground at NEW position
    // This prevents the "clipping" issue by checking the height exactly where we just moved
    float currentGroundLevel = getPhysicsGroundHeight(position.x, position.z);

    // 3. Vertical Physics (Gravity)
    if (!isGrounded) {
        velocity.y += gravity * dt;
    } else {
        // Zero out downward momentum, but allow upward (for jumping/hills)
        velocity.y = std::max(0.0f, velocity.y);
    }

    position.y += velocity.y * dt;

    // 4. Ground Collision & Constraint
    // The "Feet" of the character is position.y.
    if (position.y < currentGroundLevel) {
        position.y = currentGroundLevel; // Snap to the grass surface
        velocity.y = 0.0f;              // Stop falling
        isGrounded = true;
    } else {
        // We are grounded if we are resting precisely on the terrain
        isGrounded = (position.y <= currentGroundLevel + 0.01f);
    }
}
