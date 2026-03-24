#pragma once
#include <GLES3/gl31.h>
#include <string>
#include <vector>

const int GRASS_COUNT = 262144; 

class GrassRenderer {
public:
    GrassRenderer();
    void init();
    void updateAndRender(float time, float deltaTime, int screenWidth, int screenHeight);
    
    void updateInput(float mx, float my, float lx, float ly);

    // Camera State
    float camX = 0.0f;
    float camY = 1.8f;
    float camZ = 0.0f;
    
    float camYaw = -90.0f; 
    float camPitch = 0.0f;
    
    float moveX = 0.0f;
    float moveY = 0.0f;

private:
    // OpenGL Handles for Grass
    GLuint computeProgram, renderProgram;
    GLuint ssbo, vao, vbo;

    // OpenGL Handles for Terrain
    GLuint terrainProgram;
    GLuint terrainVao, terrainVbo, terrainEbo;
    int terrainIndexCount;

    // Initialization Methods
    GLuint compileShader(GLenum type, const std::string& source);
    GLuint createProgram(GLuint vShader, GLuint fShader);
    GLuint createComputeProgram(GLuint cShader);
    void generateTerrainGrid();

    // Matrix Math
    void buildPerspective(float* m, float fov, float aspect, float zNear, float zFar);
    void buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz);
    void multiply(float* out, const float* a, const float* b);

    // CPU Terrain Math (To make the camera walk on the hills)
    float fract(float x);
    float hash(float px, float py);
    float mix(float x, float y, float a);
    float smoothstep(float edge0, float edge1, float x);
    float noise(float px, float py);
    float fbm(float px, float py);
    float getElevation(float px, float pz);
};
