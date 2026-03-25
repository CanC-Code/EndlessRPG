#include "Renderer.h"
#include "AssetManager.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>

#define LOG_TAG "GrassEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Constructor: Initializes all OpenGL handles to 0
GrassRenderer::GrassRenderer() : computeProgram(0), renderProgram(0), terrainProgram(0), 
                                 ssbo(0), vao(0), vbo(0), 
                                 terrainVao(0), terrainVbo(0), terrainEbo(0), terrainIndexCount(0) {}

// UPDATED: Receives all input data from the Kotlin UI
void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx; 
    moveY = my;
    isThirdPerson = tp; 
    cameraZoom = zoom;
    
    float sensitivity = 0.15f;
    camYaw += lx * sensitivity;
    camPitch -= ly * sensitivity;
    
    // Clamp pitch to prevent the camera from flipping or causing gimbal lock
    if(camPitch > 85.0f) camPitch = 85.0f;
    if(camPitch < -85.0f) camPitch = -85.0f;
}

// Shader helper functions
GLuint GrassRenderer::compileShader(GLenum type, const std::string& source) {
    if (source.empty()) return 0;
    GLuint shader = glCreateShader(type);
    const char* src = source.c_str();
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);
    GLint success; glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) { glDeleteShader(shader); return 0; }
    return shader;
}

GLuint GrassRenderer::createProgram(GLuint vShader, GLuint fShader) {
    if (!vShader || !fShader) return 0;
    GLuint program = glCreateProgram();
    glAttachShader(program, vShader); glAttachShader(program, fShader);
    glLinkProgram(program);
    GLint success; glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) return 0;
    return program;
}

GLuint GrassRenderer::createComputeProgram(GLuint cShader) {
    if (!cShader) return 0;
    GLuint program = glCreateProgram();
    glAttachShader(program, cShader); glLinkProgram(program);
    GLint success; glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) return 0;
    return program;
}

