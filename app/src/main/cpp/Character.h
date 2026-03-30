#ifndef CHARACTER_H
#define CHARACTER_H

#include <glm/glm.hpp> // Ensure GLM is in your project for vector math

class Character {
public:
    Character();
    ~Character();

    void init();
    
    // Core Physics Update
    void update(float dt, float moveX, float moveY, float yaw, float groundHeight);
    
    // Getters for the Renderer
    float getX() const { return position.x; }
    float getY() const { return position.y; }
    float getZ() const { return position.z; }

private:
    glm::vec3 position;
    glm::vec3 velocity;
    
    float eyeHeight = 1.8f;   // Player height
    float gravity = -15.0f;   // Stronger gravity for "heavy" feel
    float moveSpeed = 8.0f;
    bool isGrounded = false;
};

#endif
