#include "Renderer.h"
#include "AssetManager.h" // Includes your NativeAssetManager class
#include <cmath>
#include <vector>
#include <string>
#include <cstdlib>
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
    playerX = 0.0f; playerZ = 0.0f; playerYaw = 0.0f;
    camX = 0.0f; camY = 0.0f; camZ = 0.0f;
    camYaw = 0.0f; camPitch = 0.0f;
    moveX = 0.0f; moveY = 0.0f; cameraZoom = 5.0f;
    isThirdPerson = false;
    
    velocityX = 0.0f; velocityZ = 0.0f;
    smoothPitch = 0.0f; smoothRoll = 0.0f;
    
    // Spawn character exactly on surface elevation
    playerY = getElevation(0.0f, 0.0f);
}

float GrassRenderer::getElevation(float x, float z) {
    float p_x = x * 0.005f; float p_y = 0.0f; float p_z = z * 0.005f;
    
    float h = noise3(p_x, p_y, p_z) * 35.0f;
    h += noise3(p_x * 4.0f, p_y * 4.0f, p_z * 4.0f) * 12.0f;
    h += noise3(p_x * 10.0f, p_y * 10.0f, p_z * 10.0f) * 3.0f;
    
    return h;
}

void GrassRenderer::init() {
    // 1. Load and compile shaders using NativeAssetManager
    std::string tv = NativeAssetManager::loadShaderText("shaders/terrain.vert");
    std::string tf = NativeAssetManager::loadShaderText("shaders/terrain.frag");
    terrainProgram = createProgram(compileShader(GL_VERTEX_SHADER, tv), compileShader(GL_FRAGMENT_SHADER, tf));

    std::string gv = NativeAssetManager::loadShaderText("shaders/grass.vert");
    std::string gf = NativeAssetManager::loadShaderText("shaders/grass.frag");
    renderProgram = createProgram(compileShader(GL_VERTEX_SHADER, gv), compileShader(GL_FRAGMENT_SHADER, gf));

    // 2. Generate geometry
    generateTerrainGrid();

    // 3. Generate Grass Instances
    std::vector<float> instData;
    for(int i = 0; i < GRASS_COUNT; i++) {
        float gx = (rand() % 10000 / 100.0f) - 50.0f; // Random X spread
        float gz = (rand() % 10000 / 100.0f) - 50.0f; // Random Z spread
        float gy = getElevation(gx, gz); // Plant exactly on the terrain
        instData.push_back(gx);
        instData.push_back(gy);
        instData.push_back(gz);
        instData.push_back(1.0f); // Scale
    }

    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    // Simple blade of grass geometry
    float blade[] = { -0.05f, 0.0f, 0.0f,  0.05f, 0.0f, 0.0f,  0.0f, 0.8f, 0.0f };
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(blade), blade, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, (void*)0);

    // Instance positions buffer
    glGenBuffers(1, &instanceVbo);
    glBindBuffer(GL_ARRAY_BUFFER, instanceVbo);
    glBufferData(GL_ARRAY_BUFFER, instData.size() * sizeof(float), instData.data(), GL_STATIC_DRAW);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 0, (void*)0);
    glVertexAttribDivisor(1, 1); // Tell OpenGL this advances once per instance

    glBindVertexArray(0);

    // 4. Initialize Character
    playerModel.init();

    glClearColor(0.5f, 0.7f, 1.0f, 1.0f);
    glEnable(GL_DEPTH_TEST);
}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx; moveY = my;
    camYaw += lx * 0.01f;
    camPitch += ly * 0.01f;
    isThirdPerson = tp;
    cameraZoom = zoom;
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    float dtSafe = (dt > 0.033f) ? 0.033f : dt;
    float speed = 5.0f * dtSafe;
    
    // Calculate movement based on camera angle
    velocityX = std::sin(-camYaw) * moveY * speed;
    velocityZ = -std::cos(-camYaw) * moveY * speed;
    
    playerX += velocityX;
    playerZ += velocityZ;
    
    // Snap character to actual terrain elevation
    float targetY = getElevation(playerX, playerZ); 
    if (playerY < targetY) {
        playerY = targetY; // Snap up
    } else {
        playerY += (targetY - playerY) * 15.0f * dtSafe; // Smooth fall
    }
    
    // Position Camera and Calculate Look Target
    float lookX, lookY, lookZ;
    
    if (isThirdPerson) {
        camX = playerX - std::sin(-camYaw) * cameraZoom;
        camZ = playerZ + std::cos(-camYaw) * cameraZoom;
        camY = playerY + 2.0f + std::sin(camPitch) * cameraZoom;
        
        // Look at the player
        lookX = playerX;
        lookY = playerY + 1.0f;
        lookZ = playerZ;
    } else {
        camX = playerX;
        camY = playerY + 1.8f; // Eye level
        camZ = playerZ;
        
        // Look FORWARD (Prevents looking straight down and breaking the math)
        lookX = camX + std::sin(-camYaw);
        lookY = camY + std::sin(camPitch);
        lookZ = camZ - std::cos(-camYaw);
    }
    
    glViewport(0, 0, width, height);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Calculate View-Projection Matrix
    float proj[16];
    buildPerspective(proj, 60.0f * M_PI / 180.0f, (float)width / (float)height, 0.1f, 200.0f);
    
    float view[16];
    buildLookAt(view, camX, camY, camZ, lookX, lookY, lookZ);
    
    float viewProj[16];
    multiply(viewProj, proj, view);
    
    // === RENDER PASSES ===
    
    // 1. Draw Terrain
    if (terrainProgram) {
        glUseProgram(terrainProgram);
        // FIX: Match the exact uniform name expected by your terrain.vert shader (uVP)
        glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "uVP"), 1, GL_FALSE, viewProj);
        glBindVertexArray(terrainVao);
        glDrawArrays(GL_TRIANGLES, 0, terrainIndexCount);
    }
    
    // 2. Draw Grass (Instanced)
    if (renderProgram) {
        glUseProgram(renderProgram);
        // FIX: Match the exact uniform name expected by your grass.vert shader (uVP)
        glUniformMatrix4fv(glGetUniformLocation(renderProgram, "uVP"), 1, GL_FALSE, viewProj);
        glUniform1f(glGetUniformLocation(renderProgram, "uTime"), time);
        glBindVertexArray(vao);
        glDrawArraysInstanced(GL_TRIANGLES, 0, 3, GRASS_COUNT);
    }
    
    // 3. Draw Character 
    playerModel.render(viewProj, playerX, playerY, playerZ, playerYaw, 0.0f, 0.0f, camX, camZ);
}

