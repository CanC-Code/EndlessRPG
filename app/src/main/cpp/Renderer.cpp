#include "Renderer.h"
#include "AssetManager.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>
#include <vector>
#include <chrono>
#include <thread>

#define LOG_TAG "GrassEngine"

const float EARTH_RADIUS = 6371000.0f;
const float EARTH_CIRCUMFERENCE = 2.0f * M_PI * EARTH_RADIUS;

GrassRenderer::GrassRenderer() : computeProgram(0), renderProgram(0), terrainProgram(0), 
                                 ssbo(0), vao(0), vbo(0), 
                                 terrainVao(0), terrainVbo(0), terrainEbo(0), terrainIndexCount(0),
                                 playerX(0.0f), playerY(0.0f), playerZ(0.0f),
                                 camX(0.0f), camY(1.8f), camZ(0.0f),
                                 camYaw(-90.0f), camPitch(0.0f),
                                 moveX(0.0f), moveY(0.0f),
                                 isThirdPerson(false), cameraZoom(12.0f) {}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    if (std::isnan(mx) || std::isnan(my) || std::isnan(lx) || std::isnan(ly)) return;

    moveX = std::clamp(mx, -1.0f, 1.0f); 
    moveY = std::clamp(my, -1.0f, 1.0f);
    isThirdPerson = tp; 
    cameraZoom = std::clamp(zoom, 2.0f, 40.0f);
    
    float sensitivity = 0.25f; 
    camYaw += lx * sensitivity; 
    camPitch -= ly * sensitivity;
    
    camYaw = fmodf(camYaw, 360.0f);
    if (camYaw < 0.0f) camYaw += 360.0f;
    camPitch = std::clamp(camPitch, -85.0f, 85.0f);
}

GLuint GrassRenderer::compileShader(GLenum type, const std::string& source) {
    if (source.empty()) return 0;
    GLuint shader = glCreateShader(type);
    const char* src = source.c_str();
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);
    
    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetShaderInfoLog(shader, 512, nullptr, infoLog);
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, "Shader Error: %s", infoLog);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

GLuint GrassRenderer::createProgram(GLuint vShader, GLuint fShader) {
    if (!vShader || !fShader) return 0;
    GLuint program = glCreateProgram();
    glAttachShader(program, vShader);
    glAttachShader(program, fShader);
    glLinkProgram(program);
    return program;
}

GLuint GrassRenderer::createComputeProgram(GLuint cShader) {
    if (!cShader) return 0;
    GLuint program = glCreateProgram();
    glAttachShader(program, cShader);
    glLinkProgram(program);
    return program;
}

void GrassRenderer::generateTerrainGrid() {
    const int gridSize = 200; 
    const float size = 800.0f; 
    std::vector<float> vertices;
    std::vector<unsigned short> indices;

    for(int z = 0; z <= gridSize; ++z) {
        for(int x = 0; x <= gridSize; ++x) {
            vertices.push_back(-size/2.0f + (float)x/gridSize * size);
            vertices.push_back(-size/2.0f + (float)z/gridSize * size);
        }
    }

    for(int z = 0; z < gridSize; ++z) {
        for(int x = 0; x < gridSize; ++x) {
            int row1 = z * (gridSize + 1);
            int row2 = (z + 1) * (gridSize + 1);
            indices.push_back(row1 + x); indices.push_back(row2 + x); indices.push_back(row1 + x + 1);
            indices.push_back(row1 + x + 1); indices.push_back(row2 + x); indices.push_back(row2 + x + 1);
        }
    }

    terrainIndexCount = indices.size();
    glGenVertexArrays(1, &terrainVao);
    glGenBuffers(1, &terrainVbo); glGenBuffers(1, &terrainEbo);
    glBindVertexArray(terrainVao);
    
    glBindBuffer(GL_ARRAY_BUFFER, terrainVbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, terrainEbo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned short), indices.data(), GL_STATIC_DRAW);
    
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

