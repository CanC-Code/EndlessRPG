#include "Renderer.h"
#include "AssetManager.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>
#include <vector>
#include <chrono>
#include <thread>
#include <random>

#define LOG_TAG "GrassEngine"

const float EARTH_RADIUS = 6371000.0f;
const float EARTH_CIRCUMFERENCE = 2.0f * M_PI * EARTH_RADIUS;
const float TERRAIN_SIZE = 400.0f;
const int TERRAIN_GRID = 200;
const float GRID_SPACING = TERRAIN_SIZE / (float)TERRAIN_GRID; // Exactly 2.0f

GrassRenderer::GrassRenderer() : computeProgram(0), renderProgram(0), terrainProgram(0), 
                                 ssbo(0), vao(0), vbo(0), instanceVbo(0),
                                 terrainVao(0), terrainVbo(0), terrainEbo(0), terrainIndexCount(0),
                                 playerX(0.0f), playerY(0.0f), playerZ(0.0f), playerYaw(0.0f),
                                 camX(0.0f), camY(1.8f), camZ(0.0f),
                                 camYaw(-90.0f), camPitch(0.0f),
                                 moveX(0.0f), moveY(0.0f),
                                 isThirdPerson(false), cameraZoom(12.0f) {
    // Initialize smoothing and physics variables
    smoothPitch = 0.0f;
    smoothRoll = 0.0f;
    velocityX = 0.0f;
    velocityZ = 0.0f;
}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    if (std::isnan(mx) || std::isnan(my) || std::isnan(lx) || std::isnan(ly)) return;

    // Circular Deadzone to prevent joystick drift
    float mag = sqrtf(mx*mx + my*my);
    if (mag > 0.1f) {
        moveX = std::clamp(mx, -1.0f, 1.0f); 
        moveY = std::clamp(my, -1.0f, 1.0f);
    } else {
        moveX = 0.0f; moveY = 0.0f;
    }

    isThirdPerson = tp; 
    cameraZoom = std::clamp(zoom, 2.0f, 40.0f);

    // Non-linear camera sensitivity
    float sensitivity = 0.25f + (std::abs(lx) * 0.1f); 
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
        float sx = cosf(lat) * cosf(lon), sy = sinf(lat), sz = cosf(lat) * sinf(lon);

        float noiseScale = 2000.0f; 
        float h = noise3(sx * noiseScale * 0.01f, sy * noiseScale * 0.01f, sz * noiseScale * 0.01f) * 35.0f;
        h += noise3(sx * noiseScale * 0.04f, sy * noiseScale * 0.04f, sz * noiseScale * 0.04f) * 12.0f;
        h += noise3(sx * noiseScale * 0.1f, sy * noiseScale * 0.1f, sz * noiseScale * 0.1f) * 3.0f;
        return h;
    };

    // Grid alignment matches the Terrain Mesh triangles perfectly
    float cellX = floorf(x / GRID_SPACING) * GRID_SPACING;
    float cellZ = floorf(z / GRID_SPACING) * GRID_SPACING;
    float tx = (x - cellX) / GRID_SPACING;
    float tz = (z - cellZ) / GRID_SPACING;

    float h00 = exactElevation(cellX, cellZ);
    float h10 = exactElevation(cellX + GRID_SPACING, cellZ);
    float h01 = exactElevation(cellX, cellZ + GRID_SPACING);
    float h11 = exactElevation(cellX + GRID_SPACING, cellZ + GRID_SPACING);

    if (tx + tz <= 1.0f) return h00 + (h10 - h00) * tx + (h01 - h00) * tz;
    else return h11 + (h01 - h11) * (1.0f - tx) + (h10 - h11) * (1.0f - tz);
}

