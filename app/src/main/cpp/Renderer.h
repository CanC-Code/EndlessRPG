#pragma once
#include <GLES3/gl31.h>
#include <string>
#include "Character.h"

class GrassRenderer {
public:
    GrassRenderer();
    void init();
    void updateAndRender(float time, float dt, int width, int height);
    void updateInput(float mx, float my, float lx, float ly, bool tp, float zoom);

private:
    GLuint compileShader(GLenum type, const std::string& source);
    GLuint createProgram(GLuint vShader, GLuint fShader);
    GLuint createComputeProgram(GLuint cShader);
    void generateTerrainGrid();
    float getElevation(float x, float z);
    void buildPerspective(float* m, float fov, float aspect, float zn, float zf);
    void buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz);
    void multiply(float* out, const float* a, const float* b);

    GLuint computeProgram, renderProgram, terrainProgram;
    GLuint ssbo, vao, vbo;
    GLuint terrainVao, terrainVbo, terrainEbo;
    int terrainIndexCount;

    Character playerModel;

    float playerX, playerY, playerZ;
    float playerYaw; // NEW: Independent body rotation
    float camX, camY, camZ;
    float camYaw, camPitch;
    float moveX, moveY;
    bool isThirdPerson;
    float cameraZoom;

    const int GRASS_COUNT = 60000;
};
