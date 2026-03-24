#pragma once
#include <GLES3/gl31.h>
#include <string>

// 512 * 512 instances for a dense field
const int GRASS_COUNT = 262144; 

class GrassRenderer {
public:
    GrassRenderer();
    void init();
    void updateAndRender(float time, float deltaTime, int screenWidth, int screenHeight);

private:
    GLuint computeProgram;
    GLuint renderProgram;
    GLuint ssbo;
    GLuint vao;
    GLuint vbo;

    GLuint compileShader(GLenum type, const std::string& source);
    GLuint createProgram(GLuint vertexShader, GLuint fragmentShader);
    GLuint createComputeProgram(GLuint computeShader);

    void buildPerspective(float* m, float fov, float aspect, float zNear, float zFar);
    void buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz);
    void multiply(float* out, const float* a, const float* b);
};
