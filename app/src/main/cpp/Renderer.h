#pragma once
#include <GLES3/gl31.h>

class GrassRenderer {
private:
    GLuint computeProgram;
    GLuint renderProgram;
    GLuint ssbo;
    GLuint vao, vbo;
    
    // 256x256 grid of grass per terrain chunk
    const int GRASS_COUNT = 256 * 256; 

public:
    GrassRenderer() : computeProgram(0), renderProgram(0), ssbo(0), vao(0), vbo(0) {}
    ~GrassRenderer() = default;

    void init();
    void updateAndRender(float time, float deltaTime);
};
