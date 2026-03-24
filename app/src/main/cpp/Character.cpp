#include "Character.h"
#include "AssetManager.h"
#include <cmath>

Character::Character() : program(0), vao(0), vbo(0), vertexCount(0) {}

void Character::init() {
    std::string vSrc = NativeAssetManager::loadShaderText("shaders/character.vert");
    std::string fSrc = NativeAssetManager::loadShaderText("shaders/character.frag");
    program = createProgram(vSrc.c_str(), fSrc.c_str());

    // Create a simple "humanoid" block proxy: 
    // Head, Torso, and Arms represented by a structured box
    std::vector<CharacterVertex> vertices = {
        // Front Face (Normal 0,0,1)
        {-0.3f, 0.0f, 0.2f, 0,0,1}, {0.3f, 0.0f, 0.2f, 0,0,1}, {0.3f, 1.8f, 0.2f, 0,0,1},
        {-0.3f, 0.0f, 0.2f, 0,0,1}, {0.3f, 1.8f, 0.2f, 0,0,1}, {-0.3f, 1.8f, 0.2f, 0,0,1},
        // Back Face (Normal 0,0,-1)
        {-0.3f, 0.0f, -0.2f, 0,0,-1}, {-0.3f, 1.8f, -0.2f, 0,0,-1}, {0.3f, 1.8f, -0.2f, 0,0,-1},
        {-0.3f, 0.0f, -0.2f, 0,0,-1}, {0.3f, 1.8f, -0.2f, 0,0,-1}, {0.3f, 0.0f, -0.2f, 0,0,-1}
        // ... (Other sides omitted for brevity, but you can expand this to a full cube)
    };

    vertexCount = vertices.size();
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(CharacterVertex), vertices.data(), GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(CharacterVertex), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(CharacterVertex), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);
}

void Character::render(const float* vp, float px, float py, float pz, float yaw) {
    glUseProgram(program);

    // Pass character transform
    glUniformMatrix4fv(glGetUniformLocation(program, "u_VP"), 1, GL_FALSE, vp);
    glUniform3f(glGetUniformLocation(program, "u_Pos"), px, py, pz);
    glUniform1f(glGetUniformLocation(program, "u_Yaw"), yaw * (M_PI / 180.0f));

    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, vertexCount);
}

// Shader utilities (standard boilerplate)
GLuint Character::compileShader(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    return s;
}

GLuint Character::createProgram(const char* v, const char* f) {
    GLuint p = glCreateProgram();
    glAttachShader(p, compileShader(GL_VERTEX_SHADER, v));
    glAttachShader(p, compileShader(GL_FRAGMENT_SHADER, f));
    glLinkProgram(p);
    return p;
}