void GrassRenderer::init() {
    computeProgram = createComputeProgram(compileShader(GL_COMPUTE_SHADER, NativeAssetManager::loadShaderText("shaders/grass.comp")));
    renderProgram = createProgram(compileShader(GL_VERTEX_SHADER, NativeAssetManager::loadShaderText("shaders/grass.vert")), 
                                  compileShader(GL_FRAGMENT_SHADER, NativeAssetManager::loadShaderText("shaders/grass.frag")));
    terrainProgram = createProgram(compileShader(GL_VERTEX_SHADER, NativeAssetManager::loadShaderText("shaders/terrain.vert")), 
                                   compileShader(GL_FRAGMENT_SHADER, NativeAssetManager::loadShaderText("shaders/terrain.frag")));

    playerModel.init();
    generateTerrainGrid();

    glGenBuffers(1, &ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    glBufferData(GL_SHADER_STORAGE_BUFFER, GRASS_COUNT * 8 * sizeof(float), nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);

    // FIXED: Perfect 8-Vertex Rectangular Strip
    float blade[] = { 
        -0.05f, 0.00f, 0.0f,   0.05f, 0.00f, 0.0f, 
        -0.05f, 0.46f, 0.0f,   0.05f, 0.46f, 0.0f, 
        -0.05f, 0.93f, 0.0f,   0.05f, 0.93f, 0.0f, 
        -0.05f, 1.40f, 0.0f,   0.05f, 1.40f, 0.0f 
    };
    
    glGenVertexArrays(1, &vao); glGenBuffers(1, &vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(blade), blade, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    static auto lastFrameTime = std::chrono::high_resolution_clock::now();
    auto currentFrameTime = std::chrono::high_resolution_clock::now();
    float frameDt = std::chrono::duration<float>(currentFrameTime - lastFrameTime).count();
    
    const float TARGET_FPS = 30.0f;
    const float TARGET_DT = 1.0f / TARGET_FPS;
    
    if (frameDt < TARGET_DT) {
        std::this_thread::sleep_for(std::chrono::duration<float>(TARGET_DT - frameDt));
        currentFrameTime = std::chrono::high_resolution_clock::now();
    }
    lastFrameTime = currentFrameTime;

    float dtSafe = std::min(dt, 0.033f);
    glViewport(0, 0, width, height);
    glClearColor(0.45f, 0.6f, 0.8f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if (!computeProgram || !renderProgram || !terrainProgram) return;
    glEnable(GL_DEPTH_TEST);

    float yawRad = camYaw * (M_PI / 180.0f);
    float pitchRad = camPitch * (M_PI / 180.0f);
    
    float lookX = cosf(yawRad) * cosf(pitchRad);
    float lookY = sinf(pitchRad);
    float lookZ = sinf(yawRad) * cosf(pitchRad);
    
    float fwdX = cosf(yawRad), fwdZ = sinf(yawRad);
    float rgtX = cosf(yawRad + M_PI / 2.0f), rgtZ = sinf(yawRad + M_PI / 2.0f);

    playerX += (fwdX * moveY + rgtX * moveX) * 12.0f * dtSafe;
    playerZ += (fwdZ * moveY + rgtZ * moveX) * 12.0f * dtSafe;
    
    playerX = fmodf(playerX, EARTH_CIRCUMFERENCE);
    playerZ = fmodf(playerZ, EARTH_CIRCUMFERENCE);
    playerY = getElevation(playerX, playerZ);

    float tX, tY, tZ;
    if (isThirdPerson) {
        tX = playerX - (lookX * cameraZoom);
        tY = (playerY + 2.0f) - (lookY * cameraZoom);
        tZ = playerZ - (lookZ * cameraZoom);
        float floor = getElevation(tX, tZ) + 0.5f;
        if (tY < floor) tY = floor;
    } else {
        tX = playerX; tY = playerY + 1.8f; tZ = playerZ;
    }

    camX += (tX - camX) * 12.0f * dtSafe;
    camY += (tY - camY) * 12.0f * dtSafe;
    camZ += (tZ - camZ) * 12.0f * dtSafe;

    float proj[16], view[16], vp[16];
    buildPerspective(proj, 0.8f, (float)width / (float)height, 0.1f, 1500.0f);
    
    if (isThirdPerson) buildLookAt(view, 0.0f, camY, 0.0f, playerX - camX, playerY + 1.5f, playerZ - camZ);
    else buildLookAt(view, 0.0f, camY, 0.0f, lookX, camY + lookY, lookZ);
    multiply(vp, proj, view);

    glUseProgram(computeProgram);
    glUniform1f(glGetUniformLocation(computeProgram, "u_Time"), time);
    glUniform3f(glGetUniformLocation(computeProgram, "u_CameraPos"), camX, camY, camZ);
    glDispatchCompute(32, 32, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    glUseProgram(terrainProgram);
    glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glUniform3f(glGetUniformLocation(terrainProgram, "u_CameraPos"), camX, camY, camZ);
    glUniform3f(glGetUniformLocation(terrainProgram, "u_PlayerPos"), playerX, playerY, playerZ);
    glBindVertexArray(terrainVao);
    glDrawElements(GL_TRIANGLES, terrainIndexCount, GL_UNSIGNED_SHORT, 0);

    glUseProgram(renderProgram);
    glUniformMatrix4fv(glGetUniformLocation(renderProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glUniform3f(glGetUniformLocation(renderProgram, "u_CameraPos"), camX, camY, camZ);
    glUniform3f(glGetUniformLocation(renderProgram, "u_PlayerPos"), playerX, playerY, playerZ);
    glBindVertexArray(vao);
    // FIXED: Draws all 8 vertices of the square billboard
    glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 8, GRASS_COUNT);

    if (isThirdPerson) playerModel.render(vp, playerX - camX, playerY, playerZ - camZ, camYaw);
}

float GrassRenderer::getElevation(float x, float z) {
    auto hash3 = [](float px, float py, float pz) {
        float dt = px * 12.9898f + py * 78.233f + pz * 37.719f;
        float f = sinf(dt) * 43758.5453f;
        return f - floorf(f);
    };
    
    auto noise3 = [&](float px, float py, float pz) {
        float ix = floorf(px), iy = floorf(py), iz = floorf(pz);
        float fx = px - ix, fy = py - iy, fz = pz - iz;
        float ux = fx * fx * (3.0f - 2.0f * fx);
        float uy = fy * fy * (3.0f - 2.0f * fy);
        float uz = fz * fz * (3.0f - 2.0f * fz);
        
        float a0 = hash3(ix, iy, iz), a1 = hash3(ix + 1.0f, iy, iz);
        float a2 = hash3(ix, iy + 1.0f, iz), a3 = hash3(ix + 1.0f, iy + 1.0f, iz);
        float a4 = hash3(ix, iy, iz + 1.0f), a5 = hash3(ix + 1.0f, iy, iz + 1.0f);
        float a6 = hash3(ix, iy + 1.0f, iz + 1.0f), a7 = hash3(ix + 1.0f, iy + 1.0f, iz + 1.0f);
        
        float mx0 = a0 + (a1 - a0) * ux; float mx1 = a2 + (a3 - a2) * ux;
        float mx2 = a4 + (a5 - a4) * ux; float mx3 = a6 + (a7 - a6) * ux;
        float my0 = mx0 + (mx1 - mx0) * uy; float my1 = mx2 + (mx3 - mx2) * uy;
        return my0 + (my1 - my0) * uz;
    };

    auto exactElevation = [&](float mapX, float mapZ) {
        float lon = (mapX / EARTH_CIRCUMFERENCE) * 2.0f * M_PI;
        float lat = (mapZ / EARTH_CIRCUMFERENCE) * 2.0f * M_PI;
        
        float sx = cosf(lat) * cosf(lon);
        float sy = sinf(lat);
        float sz = cosf(lat) * sinf(lon);
        
        float noiseScale = 4000.0f; 
        
        float h = noise3(sx * noiseScale * 0.01f, sy * noiseScale * 0.01f, sz * noiseScale * 0.01f) * 30.0f;
        h += noise3(sx * noiseScale * 0.03f, sy * noiseScale * 0.03f, sz * noiseScale * 0.03f) * 10.0f;
        return h;
    };

    float gridSpacing = 4.0f; 
    float cellX = floorf(x / gridSpacing) * gridSpacing;
    float cellZ = floorf(z / gridSpacing) * gridSpacing;
    float tx = (x - cellX) / gridSpacing;
    float tz = (z - cellZ) / gridSpacing;
    
    float h00 = exactElevation(cellX, cellZ);
    float h10 = exactElevation(cellX + gridSpacing, cellZ);
    float h01 = exactElevation(cellX, cellZ + gridSpacing);
    float h11 = exactElevation(cellX + gridSpacing, cellZ + gridSpacing);
    
    if (tx + tz <= 1.0f) return h00 + (h10 - h00) * tx + (h01 - h00) * tz;
    else return h11 + (h01 - h11) * (1.0f - tx) + (h10 - h11) * (1.0f - tz);
}

void GrassRenderer::buildPerspective(float* m, float fov, float aspect, float zn, float zf) {
    float f = 1.0f / tanf(fov / 2.0f);
    std::fill(m, m+16, 0.0f);
    m[0]=f/aspect; m[5]=f; m[10]=(zf+zn)/(zn-zf); m[11]=-1.0f; m[14]=(2.0f*zf*zn)/(zn-zf);
}

void GrassRenderer::buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz) {
    float f[3] = {cx - ex, cy - ey, cz - ez};
    float flen = sqrtf(f[0]*f[0] + f[1]*f[1] + f[2]*f[2]);
    if (flen < 0.00001f) flen = 0.00001f;
    f[0] /= flen; f[1] /= flen; f[2] /= flen;
    
    float up[3] = {0.0f, 1.0f, 0.0f};
    
    float s[3] = { f[1]*up[2] - f[2]*up[1], f[2]*up[0] - f[0]*up[2], f[0]*up[1] - f[1]*up[0] };
    float slen = sqrtf(s[0]*s[0] + s[1]*s[1] + s[2]*s[2]);
    if (slen < 0.00001f) { s[0] = 1.0f; s[1] = 0.0f; s[2] = 0.0f; } 
    else { s[0] /= slen; s[1] /= slen; s[2] /= slen; }
    
    float u[3] = { s[1]*f[2] - s[2]*f[1], s[2]*f[0] - s[0]*f[2], s[0]*f[1] - s[1]*f[0] };
    
    m[0] = s[0];  m[1] = u[0];  m[2] = -f[0]; m[3] = 0.0f;
    m[4] = s[1];  m[5] = u[1];  m[6] = -f[1]; m[7] = 0.0f;
    m[8] = s[2];  m[9] = u[2];  m[10] = -f[2]; m[11] = 0.0f;
    m[12] = -(s[0]*ex + s[1]*ey + s[2]*ez);
    m[13] = -(u[0]*ex + u[1]*ey + u[2]*ez);
    m[14] = (f[0]*ex + f[1]*ey + f[2]*ez);
    m[15] = 1.0f;
}

void GrassRenderer::multiply(float* out, const float* a, const float* b) {
    float t[16];
    for(int i=0; i<4; i++) for(int j=0; j<4; j++)
        t[j*4+i] = a[0*4+i]*b[j*4+0] + a[1*4+i]*b[j*4+1] + a[2*4+i]*b[j*4+2] + a[3*4+i]*b[j*4+3];
    std::copy(t, t+16, out);
}
