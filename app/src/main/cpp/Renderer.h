#pragma once
#include <GLES3/gl31.h>

class GrassRenderer {
private:
    GLuint computeProgram, renderProgram, ssbo, vao, vbo;
    const int GRASS_COUNT = 256 * 256; 

public:
    GrassRenderer() : computeProgram(0), renderProgram(0), ssbo(0), vao(0), vbo(0) {}
    void init();
    void updateAndRender(float time, float deltaTime);
};
