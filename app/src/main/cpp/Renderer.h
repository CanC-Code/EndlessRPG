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
    
    GLuint terrainVAO, terrainVBO, terrainEBO;
    GLuint terrainProgram;
    GLuint grassProgram, grassComputeProgram;
    GLuint grassSSBO;
    
    float cameraX = 0, cameraY = 15, cameraZ = 0;
    float camYaw = 0, camPitch = -0.5f;
    float moveX = 0, moveY = 0;
    float cameraZoom = 15.0f;
    bool isThirdPerson = true;
    
    int indexCount;
};
