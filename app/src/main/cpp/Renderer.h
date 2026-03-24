#pragma once
#include <GLES3/gl31.h>
#include <string>

const int GRASS_COUNT = 262144; 

class GrassRenderer {
public:
    GrassRenderer();
    void init();
    void updateAndRender(float time, float deltaTime, int screenWidth, int screenHeight);

    // Camera variables for infinite generation
    float camX = 0.0f;
    float camY = 1.8f;
    float camZ = 0.0f;

private:
    GLuint computeProgram, renderProgram;
    GLuint ssbo, vao, vbo;

    GLuint compileShader(GLenum type, const std::string& source);
    GLuint createProgram(GLuint vShader, GLuint fShader);
    GLuint createComputeProgram(GLuint cShader);

    void buildPerspective(float* m, float fov, float aspect, float zNear, float zFar);
    void buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz);
    void multiply(float* out, const float* a, const float* b);
};
