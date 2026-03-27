#include "Renderer.h"
#include "AssetManager.h" 
#include <cmath>
#include <vector>
#include <string>
#include <cstdlib>
#include <android/log.h>

#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "GameEngine", __VA_ARGS__)

// --- C++ equivalents of GLSL math functions ---
inline float fract(float x) { return x - std::floor(x); }
inline float mix(float x, float y, float a) { return x * (1.0f - a) + y * a; }

float hash3(float px, float py, float pz) {
    float p3x = fract(px * 0.1031f);
    float p3y = fract(py * 0.1030f);
    float p3z = fract(pz * 0.0973f);
    float dot_val = (p3x * (p3y + 33.33f)) + (p3y * (p3z + 33.33f)) + (p3z * (p3x + 33.33f));
    p3x += dot_val; p3y += dot_val; p3z += dot_val;
    return fract((p3x + p3y) * p3z);
}

float noise3(float x, float y, float z) {
    float ix = std::floor(x); float iy = std::floor(y); float iz = std::floor(z);
    float fx = fract(x); float fy = fract(y); float fz = fract(z);
    float ux = fx * fx * (3.0f - 2.0f * fx);
    float uy = fy * fy * (3.0f - 2.0f * fy);
    float uz = fz * fz * (3.0f - 2.0f * fz);

    float n000 = hash3(ix, iy, iz); float n100 = hash3(ix + 1.0f, iy, iz);
    float n010 = hash3(ix, iy + 1.0f, iz); float n110 = hash3(ix + 1.0f, iy + 1.0f, iz);
    float n001 = hash3(ix, iy, iz + 1.0f); float n101 = hash3(ix + 1.0f, iy, iz + 1.0f);
    float n011 = hash3(ix, iy + 1.0f, iz + 1.0f); float n111 = hash3(ix + 1.0f, iy + 1.0f, iz + 1.0f);

    float nx00 = mix(n000, n100, ux); float nx10 = mix(n010, n110, ux);
    float nx01 = mix(n001, n101, ux); float nx11 = mix(n011, n111, ux);
    float nxy0 = mix(nx00, nx10, uy); float nxy1 = mix(nx01, nx11, uy);

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
    // 1. Reintroduce Compute Shader Logic
    std::string cs = NativeAssetManager::loadShaderText("shaders/grass.comp");
    if(!cs.empty()) computeProgram = createComputeProgram(compileShader(GL_COMPUTE_SHADER, cs));

    // Initialize SSBO for Grass Compute Shader
    glGenBuffers(1, &ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    // Allocate buffer size (assuming generous 64 bytes per blade for position, physics, etc)
    glBufferData(GL_SHADER_STORAGE_BUFFER, GRASS_COUNT * 64, nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);

    // 2. Load Graphics Shaders
    std::string tv = NativeAssetManager::loadShaderText("shaders/terrain.vert");
    std::string tf = NativeAssetManager::loadShaderText("shaders/terrain.frag");
    terrainProgram = createProgram(compileShader(GL_VERTEX_SHADER, tv), compileShader(GL_FRAGMENT_SHADER, tf));

    std::string gv = NativeAssetManager::loadShaderText("shaders/grass.vert");
    std::string gf = NativeAssetManager::loadShaderText("shaders/grass.frag");
    renderProgram = createProgram(compileShader(GL_VERTEX_SHADER, gv), compileShader(GL_FRAGMENT_SHADER, gf));

    // 3. Generate Terrain & Geometry
    generateTerrainGrid();

    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    float blade[] = { -0.05f, 0.0f, 0.0f,  0.05f, 0.0f, 0.0f,  0.0f, 0.8f, 0.0f };
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(blade), blade, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, (void*)0);
    glBindVertexArray(0);

    // 4. Initialize Character
    playerModel.init();

    glClearColor(0.5f, 0.7f, 1.0f, 1.0f); // Beautiful blue sky
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
    float speed = 15.0f * dtSafe;
    
    velocityX = std::sin(-camYaw) * moveY * speed;
    velocityZ = -std::cos(-camYaw) * moveY * speed;
    
    playerX += velocityX;
    playerZ += velocityZ;
    
    float targetY = getElevation(playerX, playerZ); 
    if (playerY < targetY) playerY = targetY; 
    else playerY += (targetY - playerY) * 15.0f * dtSafe; 
    
    // Position Camera perfectly (Spherical coordinate math prevents looking "straight down" bug)
    float lookX, lookY, lookZ;
    if (isThirdPerson) {
        camX = playerX - std::sin(-camYaw) * cameraZoom;
        camZ = playerZ + std::cos(-camYaw) * cameraZoom;
        camY = playerY + 2.0f + std::sin(camPitch) * cameraZoom;
        lookX = playerX; lookY = playerY + 1.0f; lookZ = playerZ;
    } else {
        camX = playerX; camY = playerY + 1.8f; camZ = playerZ;
        float dirX = std::sin(-camYaw) * std::cos(camPitch);
        float dirY = std::sin(camPitch);
        float dirZ = -std::cos(-camYaw) * std::cos(camPitch);
        lookX = camX + dirX; lookY = camY + dirY; lookZ = camZ + dirZ;
    }
    
    glViewport(0, 0, width, height);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Matrix calculations
    float proj[16]; buildPerspective(proj, 60.0f * M_PI / 180.0f, (float)width / (float)height, 0.1f, 500.0f);
    float view[16]; buildLookAt(view, camX, camY, camZ, lookX, lookY, lookZ);
    float viewProj[16]; multiply(viewProj, proj, view);
    
    // === 1. DISPATCH COMPUTE SHADER ===
    if (computeProgram) {
        glUseProgram(computeProgram);
        glUniform1f(glGetUniformLocation(computeProgram, "uTime"), time);
        glUniform3f(glGetUniformLocation(computeProgram, "uPlayerPos"), playerX, playerY, playerZ);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
        glDispatchCompute(GRASS_COUNT / 64, 1, 1); // Group size of 64
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT | GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT);
    }
    
    // === 2. RENDER TERRAIN ===
    if (terrainProgram) {
        glUseProgram(terrainProgram);
        // Blanket-cover uniforms just in case of different naming conventions
        glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "uVP"), 1, GL_FALSE, viewProj);
        glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "uViewProj"), 1, GL_FALSE, viewProj);
        glBindVertexArray(terrainVao);
        // Restored EBO Logic!
        glDrawElements(GL_TRIANGLES, terrainIndexCount, GL_UNSIGNED_INT, 0); 
    }
    
    // === 3. RENDER GRASS ===
    if (renderProgram) {
        glUseProgram(renderProgram);
        glUniformMatrix4fv(glGetUniformLocation(renderProgram, "uVP"), 1, GL_FALSE, viewProj);
        glUniformMatrix4fv(glGetUniformLocation(renderProgram, "uViewProj"), 1, GL_FALSE, viewProj);
        glUniform1f(glGetUniformLocation(renderProgram, "uTime"), time);
        glBindVertexArray(vao);
        glDrawArraysInstanced(GL_TRIANGLES, 0, 3, GRASS_COUNT);
    }
    
    // === 4. RENDER CHARACTER ===
    playerModel.render(viewProj, playerX, playerY, playerZ, playerYaw, 0.0f, 0.0f, camX, camZ);
}