void GrassRenderer::generateTerrainGrid() {
    const int gridSize = 128;
    const float size = 100.0f; // Increased size to cover more horizon
    std::vector<float> vertices;
    std::vector<unsigned short> indices;

    for(int z = 0; z <= gridSize; ++z) {
        for(int x = 0; x <= gridSize; ++x) {
            float px = -size/2.0f + (float)x / gridSize * size;
            float pz = -size/2.0f + (float)z / gridSize * size;
            vertices.push_back(px);
            vertices.push_back(pz);
        }
    }

    for(int z = 0; z < gridSize; ++z) {
        for(int x = 0; x < gridSize; ++x) {
            int topLeft = z * (gridSize + 1) + x;
            int topRight = topLeft + 1;
            int bottomLeft = (z + 1) * (gridSize + 1) + x;
            int bottomRight = bottomLeft + 1;
            indices.push_back(topLeft); indices.push_back(bottomLeft); indices.push_back(topRight);
            indices.push_back(topRight); indices.push_back(bottomLeft); indices.push_back(bottomRight);
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
    // 1. Load and Compile Shaders
    std::string cSrc = NativeAssetManager::loadShaderText("shaders/grass.comp");
    std::string vSrc = NativeAssetManager::loadShaderText("shaders/grass.vert");
    std::string fSrc = NativeAssetManager::loadShaderText("shaders/grass.frag");
    std::string tVSrc = NativeAssetManager::loadShaderText("shaders/terrain.vert");
    std::string tFSrc = NativeAssetManager::loadShaderText("shaders/terrain.frag");

    computeProgram = createComputeProgram(compileShader(GL_COMPUTE_SHADER, cSrc));
    renderProgram = createProgram(compileShader(GL_VERTEX_SHADER, vSrc), compileShader(GL_FRAGMENT_SHADER, fSrc));
    terrainProgram = createProgram(compileShader(GL_VERTEX_SHADER, tVSrc), compileShader(GL_FRAGMENT_SHADER, tFSrc));

    // 2. Initialize Player Model Geometry
    playerModel.init();

    // 3. Setup Terrain Grid
    generateTerrainGrid();

    // 4. Setup Grass SSBO
    glGenBuffers(1, &ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    glBufferData(GL_SHADER_STORAGE_BUFFER, GRASS_COUNT * 8 * sizeof(float), nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);

    float bladeVertices[] = {
        -0.03f, 0.0f, 0.0f,  0.03f, 0.0f, 0.0f, 
        -0.02f, 0.4f, 0.0f,  0.02f, 0.4f, 0.0f, 
        -0.01f, 0.8f, 0.0f,  0.01f, 0.8f, 0.0f, 
         0.0f,  1.1f, 0.0f 
    };

    glGenVertexArrays(1, &vao); glGenBuffers(1, &vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(bladeVertices), bladeVertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    glViewport(0, 0, width, height);
    glClearColor(0.2f, 0.25f, 0.35f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if (computeProgram == 0 || renderProgram == 0 || terrainProgram == 0) return;

    glEnable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    // --- 1. MOVEMENT & COLLISION MATH ---
    float yawRad = camYaw * (M_PI / 180.0f);
    float pitchRad = camPitch * (M_PI / 180.0f);

    float lookX = cosf(yawRad) * cosf(pitchRad);
    float lookY = sinf(pitchRad);
    float lookZ = sinf(yawRad) * cosf(pitchRad);
    
    float forwardX = cosf(yawRad), forwardZ = sinf(yawRad);
    float rightX = cosf(yawRad - M_PI / 2.0f), rightZ = sinf(yawRad - M_PI / 2.0f);

    float speed = 8.0f * dt;
    playerX += (forwardX * moveY + rightX * moveX) * speed;
    playerZ += (forwardZ * moveY + rightZ * moveX) * speed; 
    playerY = getElevation(playerX, playerZ);

    // --- 2. CAMERA ORBIT & LERP (Smooth Follow) ---
    float targetCamX, targetCamY, targetCamZ;
    if (isThirdPerson) {
        targetCamX = playerX - (lookX * cameraZoom);
        targetCamY = (playerY + 2.0f) - (lookY * cameraZoom); 
        targetCamZ = playerZ - (lookZ * cameraZoom);
        
        // Ground Collision: Keep camera above hills
        float floor = getElevation(targetCamX, targetCamZ) + 0.8f;
        if (targetCamY < floor) targetCamY = floor;
    } else {
        targetCamX = playerX; targetCamY = playerY + 1.8f; targetCamZ = playerZ;
    }

    // Apply LERP for "heavy" cinematic camera feel
    float lerpSpeed = 12.0f * dt;
    camX += (targetCamX - camX) * lerpSpeed;
    camY += (targetCamY - camY) * lerpSpeed;
    camZ += (targetCamZ - camZ) * lerpSpeed;

    // --- 3. COMPUTE PASS (Grass Displacement) ---
    glUseProgram(computeProgram);
    glUniform1f(glGetUniformLocation(computeProgram, "u_Time"), time);
    glUniform3f(glGetUniformLocation(computeProgram, "u_CameraPos"), camX, camY, camZ);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
    glDispatchCompute(512 / 16, 512 / 16, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // --- 4. RENDER PASSES ---
    float proj[16], view[16], vp[16];
    buildPerspective(proj, 0.8f, (float)width / (float)height, 0.1f, 1000.0f);
    
    // CRITICAL FIX: Ensure target is never exactly equal to camera pos
    if (isThirdPerson) {
        buildLookAt(view, camX, camY, camZ, playerX, playerY + 1.8f, playerZ);
    } else {
        buildLookAt(view, camX, camY, camZ, camX + lookX, camY + lookY, camZ + lookZ);
    }
    multiply(vp, proj, view);

    // Draw Terrain
    glUseProgram(terrainProgram);
    glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glUniform3f(glGetUniformLocation(terrainProgram, "u_CameraPos"), camX, camY, camZ);
    glBindVertexArray(terrainVao);
    glDrawElements(GL_TRIANGLES, terrainIndexCount, GL_UNSIGNED_SHORT, 0);

    // Draw Grass
    glUseProgram(renderProgram);
    glUniformMatrix4fv(glGetUniformLocation(renderProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glBindVertexArray(vao);
    glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 7, GRASS_COUNT);

    // Draw Character Model
    if (isThirdPerson) {
        playerModel.render(vp, playerX, playerY, playerZ, camYaw);
    }
}

// Procedural Math (Must match the GPU precisely)
float GrassRenderer::fract(float x) { return x - std::floor(x); }
float GrassRenderer::mix(float x, float y, float a) { return x * (1.0f - a) + y * a; }
float GrassRenderer::smoothstep(float edge0, float edge1, float x) {
    float t = std::clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
    return t * t * (3.0f - 2.0f * t);
}
float GrassRenderer::hash(float px, float py) {
    float p2x = fract(px * 5.3983f), p2y = fract(py * 5.4427f);
    float d = p2y * (p2x + 21.5351f) + p2x * (p2y + 14.3137f);
    return fract((p2x + d) * (p2y + d) * 95.4337f);
}
float GrassRenderer::noise(float px, float py) {
    float ix = std::floor(px), iy = std::floor(py);
    float fx = fract(px), fy = fract(py);
    float ux = fx * fx * (3.0f - 2.0f * fx), uy = fy * fy * (3.0f - 2.0f * fy);
    return mix(mix(hash(ix, iy), hash(ix + 1.0f, iy), ux), mix(hash(ix, iy + 1.0f), hash(ix + 1.0f, iy + 1.0f), ux), uy);
}
float GrassRenderer::fbm(float px, float py) {
    float f = 0.0f, amp = 0.5f;
    for(int i = 0; i < 3; i++) { f += amp * noise(px, py); px *= 2.0f; py *= 2.0f; amp *= 0.5f; }
    return f;
}
float GrassRenderer::getElevation(float px, float pz) {
    float base = fbm(px * 0.005f, pz * 0.005f);
    float mountains = std::pow(fbm(px * 0.015f + 100.0f, pz * 0.015f + 100.0f), 2.5f) * 50.0f;
    float plateaus = smoothstep(0.4f, 0.6f, fbm(px * 0.02f, pz * 0.02f)) * 12.0f;
    float hills = fbm(px * 0.035f, pz * 0.035f) * 8.0f;
    float biomeMask = smoothstep(0.35f, 0.65f, base);
    return mix(plateaus + hills, mountains, biomeMask) + fbm(px * 0.3f, pz * 0.3f) * 0.4f;
}

// Linear Algebra Helpers
void GrassRenderer::buildPerspective(float* m, float fov, float aspect, float zn, float zf) {
    float f = 1.0f / tanf(fov / 2.0f);
    for(int i=0; i<16; i++) m[i] = 0.0f;
    m[0]=f/aspect; m[5]=f; m[10]=(zf+zn)/(zn-zf); m[11]=-1.0f; m[14]=(2.0f*zf*zn)/(zn-zf);
}
void GrassRenderer::buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz) {
    float fx=cx-ex, fy=cy-ey, fz=cz-ez;
    float rlf=1.0f/sqrtf(fx*fx+fy*fy+fz*fz); fx*=rlf; fy*=rlf; fz*=rlf;
    float sx=fy*0.0f-fz*1.0f, sy=fz*0.0f-fx*0.0f, sz=fx*1.0f-fy*0.0f;
    float rls=1.0f/sqrtf(sx*sx+sy*sy+sz*sz); sx*=rls; sy*=rls; sz*=rls;
    float ux=sy*fz-sz*fy, uy=sz*fx-sx*fz, uz=sx*fy-sy*fx;
    m[0]=sx; m[1]=sy; m[2]=sz; m[3]=0.0f; m[4]=ux; m[5]=uy; m[6]=uz; m[7]=0.0f;
    m[8]=-fx; m[9]=-fy; m[10]=-fz; m[11]=0.0f; m[12]=-(sx*ex+sy*ey+sz*ez); m[13]=-(ux*ex+uy*ey+uz*ez); m[14]=(fx*ex+fy*ey+fz*ez); m[15]=1.0f;
}
void GrassRenderer::multiply(float* out, const float* a, const float* b) {
    float tmp[16];
    for(int i=0; i<4; i++) for(int j=0; j<4; j++)
        tmp[j*4+i] = a[0*4+i]*b[j*4+0] + a[1*4+i]*b[j*4+1] + a[2*4+i]*b[j*4+2] + a[3*4+i]*b[j*4+3];
    for(int i=0; i<16; i++) out[i] = tmp[i];
}
