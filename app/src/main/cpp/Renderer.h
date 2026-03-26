#pragma once
#include <GLES3/gl31.h>
#include "Character.h"
#include <string>
#include <vector>

#define GRASS_COUNT 65536 // 64k blades for photographic density

class GrassRenderer {
public:
    GrassRenderer();
    void init();
    void updateInput(float mx, float my, float lx, float ly, bool tp, float zoom);
    void updateAndRender(float time, float dt, int width, int height);

private:
    GLuint renderProgram, terrainProgram, computeProgram;
    GLuint vao, vbo, instanceVbo, ssbo;
    GLuint terrainVao, terrainVbo, terrainEbo;
    int terrainIndexCount;

    Character playerModel;

    // Transformation State
    float playerX, playerY, playerZ, playerYaw;
    float camX, camY, camZ, camYaw, camPitch;
    float moveX, moveY, cameraZoom;
    bool isThirdPerson;

    // --- NEW PHYSICS & INTERACTION STATE ---
    float velocityX, velocityZ;   // Momentum for "weighted" movement
    float smoothPitch, smoothRoll; // Prevents "snapping" on slopes
    
    // Internal Utilities
    float getElevation(float x, float z);
    void generateTerrainGrid();
    GLuint compileShader(GLenum type, const std::string& source);
    GLuint createProgram(GLuint vS, GLuint fS);
    GLuint createComputeProgram(GLuint cS);
    
    void buildPerspective(float* m, float fov, float aspect, float zn, float zf);
    void buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz);
    void multiply(float* out, const float* a, const float* b);
};
