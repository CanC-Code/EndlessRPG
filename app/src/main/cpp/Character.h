#pragma once
#include <GLES3/gl31.h>
#include <vector>

struct CharacterVertex {
    float x, y, z;
    float nx, ny, nz; // Normals for lighting
};

class Character {
public:
    Character();
    void init();
    void render(const float* viewProjection, float playerX, float playerY, float playerZ, float yaw);

private:
    GLuint program;
    GLuint vao, vbo;
    int vertexCount;

    GLuint compileShader(GLenum type, const char* source);
    GLuint createProgram(const char* vSrc, const char* fSrc);
};
