#ifndef CHARACTER_H
#define CHARACTER_H

struct Vec3 {
    float x, y, z;
    Vec3(float _x = 0, float _y = 0, float _z = 0) : x(_x), y(_y), z(_z) {}
};

class Character {
public:
    Character();
    ~Character();

    void update(float dt, float moveX, float moveY, float yaw, float groundHeight);
    
    float getX() const { return position.x; }
    float getY() const { return position.y; }
    float getZ() const { return position.z; }

private:
    Vec3 position;
    Vec3 velocity;
    
    float eyeHeight = 1.8f;   // Player's camera height from their feet
    float gravity = -15.0f;   // Gravity strength
    float moveSpeed = 8.0f;
    bool isGrounded = false;
};

#endif