void GrassRenderer::generateTerrainGrid() {
    std::vector<float> vertices;
    std::vector<unsigned short> indices;

    for(int z = 0; z <= TERRAIN_GRID; ++z) {
        for(int x = 0; x <= TERRAIN_GRID; ++x) {
            vertices.push_back(-TERRAIN_SIZE/2.0f + (float)x/TERRAIN_GRID * TERRAIN_SIZE);
            vertices.push_back(-TERRAIN_SIZE/2.0f + (float)z/TERRAIN_GRID * TERRAIN_SIZE);
        }
    }

    for(int z = 0; z < TERRAIN_GRID; ++z) {
        for(int x = 0; x < TERRAIN_GRID; ++x) {
            int row1 = z * (TERRAIN_GRID + 1);
            int row2 = (z + 1) * (TERRAIN_GRID + 1);
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
    // Note: computeProgram initialization removed to match optimized pipeline logic
    renderProgram = createProgram(compileShader(GL_VERTEX_SHADER, NativeAssetManager::loadShaderText("shaders/grass.vert")), 
                                  compileShader(GL_FRAGMENT_SHADER, NativeAssetManager::loadShaderText("shaders/grass.frag")));
    terrainProgram = createProgram(compileShader(GL_VERTEX_SHADER, NativeAssetManager::loadShaderText("shaders/terrain.vert")), 
                                   compileShader(GL_FRAGMENT_SHADER, NativeAssetManager::loadShaderText("shaders/terrain.frag")));

    playerModel.init();
    generateTerrainGrid();

    // Photographic Grass Tapering (8 vertices for smooth bending)
    float blade[] = { 
        -0.05f, 0.00f, 0.0f,   0.05f, 0.00f, 0.0f, 
        -0.04f, 0.46f, 0.0f,   0.04f, 0.46f, 0.0f, 
        -0.02f, 0.93f, 0.0f,   0.02f, 0.93f, 0.0f, 
        -0.00f, 1.40f, 0.0f,   0.00f, 1.40f, 0.0f 
    };

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(blade), blade, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    // Seed grass EXACTLY on terrain heights
    std::random_device rd; // <-- Fixed: Changed from mt1random_device
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(-TERRAIN_SIZE/2.0f, TERRAIN_SIZE/2.0f);
    std::uniform_real_distribution<float> hashDis(0.0f, 1.0f);

    for (int i = 0; i < GRASS_COUNT; ++i) {
        float x = dis(gen);
        float z = dis(gen);
        float y = getElevation(x, z);
        float hash = hashDis(gen);

        instanceData.push_back(x);
        instanceData.push_back(y);
        instanceData.push_back(z);
        instanceData.push_back(hash);
    }

    glGenBuffers(1, &instanceVbo);
    glBindBuffer(GL_ARRAY_BUFFER, instanceVbo);
    glBufferData(GL_ARRAY_BUFFER, instanceData.size() * sizeof(float), instanceData.data(), GL_STATIC_DRAW);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribDivisor(1, 1); 
    glBindVertexArray(0);
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    float dtSafe = std::min(dt, 0.033f); // Max 30fps delta for physics stability

    glViewport(0, 0, width, height);
    glClearColor(0.5f, 0.65f, 0.8f, 1.0f); // Atmospheric Sky Color
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if (!renderProgram || !terrainProgram) return;
    glEnable(GL_DEPTH_TEST);

    float yawRad = camYaw * (M_PI / 180.0f);
    float pitchRad = camPitch * (M_PI / 180.0f);
    float lookX = cosf(yawRad) * cosf(pitchRad);
    float lookY = sinf(pitchRad);
    float lookZ = sinf(yawRad) * cosf(pitchRad);

    float fwdX = cosf(yawRad), fwdZ = sinf(yawRad);
    float rgtX = cosf(yawRad + M_PI / 2.0f), rgtZ = sinf(yawRad + M_PI / 2.0f);

    // KINEMATICS: Inertia and Momentum
    float targetSpeedX = (fwdX * moveY + rgtX * moveX) * 10.0f;
    float targetSpeedZ = (fwdZ * moveY + rgtZ * moveX) * 10.0f;

    // Smooth damp velocity for realistic human acceleration
    velocityX += (targetSpeedX - velocityX) * 8.0f * dtSafe;
    velocityZ += (targetSpeedZ - velocityZ) * 8.0f * dtSafe;

    playerX += velocityX * dtSafe;
    playerZ += velocityZ * dtSafe;

    // Exact elevation locking
    float targetY = getElevation(playerX, playerZ);
    playerY += (targetY - playerY) * 15.0f * dtSafe; 

    // FINITE DIFFERENCE TERRAIN NORMAL
    float eps = GRID_SPACING * 0.5f;
    float hL = getElevation(playerX - eps, playerZ);
    float hR = getElevation(playerX + eps, playerZ);
    float hD = getElevation(playerX, playerZ - eps);
    float hU = getElevation(playerX, playerZ + eps);

    float normX = hL - hR;
    float normY = 2.0f * eps;
    float normZ = hD - hU;
    float normLen = sqrtf(normX*normX + normY*normY + normZ*normZ);
    normX /= normLen; normY /= normLen; normZ /= normLen;

    // SHORTEST-PATH YAW ROTATION
    if (std::abs(velocityX) > 0.1f || std::abs(velocityZ) > 0.1f) {
        float targetYaw = camYaw + atan2f(moveX, -moveY) * (180.0f / M_PI);
        float diff = fmodf(targetYaw - playerYaw + 540.0f, 360.0f) - 180.0f;
        playerYaw += diff * 12.0f * dtSafe; 
        playerYaw = fmodf(playerYaw + 360.0f, 360.0f);
    }

    // SMOOTH BIOMECHANICAL ALIGNMENT
    float pYawRad = playerYaw * (M_PI / 180.0f);
    float terrainPitchTarget = -asin(normX * cosf(pYawRad + M_PI/2.0f) + normZ * sinf(pYawRad + M_PI/2.0f));
    float terrainRollTarget = -asin(normX * cosf(pYawRad) + normZ * sinf(pYawRad));

    smoothPitch += (terrainPitchTarget - smoothPitch) * 8.0f * dtSafe;
    smoothRoll += (terrainRollTarget - smoothRoll) * 8.0f * dtSafe;

    // CINEMATIC CAMERA COLLISION & SPRING
    float tX, tY, tZ;
    if (isThirdPerson) {
        tX = playerX - (lookX * cameraZoom);
        tZ = playerZ - (lookZ * cameraZoom);
        tY = (playerY + 1.8f) - (lookY * cameraZoom);

        // Prevent camera from clipping through hills
        float camFloor = getElevation(tX, tZ) + 0.8f;
        if (tY < camFloor) {
            tY = camFloor;
        }
    } else {
        tX = playerX; tY = playerY + 1.8f; tZ = playerZ;
    }

    // Frame-independent exponential smoothing
    float blend = 1.0f - expf(-12.0f * dtSafe);
    camX += (tX - camX) * blend;
    camY += (tY - camY) * blend;
    camZ += (tZ - camZ) * blend;

    float proj[16], view[16], vp[16];
    buildPerspective(proj, 0.8f, (float)width / (float)height, 0.1f, 1500.0f);
    if (isThirdPerson) buildLookAt(view, camX, camY, camZ, playerX, playerY + 1.5f, playerZ);
    else buildLookAt(view, camX, camY, camZ, camX + lookX, camY + lookY, camZ + lookZ);
    multiply(vp, proj, view);

    // Render Terrain
    glUseProgram(terrainProgram);
    glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glUniform3f(glGetUniformLocation(terrainProgram, "u_CameraPos"), camX, camY, camZ);
    glBindVertexArray(terrainVao);
    glDrawElements(GL_TRIANGLES, terrainIndexCount, GL_UNSIGNED_SHORT, 0);

    // Render Procedural Grass Foliage
    glDisable(GL_CULL_FACE); // Two-sided grass
    glUseProgram(renderProgram);
    glUniformMatrix4fv(glGetUniformLocation(renderProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glUniform3f(glGetUniformLocation(renderProgram, "u_CameraPos"), camX, camY, camZ);
    glUniform3f(glGetUniformLocation(renderProgram, "u_PlayerPos"), playerX, playerY, playerZ);
    glUniform1f(glGetUniformLocation(renderProgram, "u_Time"), time);
    glBindVertexArray(vao);
    glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 8, GRASS_COUNT);
    glEnable(GL_CULL_FACE);

    // Render Biomechanical Character 
    if (isThirdPerson) {
        playerModel.render(vp, playerX, playerY, playerZ, playerYaw, smoothPitch, smoothRoll, camX, camZ);
    }
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
