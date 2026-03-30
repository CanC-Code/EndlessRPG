#ifndef CHARACTER_H
#define CHARACTER_H

// A simple 3D vector struct to hold our coordinates
struct Vector3 {
    float x;
    float y;
    float z;
};

class Character {
private:
    Vector3 position;
    Vector3 velocity;
    
    float speed;

    // Helper function for procedural terrain height
    float getTerrainHeight(float x, float z);

public:
    Character();
    ~Character();

    // FIXED: Now expects 5 parameters to match Renderer.cpp
    void update(float deltaTime, float joystickX, float joystickY, float camYaw, float camPitch);

    // Getters
    float getX() const;
    float getY() const;
    float getZ() const;
};

#endif // CHARACTER_H