void GrassRenderer::generateTerrainGrid() {
    // Restored Element Buffer Object (EBO) Logic for smooth connected terrain
    std::vector<float> vertices;
    std::vector<unsigned int> indices;
    int gridWidth = 150;
    int gridDepth = 150;
    
    // Generate vertices centered around 0
    for(int z = 0; z < gridDepth; z++) {
        for(int x = 0; x < gridWidth; x++) {
            vertices.push_back(x - gridWidth/2.0f);
            vertices.push_back(z - gridDepth/2.0f);
        }
    }
    // Generate indices
    for(int z = 0; z < gridDepth - 1; z++) {
        for(int x = 0; x < gridWidth - 1; x++) {
            int topLeft = z * gridWidth + x;
            int topRight = topLeft + 1;
            int bottomLeft = (z + 1) * gridWidth + x;
            int bottomRight = bottomLeft + 1;
            
            indices.push_back(topLeft);
            indices.push_back(bottomLeft);
            indices.push_back(topRight);
            indices.push_back(topRight);
            indices.push_back(bottomLeft);
            indices.push_back(bottomRight);
        }
    }
    
    terrainIndexCount = indices.size();
    
    glGenVertexArrays(1, &terrainVao);
    glBindVertexArray(terrainVao);
    
    glGenBuffers(1, &terrainVbo);
    glBindBuffer(GL_ARRAY_BUFFER, terrainVbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);

    glGenBuffers(1, &terrainEbo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, terrainEbo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned int), indices.data(), GL_STATIC_DRAW);
    
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
    m[0] = f / aspect; m[5] = f;
    m[10] = -(zf + zn) / (zf - zn); m[11] = -1.0f;
    m[14] = -(2.0f * zf * zn) / (zf - zn);
}

void GrassRenderer::buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz) {
    float fx = cx - ex; float fy = cy - ey; float fz = cz - ez;
    float flen = std::sqrt(fx*fx + fy*fy + fz*fz);
    if (flen > 0.0001f) { fx /= flen; fy /= flen; fz /= flen; }

    float ux = 0.0f, uy = 1.0f, uz = 0.0f;
    float rx = fy * uz - fz * uy; float ry = fz * ux - fx * uz; float rz = fx * uy - fy * ux;
    float rlen = std::sqrt(rx*rx + ry*ry + rz*rz);
    if (rlen > 0.0001f) { rx /= rlen; ry /= rlen; rz /= rlen; }

    ux = ry * fz - rz * fy; uy = rz * fx - rx * fz; uz = rx * fy - ry * fx;

    m[0] = rx; m[1] = ux; m[2] = -fx; m[3] = 0.0f;
    m[4] = ry; m[5] = uy; m[6] = -fy; m[7] = 0.0f;
    m[8] = rz; m[9] = uz; m[10] = -fz; m[11] = 0.0f;
    m[12] = -(rx*ex + ry*ey + rz*ez);
    m[13] = -(ux*ex + uy*ey + uz*ez);
    m[14] = fx*ex + fy*ey + fz*ez;
    m[15] = 1.0f;
}

void GrassRenderer::multiply(float* out, const float* a, const float* b) {
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
