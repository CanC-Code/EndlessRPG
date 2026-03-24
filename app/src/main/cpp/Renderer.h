#pragma once
#include <GLES3/gl31.h>
#include <string>

class GrassRenderer {
private:
    GLuint computeProgram, renderProgram, ssbo, vao, vbo;
    const int GRASS_COUNT = 256 * 256; 

    GLuint compileShader(GLenum type, const std::string& source);
    GLuint createProgram(GLuint v, GLuint f);
    GLuint createComputeProgram(GLuint c);
    
    void buildPerspective(float* m, float fov, float aspect, float zn, float zf);
    void buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz);
    void multiply(float* out, const float* a, const float* b);

public:
    GrassRenderer();
    void init();
    void updateAndRender(float time, float dt, int w, int h);
};
