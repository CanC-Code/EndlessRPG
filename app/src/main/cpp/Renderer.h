#pragma once

#include <GLES3/gl31.h>
#include <vector>
#include <string>

class GrassRenderer {
public:
    GrassRenderer();
    ~GrassRenderer();
    
    void init();
    void render(int width, int height);
    void updateInput(float mx, float my, float lx, float ly, bool tp, float zoom);

private:
    void generateTerrainGrid();
    void setupShaders();
    
    // OpenGL Objects
    GLuint terrainVAO, terrainVBO, terrainEBO;
    GLuint terrainProgram;
    GLuint grassProgram, grassComputeProgram;
    GLuint grassSSBO;
    
    // Camera & Input State
    float cameraX = 0.0f;
    float cameraY = 15.0f;
    float cameraZ = 0.0f;
    float camYaw = 0.0f;
    float camPitch = -0.5f;
    float moveX = 0.0f;
    float moveY = 0.0f;
    float cameraZoom = 15.0f;
    bool isThirdPerson = true;
    
    int indexCount;
};
