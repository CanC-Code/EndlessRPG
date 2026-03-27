#include "renderer.h"
#include <cmath>
#include <vector>
#include <string>
#include <android/log.h>

#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "GameEngine", __VA_ARGS__)

// --- C++ equivalents of GLSL math functions (Fix for Bug 1) ---
inline float fract(float x) {
    return x - std::floor(x);
}

inline float mix(float x, float y, float a) {
    return x * (1.0f - a) + y * a;
}

// 3D Hash mimicking the GPU precisely
float hash3(float px, float py, float pz) {
    float p3x = fract(px * 0.1031f);
    float p3y = fract(py * 0.1030f);
    float p3z = fract(pz * 0.0973f);
    
    float dot_val = (p3x * (p3y + 33.33f)) + (p3y * (p3z + 33.33f)) + (p3z * (p3x + 33.33f));
    
    p3x += dot_val; 
    p3y += dot_val; 
    p3z += dot_val;
    return fract((p3x + p3y) * p3z);
}

// 3D Noise mimicking the GPU precisely
float noise3(float x, float y, float z) {
    float ix = std::floor(x); float iy = std::floor(y); float iz = std::floor(z);
    float fx = fract(x); float fy = fract(y); float fz = fract(z);
    
    float ux = fx * fx * (3.0f - 2.0f * fx);
    float uy = fy * fy * (3.0f - 2.0f * fy);
    float uz = fz * fz * (3.0f - 2.0f * fz);

    float n000 = hash3(ix, iy, iz);
    float n100 = hash3(ix + 1.0f, iy, iz);
    float n010 = hash3(ix, iy + 1.0f, iz);
    float n110 = hash3(ix + 1.0f, iy + 1.0f, iz);
    float n001 = hash3(ix, iy, iz + 1.0f);
    float n101 = hash3(ix + 1.0f, iy, iz + 1.0f);
    float n011 = hash3(ix, iy + 1.0f, iz + 1.0f);
    float n111 = hash3(ix + 1.0f, iy + 1.0f, iz + 1.0f);

    float nx00 = mix(n000, n100, ux);
    float nx10 = mix(n010, n110, ux);
    float nx01 = mix(n001, n101, ux);
    float nx11 = mix(n011, n111, ux);

    float nxy0 = mix(nx00, nx10, uy);
    float nxy1 = mix(nx01, nx11, uy);

    return mix(nxy0, nxy1, uz);
}

// --- Class Implementation ---

GrassRenderer::GrassRenderer() {
    // Initialize Transformation State
    playerX = 0.0f;
    playerZ = 0.0f;
    playerYaw = 0.0f;
    camX = 0.0f; camY = 0.0f; camZ = 0.0f;
    camYaw = 0.0f; camPitch = 0.0f;
    moveX = 0.0f; moveY = 0.0f; cameraZoom = 5.0f;
    isThirdPerson = false;
    
    // Initialize Physics State
    velocityX = 0.0f; 
    velocityZ = 0.0f;
    smoothPitch = 0.0f; 
    smoothRoll = 0.0f;
    
    // FIX BUG 2: Spawn character exactly on surface elevation
    playerY = getElevation(0.0f, 0.0f);
}

float GrassRenderer::getElevation(float x, float z) {
    float p_x = x * 0.005f;
    float p_y = 0.0f;
    float p_z = z * 0.005f;
    
    // Exact 3 octaves mapped to the GPU
    float h = noise3(p_x, p_y, p_z) * 35.0f;
    h += noise3(p_x * 4.0f, p_y * 4.0f, p_z * 4.0f) * 12.0f;
    h += noise3(p_x * 10.0f, p_y * 10.0f, p_z * 10.0f) * 3.0f;
    
    return h;
}

void GrassRenderer::init() {
    // Called to initialize GL state (VBOs, VAOs, shaders)
    generateTerrainGrid();
    glClearColor(0.5f, 0.7f, 1.0f, 1.0f);
    glEnable(GL_DEPTH_TEST);
}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx;
    moveY = my;
    camYaw += lx * 0.01f;
    camPitch += ly * 0.01f;
    isThirdPerson = tp;
    cameraZoom = zoom;
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    float dtSafe = (dt > 0.033f) ? 0.033f : dt;
    float speed = 5.0f * dtSafe;
    
    // Basic physics / movement implementation using your velocity variables
    velocityX = std::sin(-playerYaw) * moveY * speed;
    velocityZ = -std::cos(-playerYaw) * moveY * speed;
    
    playerX += velocityX;
    playerZ += velocityZ;
    
    // Terrain collision resolution
    float targetY = getElevation(playerX, playerZ) + 1.8f; 
    
    if (playerY < targetY) {
        playerY = targetY; // Snap up
    } else {
        playerY += (targetY - playerY) * 15.0f * dtSafe; // Smooth fall
    }
    
    glViewport(0, 0, width, height);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // (Rendering logic placeholder - matrix math will go here)
}

void GrassRenderer::generateTerrainGrid() {
    // Basic terrain generation logic
    std::vector<float> vertices;
    for(int z = -50; z < 50; z++) {
        for(int x = -50; x < 50; x++) {
            vertices.push_back(x); vertices.push_back(z);
            vertices.push_back(x+1); vertices.push_back(z);
            vertices.push_back(x); vertices.push_back(z+1);
            vertices.push_back(x+1); vertices.push_back(z);
            vertices.push_back(x+1); vertices.push_back(z+1);
            vertices.push_back(x); vertices.push_back(z+1);
        }
    }
    terrainIndexCount = vertices.size() / 2;
    glGenVertexArrays(1, &terrainVao);
    glBindVertexArray(terrainVao);
    glGenBuffers(1, &terrainVbo);
    glBindBuffer(GL_ARRAY_BUFFER, terrainVbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glBindVertexArray(0);
}

GLuint GrassRenderer::compileShader(GLenum type, const std::string& source) {
    GLuint shader = glCreateShader(type);
    const char* src = source.c_str();
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);
    
    GLint compiled;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) {
        GLint infoLen = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);
        if (infoLen) {
            std::vector<char> infoLog(infoLen);
            glGetShaderInfoLog(shader, infoLen, nullptr, infoLog.data());
            LOGE("Shader compilation failed: %s", infoLog.data());
        }
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

GLuint GrassRenderer::createProgram(GLuint vS, GLuint fS) {
    GLuint prog = glCreateProgram();
    glAttachShader(prog, vS);
    glAttachShader(prog, fS);
    glLinkProgram(prog);
    return prog;
}

GLuint GrassRenderer::createComputeProgram(GLuint cS) {
    GLuint prog = glCreateProgram();
    glAttachShader(prog, cS);
    glLinkProgram(prog);
    return prog;
}

void GrassRenderer::buildPerspective(float* m, float fov, float aspect, float zn, float zf) {
    float f = 1.0f / std::tan(fov / 2.0f);
    for (int i=0; i<16; i++) m[i] = 0.0f;
    m[0] = f / aspect;
    m[5] = f;
    m[10] = -(zf + zn) / (zf - zn);
    m[11] = -1.0f;
    m[14] = -(2.0f * zf * zn) / (zf - zn);
}

void GrassRenderer::buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz) {
    // Dummy identity implementation to fulfill linker - replace with your math
    for(int i=0; i<16; i++) m[i] = (i%5==0)?1.0f:0.0f;
}

void GrassRenderer::multiply(float* out, const float* a, const float* b) {
    // Dummy identity implementation to fulfill linker - replace with your math
    for(int i=0; i<16; i++) out[i] = a[i];
}