void GrassRenderer::generateTerrainGrid() {
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

// --- ACTUAL MATRIX MATH ---

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
    // Calculate forward vector
    float fx = cx - ex; float fy = cy - ey; float fz = cz - ez;
    float flen = std::sqrt(fx*fx + fy*fy + fz*fz);
    if (flen > 0.0001f) { fx /= flen; fy /= flen; fz /= flen; }

    // World up
    float ux = 0.0f, uy = 1.0f, uz = 0.0f;

    // Calculate Right vector (Forward cross Up)
    float rx = fy * uz - fz * uy;
    float ry = fz * ux - fx * uz;
    float rz = fx * uy - fy * ux;
    float rlen = std::sqrt(rx*rx + ry*ry + rz*rz);
    if (rlen > 0.0001f) { rx /= rlen; ry /= rlen; rz /= rlen; }

    // Recalculate Up vector (Right cross Forward) to ensure orthogonal angles
    ux = ry * fz - rz * fy;
    uy = rz * fx - rx * fz;
    uz = rx * fy - ry * fx;

    // Populate LookAt Matrix
    m[0] = rx;  m[1] = ux;  m[2] = -fx; m[3] = 0.0f;
    m[4] = ry;  m[5] = uy;  m[6] = -fy; m[7] = 0.0f;
    m[8] = rz;  m[9] = uz;  m[10] = -fz; m[11] = 0.0f;
    m[12] = -(rx*ex + ry*ey + rz*ez);
    m[13] = -(ux*ex + uy*ey + uz*ez);
    m[14] = fx*ex + fy*ey + fz*ez;
    m[15] = 1.0f;
}

void GrassRenderer::multiply(float* out, const float* a, const float* b) {
    // Standard Column-Major Matrix Multiplication
    for (int col = 0; col < 4; ++col) {
        for (int row = 0; row < 4; ++row) {
            out[col * 4 + row] =
                a[0 * 4 + row] * b[col * 4 + 0] +
                a[1 * 4 + row] * b[col * 4 + 1] +
                a[2 * 4 + row] * b[col * 4 + 2] +
                a[3 * 4 + row] * b[col * 4 + 3];
        }
    }
}
