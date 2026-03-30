#include "Character.h"
#include <cmath>

// We redefine the world math here to ensure the physics engine 
// sees the exact same hills as the GPU Renderer.
float getPhysicsGroundHeight(float x, float z) {
    float h = sinf(x * 0.04f) * 4.0f;
    h += cosf(z * 0.03f) * 3.0f;
    h += sinf((x + z) * 0.1f) * 1.5f;
    return h;
}

Character::Character() {
    position = Vec3(0.0f, 10.0f, 0.0f); // Start high in the air to test gravity
    velocity = Vec3(0.0f, 0.0f, 0.0f);
}

Character::~Character() {}

void Character::update(float dt, float mx, float my, float yaw, float groundHeightInput) {
    // 1. Calculate View-Relative Movement
    // Using the Yaw (camera rotation) to move forward/backward relative to where we look
    float cosY = cosf(yaw);
    float sinY = sinf(yaw);

    // Update X and Z first (Horizontal Movement)
    position.x += (mx * cosY + my * sinY) * moveSpeed * dt;
    position.z += (-my * cosY + mx * sinY) * moveSpeed * dt;

    // 2. Vertical Physics (Gravity & Jumping)
    // We apply gravity constantly if we aren't standing on something solid
    if (!isGrounded) {
        velocity.y += gravity * dt;
    } else {
        // If grounded, we zero out the downward momentum
        velocity.y = std::max(0.0f, velocity.y);
    }

    // Apply vertical velocity to our Y position
    position.y += velocity.y * dt;

    // 3. THE FIX: Dynamic Ground Probing
    // Instead of using the 'groundHeight' passed from the frame start, 
    // we calculate the height at our NEW coordinates to prevent clipping.
    float currentGroundLevel = getPhysicsGroundHeight(position.x, position.z);

    // 4. Ground Collision Constraint
    // This is the physical "floor" logic.
    if (position.y < currentGroundLevel) {
        position.y = currentGroundLevel; // Snap feet to the grass
        velocity.y = 0.0f;              // Stop falling
        isGrounded = true;
    } else {
        // If we are significantly above the ground, we are in the air (falling)
        isGrounded = (position.y <= currentGroundLevel + 0.01f);
    }
}
