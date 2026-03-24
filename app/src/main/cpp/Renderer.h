#pragma once
#include <GLES3/gl31.h>   // ES 3.1 header (compute shaders, vertex-stage SSBOs)
#include <string>

// 512×512 = 262 144 grass blades.  Reduce to 128×128 (16 384) if the GPU stalls.
const int GRASS_GRID = 512;
const int GRASS_COUNT = GRASS_GRID * GRASS_GRID;  // 262 144

class GrassRenderer {
public:
    GrassRenderer();
    void init();   // Must be called on the render thread after EGL context is live.
    void updateAndRender(float time, float deltaTime, int screenWidth, int screenHeight);

    // Camera state — public so the RenderLoop or a future input system can drive it.
    float camX = 0.0f;
    float camY = 1.8f;   // Eye height in metres
    float camZ = 0.0f;

private:
    GLuint computeProgram, renderProgram;
    GLuint ssbo, vao, vbo;

    GLuint compileShader(GLenum type, const std::string& source);
    GLuint createProgram(GLuint vShader, GLuint fShader);
    GLuint createComputeProgram(GLuint cShader);

    void buildPerspective(float* m, float fov, float aspect, float zNear, float zFar);

    // Takes an explicit world-up vector so the caller is unambiguous.
    void buildLookAt(float* m,
                     float ex, float ey, float ez,   // eye
                     float cx, float cy, float cz,   // centre / target
                     float ux, float uy, float uz);  // world-up  (use 0,1,0)

    void multiply(float* out, const float* a, const float* b);
};
