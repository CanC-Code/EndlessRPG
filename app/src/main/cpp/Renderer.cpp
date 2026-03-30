#include "Renderer.h"
#include <GLES3/gl31.h>
#include <cmath>
#include <android/log.h>
#include <vector>
#include <cstdlib>

#define LOG_TAG "ProceduralEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static float gTime = 0.0f;
static GLuint emptyVAO = 0;

// The World Math (Shared between CPU height and GPU shaders)
float getTerrainHeight(float x, float z) {
    float h = sin(x * 0.04f) * 4.0f;
    h += cos(z * 0.03f) * 3.0f;
    h += sin((x + z) * 0.1f) * 1.5f;
    return h;
}

// --- Matrix Math Helpers ---
void loadIdentity(float* m) { for(int i=0; i<16; i++) m[i] = (i%5 == 0) ? 1.0f : 0.0f; }
void perspective(float* m, float fovY, float aspect, float zNear, float zFar) {
    float f = 1.0f / tan(fovY / 2.0f);
    loadIdentity(m);
    m[0] = f / aspect; m[5] = f;
    m[10] = (zFar + zNear) / (zNear - zFar); m[11] = -1.0f;
    m[14] = (2.0f * zFar * zNear) / (zNear - zFar); m[15] = 0.0f;
}
void lookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz, float ux, float uy, float uz) {
    float f[3] = {cx - ex, cy - ey, cz - ez};
    float magF = sqrt(f[0]*f[0] + f[1]*f[1] + f[2]*f[2]);
    f[0]/=magF; f[1]/=magF; f[2]/=magF;
    float s[3] = { f[1]*uz - f[2]*uy, f[2]*ux - f[0]*uz, f[0]*uy - f[1]*ux };
    float magS = sqrt(s[0]*s[0] + s[1]*s[1] + s[2]*s[2]);
    s[0]/=magS; s[1]/=magS; s[2]/=magS;
    float u_prime[3] = { s[1]*f[2] - s[2]*f[1], s[2]*f[0] - s[0]*f[2], s[0]*f[1] - s[1]*f[0] };
    loadIdentity(m);
    m[0] = s[0];       m[4] = s[1];       m[8] = s[2];
    m[1] = u_prime[0]; m[5] = u_prime[1]; m[9] = u_prime[2];
    m[2] = -f[0];      m[6] = -f[1];      m[10] = -f[2];
    m[12] = -(s[0]*ex + s[1]*ey + s[2]*ez);
    m[13] = -(u_prime[0]*ex + u_prime[1]*ey + u_prime[2]*ez);
    m[14] = f[0]*ex + f[1]*ey + f[2]*ez;
}
void multiplyMatrix(float* out, const float* a, const float* b) {
    for(int c=0; c<4; c++) {
        for(int r=0; r<4; r++) {
            out[c*4+r] = a[0*4+r]*b[c*4+0] + a[1*4+r]*b[c*4+1] + a[2*4+r]*b[c*4+2] + a[3*4+r]*b[c*4+3];
        }
    }
}

// Implementation of our new Asset Loader
char* GrassRenderer::loadShaderFile(AAssetManager* assetManager, const char* filename) {
    AAsset* asset = AAssetManager_open(assetManager, filename, AASSET_MODE_BUFFER);
    if (!asset) {
        LOGE("Failed to open shader file: %s", filename);
        return nullptr;
    }
    off_t length = AAsset_getLength(asset);
    char* buffer = (char*)malloc(length + 1);
    AAsset_read(asset, buffer, length);
    buffer[length] = '\0';
    AAsset_close(asset);
    return buffer;
}

GLuint compileShaderFromSource(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);
    
    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        char log[512];
        glGetShaderInfoLog(shader, 512, nullptr, log);
        LOGE("Shader Error: %s", log);
    }
    return shader;
}

GrassRenderer::GrassRenderer() : terrainVAO(0), terrainVBO(0), terrainEBO(0), terrainProgram(0), grassProgram(0), grassComputeProgram(0), grassSSBO(0), indexCount(0) {
    cameraX = 0.0f; cameraZ = 0.0f; cameraY = 1.8f; camYaw = 0.0f; camPitch = 0.0f; 
}

GrassRenderer::~GrassRenderer() {}

