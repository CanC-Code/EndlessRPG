#pragma once
#include <GLES3/gl31.h>
#include <string>

class GrassRenderer {
private:
    GLuint computeProgram;
    GLuint renderProgram;
    GLuint ssbo;
    GLuint vao, vbo;
    
    const int GRASS_COUNT = 256 * 256; 

    // Internal helpers for shader compilation and matrix math
    GLuint compileShader(GLenum type, const std::string& source);
    GLuint createProgram(GLuint vertexShader, GLuint fragmentShader);
    GLuint createComputeProgram(GLuint computeShader);
    
    void buildPerspectiveMatrix(float* m, float fov, float aspect, float zNear, float zFar);
    void buildLookAtMatrix(float* m, float ex, float ey, float ez, float cx, float cy, float cz);
    void multiplyMatrix(float* out, const float* a, const float* b);

public:
    GrassRenderer() : computeProgram(0), renderProgram(0), ssbo(0), vao(0), vbo(0) {}
    ~GrassRenderer() = default;

    void init();
    void updateAndRender(float time, float deltaTime, int screenWidth, int screenHeight);
};
