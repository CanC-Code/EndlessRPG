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
    
    // NEW: We must declare the speed variable here so the .cpp file can use it
    float speed;

    // NEW: Declare the terrain height calculation function as a private helper
    float getTerrainHeight(float x, float z);

public:
    Character();
    ~Character();

    // NEW: Declare our updated movement function
    void update(float deltaTime, float joystickX, float joystickY);

    // Getters for position (Declared here, implemented in the .cpp file)
    float getX() const;
    float getY() const;
    float getZ() const;
};

#endif // CHARACTER_H