void GrassRenderer::setupShaders(AAssetManager* assetManager) {
    // 1. Load Terrain
    char* vsSrc = loadShaderFile(assetManager, "terrain.vert");
    char* fsSrc = loadShaderFile(assetManager, "terrain.frag");
    if (vsSrc && fsSrc) {
        GLuint vs = compileShaderFromSource(GL_VERTEX_SHADER, vsSrc);
        GLuint fs = compileShaderFromSource(GL_FRAGMENT_SHADER, fsSrc);
        terrainProgram = glCreateProgram();
        glAttachShader(terrainProgram, vs); glAttachShader(terrainProgram, fs);
        glLinkProgram(terrainProgram);
        free(vsSrc); free(fsSrc);
    }

    // 2. Load Grass Compute
    char* csSrc = loadShaderFile(assetManager, "grass.comp");
    if (csSrc) {
        GLuint cs = compileShaderFromSource(GL_COMPUTE_SHADER, csSrc);
        grassComputeProgram = glCreateProgram();
        glAttachShader(grassComputeProgram, cs);
        glLinkProgram(grassComputeProgram);
        free(csSrc);
    }

    // 3. Load Grass Rendering
    char* gvsSrc = loadShaderFile(assetManager, "grass.vert");
    char* gfsSrc = loadShaderFile(assetManager, "grass.frag");
    if (gvsSrc && gfsSrc) {
        GLuint vs = compileShaderFromSource(GL_VERTEX_SHADER, gvsSrc);
        GLuint fs = compileShaderFromSource(GL_FRAGMENT_SHADER, gfsSrc);
        grassProgram = glCreateProgram();
        glAttachShader(grassProgram, vs); glAttachShader(grassProgram, fs);
        glLinkProgram(grassProgram);
        free(gvsSrc); free(gfsSrc);
    }

    // Buffers setup
    glGenBuffers(1, &grassSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, grassSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, 65536 * 32, nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, grassSSBO);
    glGenVertexArrays(1, &emptyVAO);
}

void GrassRenderer::generateTerrainGrid() {
    std::vector<float> vertices;
    std::vector<unsigned int> indices;
    int res = 160; float size = 320.0f;
    for(int z = 0; z < res; z++) {
        for(int x = 0; x < res; x++) {
            vertices.push_back((x / (float)res) * size - size*0.5f);
            vertices.push_back(0.0f); vertices.push_back((z / (float)res) * size - size*0.5f);
        }
    }
    for(int z = 0; z < res - 1; z++) {
        for(int x = 0; x < res - 1; x++) {
            int tl = (z * res) + x; int bl = ((z + 1) * res) + x;
            indices.insert(indices.end(), { (unsigned int)tl, (unsigned int)bl, (unsigned int)tl+1, (unsigned int)tl+1, (unsigned int)bl, (unsigned int)bl+1 });
        }
    }
    indexCount = indices.size();
    glGenVertexArrays(1, &terrainVAO); glGenBuffers(1, &terrainVBO); glGenBuffers(1, &terrainEBO);
    glBindVertexArray(terrainVAO);
    glBindBuffer(GL_ARRAY_BUFFER, terrainVBO); glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, terrainEBO); glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned int), indices.data(), GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx; moveY = my; 
    camYaw += lx * 0.004f; camPitch += ly * 0.004f;
    if (camPitch > 1.2f) camPitch = 1.2f; if (camPitch < -1.2f) camPitch = -1.2f;
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height, AAssetManager* assetManager) {
    if (width <= 0 || height <= 0) return;
    gTime = time;
    if (terrainVAO == 0) { 
        generateTerrainGrid(); 
        setupShaders(assetManager); 
    }
    cameraX += (moveX * cos(camYaw) + moveY * sin(camYaw)) * dt * 9.0f;
    cameraZ += (-moveY * cos(camYaw) + moveX * sin(camYaw)) * dt * 9.0f; 
    cameraY = getTerrainHeight(cameraX, cameraZ) + 1.75f;
    render(width, height);
}

void GrassRenderer::render(int width, int height) {
    glViewport(0, 0, width, height);
    glClearColor(0.55f, 0.7f, 0.85f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    float proj[16], view[16], mvp[16];
    perspective(proj, 60.0f * (M_PI / 180.0f), (float)width / (float)height, 0.1f, 1000.0f);
    lookAt(view, cameraX, cameraY, cameraZ, cameraX + sin(camYaw)*cos(camPitch), cameraY - sin(camPitch), cameraZ - cos(camYaw)*cos(camPitch), 0.0f, 1.0f, 0.0f);
    multiplyMatrix(mvp, proj, view);

    if (grassComputeProgram) {
        glUseProgram(grassComputeProgram);
        glUniform3f(glGetUniformLocation(grassComputeProgram, "u_CameraPos"), cameraX, cameraY, cameraZ);
        glUniform1f(glGetUniformLocation(grassComputeProgram, "u_Time"), gTime);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, grassSSBO);
        glDispatchCompute(256, 1, 1);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
    }

    if (terrainProgram) {
        glUseProgram(terrainProgram);
        glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "u_MVP"), 1, GL_FALSE, mvp);
        glUniform3f(glGetUniformLocation(terrainProgram, "u_CameraPos"), cameraX, cameraY, cameraZ);
        glBindVertexArray(terrainVAO);
        glDrawElements(GL_TRIANGLES, indexCount, GL_UNSIGNED_INT, 0);
    }

    if (grassProgram) {
        glUseProgram(grassProgram);
        glUniformMatrix4fv(glGetUniformLocation(grassProgram, "u_MVP"), 1, GL_FALSE, mvp);
        glUniform3f(glGetUniformLocation(grassProgram, "u_CameraPos"), cameraX, cameraY, cameraZ);
        glBindVertexArray(emptyVAO);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, grassSSBO);
        glDrawArraysInstanced(GL_TRIANGLES, 0, 6, 65536);
    }
}
