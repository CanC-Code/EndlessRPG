#include "Renderer.h"
#include "AssetManager.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>

#define LOG_TAG "GrassEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

GrassRenderer::GrassRenderer() : computeProgram(0), renderProgram(0), terrainProgram(0), 
                                 ssbo(0), vao(0), vbo(0), 
                                 terrainVao(0), terrainVbo(0), terrainEbo(0), terrainIndexCount(0) {}

// UPDATED: Handles the new Third Person and Zoom state from the UI
void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx; 
    moveY = my;
    isThirdPerson = tp; 
    cameraZoom = zoom;
    
    float sensitivity = 0.15f;
    camYaw += lx * sensitivity;
    camPitch -= ly * sensitivity;
    
    if(camPitch > 89.0f) camPitch = 89.0f;
    if(camPitch < -89.0f) camPitch = -89.0f;
}

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
    const float size = 60.0f;
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
    glGenBuffers(1, &terrainVbo);
    glGenBuffers(1, &terrainEbo);

    glBindVertexArray(terrainVao);
    glBindBuffer(GL_ARRAY_BUFFER, terrainVbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, terrainEbo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned short), indices.data(), GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    glBindVertexArray(0);
}

void GrassRenderer::init() {
    std::string cSrc = NativeAssetManager::loadShaderText("shaders/grass.comp");
    std::string vSrc = NativeAssetManager::loadShaderText("shaders/grass.vert");
    std::string fSrc = NativeAssetManager::loadShaderText("shaders/grass.frag");

    std::string tVSrc = NativeAssetManager::loadShaderText("shaders/terrain.vert");
    std::string tFSrc = NativeAssetManager::loadShaderText("shaders/terrain.frag");

    computeProgram = createComputeProgram(compileShader(GL_COMPUTE_SHADER, cSrc));
    renderProgram = createProgram(compileShader(GL_VERTEX_SHADER, vSrc), compileShader(GL_FRAGMENT_SHADER, fSrc));
    terrainProgram = createProgram(compileShader(GL_VERTEX_SHADER, tVSrc), compileShader(GL_FRAGMENT_SHADER, tFSrc));

    generateTerrainGrid();

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

    // --- UPDATED: FPS CAMERA & PLAYER MATH ---
    float yawRad = camYaw * (M_PI / 180.0f);
    float pitchRad = camPitch * (M_PI / 180.0f);

    float lookDirX = cosf(yawRad) * cosf(pitchRad);
    float lookDirY = sinf(pitchRad);
    float lookDirZ = sinf(yawRad) * cosf(pitchRad);
    
    float flatForwardX = cosf(yawRad);
    float flatForwardZ = sinf(yawRad);
    float flatRightX = cosf(yawRad - M_PI / 2.0f);
    float flatRightZ = sinf(yawRad - M_PI / 2.0f);

    float speed = 8.0f * dt;
    
    // 1. Move the PLAYER based on inputs
    playerX += (flatForwardX * moveY + flatRightX * moveX) * speed;
    playerZ += (flatForwardZ * moveY + flatRightZ * moveX) * speed;

    // 2. Snap the PLAYER to the terrain
    playerY = getElevation(playerX, playerZ);

    // 3. Position the CAMERA based on the view mode
    if (isThirdPerson) {
        // Orbit Math: Offset the camera backwards from the player along the look direction
        camX = playerX - (lookDirX * cameraZoom);
        camY = (playerY + 1.8f) - (lookDirY * cameraZoom);
        camZ = playerZ - (lookDirZ * cameraZoom);
        
        // Safety check: Prevent the camera from swinging through the dirt
        float groundUnderCam = getElevation(camX, camZ) + 0.5f;
        if (camY < groundUnderCam) camY = groundUnderCam;
    } else {
        camX = playerX;
        camY = playerY + 1.8f; // Eye level
        camZ = playerZ;
    }

    // --- COMPUTE PASS (Grass generation) ---
    glUseProgram(computeProgram);
    glUniform1f(glGetUniformLocation(computeProgram, "u_Time"), time);
    
    // Pass camX/Y/Z to the world generator so grass is generated around the current view
    glUniform3f(glGetUniformLocation(computeProgram, "u_CameraPos"), camX, camY, camZ);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
    glDispatchCompute(512 / 16, 512 / 16, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // Matrices
    float proj[16], view[16], vp[16];
    buildPerspective(proj, 0.8f, (float)width / (float)height, 0.1f, 1000.0f);
    buildLookAt(view, camX, camY, camZ, camX + lookDirX, camY + lookDirY, camZ + lookDirZ);
    multiply(vp, proj, view);

    // Render Pass 1: Terrain
    glUseProgram(terrainProgram);
    glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glUniform3f(glGetUniformLocation(terrainProgram, "u_CameraPos"), camX, camY, camZ);
    glBindVertexArray(terrainVao);
    glDrawElements(GL_TRIANGLES, terrainIndexCount, GL_UNSIGNED_SHORT, 0);

    // Render Pass 2: Grass
    glUseProgram(renderProgram);
    glUniformMatrix4fv(glGetUniformLocation(renderProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glBindVertexArray(vao);
    glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 7, GRASS_COUNT);
}

// Procedural CPU Math
float GrassRenderer::fract(float x) { return x - std::floor(x); }
float GrassRenderer::mix(float x, float y, float a) { return x * (1.0f - a) + y * a; }
float GrassRenderer::smoothstep(float edge0, float edge1, float x) {
    float t = std::clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
    return t * t * (3.0f - 2.0f * t);
}
float GrassRenderer::hash(float px, float py) {
    float p2x = fract(px * 5.3983f);
    float p2y = fract(py * 5.4427f);
    float d = p2y * (p2x + 21.5351f) + p2x * (p2y + 14.3137f);
    p2x += d; p2y += d;
    return fract(p2x * p2y * 95.4337f);
}
float GrassRenderer::noise(float px, float py) {
    float ix = std::floor(px); float iy = std::floor(py);
    float fx = fract(px); float fy = fract(py);
    float ux = fx * fx * (3.0f - 2.0f * fx);
    float uy = fy * fy * (3.0f - 2.0f * fy);
    return mix(mix(hash(ix + 0.0f, iy + 0.0f), hash(ix + 1.0f, iy + 0.0f), ux),
               mix(hash(ix + 0.0f, iy + 1.0f), hash(ix + 1.0f, iy + 1.0f), ux), uy);
}
float GrassRenderer::fbm(float px, float py) {
    float f = 0.0f; float amp = 0.5f;
    for(int i = 0; i < 3; i++) {
        f += amp * noise(px, py);
        px *= 2.0f; py *= 2.0f; amp *= 0.5f;
    }
    return f;
}
float GrassRenderer::getElevation(float px, float pz) {
    float base = fbm(px * 0.005f, pz * 0.005f);
    float mNoise = fbm(px * 0.015f + 100.0f, pz * 0.015f + 100.0f);
    float mountains = std::pow(mNoise, 2.5f) * 50.0f;
    float pNoise = fbm(px * 0.02f, pz * 0.02f);
    float plateaus = smoothstep(0.4f, 0.6f, pNoise) * 12.0f;
    float hills = fbm(px * 0.035f, pz * 0.035f) * 8.0f;
    float biomeMask = smoothstep(0.35f, 0.65f, base);
    float elevation = mix(plateaus + hills, mountains, biomeMask);
    elevation += fbm(px * 0.3f, pz * 0.3f) * 0.4f; 
    return elevation;
}

// Matrix Helpers
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
    m[0]=sx; m[4]=ux; m[8]=-fx; m[12]=-(m[0]*ex+m[4]*ey+m[8]*ez); 
    m[1]=sy; m[5]=uy; m[9]=-fy; m[13]=-(m[1]*ex+m[5]*ey+m[9]*ez);
    m[2]=sz; m[6]=uz; m[10]=-fz; m[14]=-(m[2]*ex+m[6]*ey+m[10]*ez); 
    m[3]=0.0f; m[7]=0.0f; m[11]=0.0f; m[15]=1.0f;
}
void GrassRenderer::multiply(float* out, const float* a, const float* b) {
    float temp[16];
    for (int i=0; i<4; i++) for (int j=0; j<4; j++)
        temp[j*4+i] = a[0*4+i]*b[j*4+0] + a[1*4+i]*b[j*4+1] + a[2*4+i]*b[j*4+2] + a[3*4+i]*b[j*4+3];
    for (int i=0; i<16; i++) out[i] = temp[i];
}
