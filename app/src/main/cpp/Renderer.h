#pragma once
#include <GLES3/gl31.h>
#include <string>
#include <vector>
#include "Character.h" // Required for the player model

const int GRASS_COUNT = 262144; 

class GrassRenderer {
public:
    GrassRenderer();
    void init();
    void updateAndRender(float time, float deltaTime, int screenWidth, int screenHeight);
    void updateInput(float mx, float my, float lx, float ly, bool isThirdPerson, float zoom);

    // Player and Camera State
    float playerX = 0.0f, playerY = 0.0f, playerZ = 0.0f;
    float camX = 0.0f, camY = 1.8f, camZ = 0.0f;
    float camYaw = -90.0f, camPitch = 0.0f;
    float moveX = 0.0f, moveY = 0.0f;
    bool isThirdPerson = false;
    float cameraZoom = 8.0f;

private:
    Character playerModel;

    // OpenGL Handles
    GLuint computeProgram, renderProgram, terrainProgram;
    GLuint ssbo, vao, vbo;
    GLuint terrainVao, terrainVbo, terrainEbo;
    int terrainIndexCount;

    // Internal Methods
    GLuint compileShader(GLenum type, const std::string& source);
    GLuint createProgram(GLuint vShader, GLuint fShader);
    GLuint createComputeProgram(GLuint cShader);
    void generateTerrainGrid();

    // Math
    void buildPerspective(float* m, float fov, float aspect, float zNear, float zFar);
    void buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz);
    void multiply(float* out, const float* a, const float* b);

    // Procedural Math (C++ Scalar Versions)
    float fract(float x);
    float hash(float x, float y);
    float mix(float x, float y, float a);
    float smoothstep(float edge0, float edge1, float x);
    float noise(float x, float y);
    float fbm(float x, float y);
    float getElevation(float x, float y);
};
