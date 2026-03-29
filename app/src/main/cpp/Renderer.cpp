#include "Renderer.h"
#include <GLES3/gl31.h>
#include <cmath>
#include <android/log.h>
#include <vector>

#define LOG_TAG "ProceduralEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// ============================================================================
// MATRIX MATH HELPERS (No external libraries required!)
// ============================================================================
void loadIdentity(float* m) {
    for(int i=0; i<16; i++) m[i] = (i%5 == 0) ? 1.0f : 0.0f;
}

void perspective(float* m, float fovY, float aspect, float zNear, float zFar) {
    float f = 1.0f / tan(fovY / 2.0f);
    loadIdentity(m);
    m[0] = f / aspect;
    m[5] = f;
    m[10] = (zFar + zNear) / (zNear - zFar);
    m[11] = -1.0f;
    m[14] = (2.0f * zFar * zNear) / (zNear - zFar);
    m[15] = 0.0f;
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

// ============================================================================
// GLSL SHADER STRINGS
// ============================================================================
const char* terrainVS = R"(#version 310 es
layout(location = 0) in vec3 aPos;
uniform mat4 u_MVP;
out vec3 vWorldPos;
void main() {
    vWorldPos = aPos;
    gl_Position = u_MVP * vec4(aPos, 1.0);
}
)";

const char* terrainFS = R"(#version 310 es
precision mediump float;
in vec3 vWorldPos;
out vec4 FragColor;
void main() {
    // Generates a 1x1 meter checkerboard grid on the terrain
    float grid = mod(floor(vWorldPos.x) + floor(vWorldPos.z), 2.0);
    vec3 color1 = vec3(0.2, 0.5, 0.2); // Light Grass
    vec3 color2 = vec3(0.15, 0.4, 0.15); // Dark Grass
    FragColor = vec4(mix(color1, color2, grid), 1.0);
}
)";

// ============================================================================
// RENDERER IMPLEMENTATION
// ============================================================================
GrassRenderer::GrassRenderer() : terrainVAO(0), terrainVBO(0), terrainEBO(0), terrainProgram(0), grassProgram(0), grassComputeProgram(0), grassSSBO(0), indexCount(0) {
    // Initial Camera Setup
    cameraX = 0.0f;
    cameraY = 5.0f; // Start 5 meters above the ground!
    cameraZ = 0.0f;
    camYaw = 0.0f;
    camPitch = -0.3f; // Look slightly downwards
}

GrassRenderer::~GrassRenderer() {}

void GrassRenderer::init() {}

GLuint compileShader(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);
    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char log[512];
        glGetShaderInfoLog(shader, 512, nullptr, log);
        LOGE("Shader Compilation Failed: %s", log);
    }
    return shader;
}

void GrassRenderer::setupShaders() {
    // Compile Terrain Program
    GLuint vs = compileShader(GL_VERTEX_SHADER, terrainVS);
    GLuint fs = compileShader(GL_FRAGMENT_SHADER, terrainFS);
    terrainProgram = glCreateProgram();
    glAttachShader(terrainProgram, vs);
    glAttachShader(terrainProgram, fs);
    glLinkProgram(terrainProgram);
    glDeleteShader(vs);
    glDeleteShader(fs);
}

void GrassRenderer::generateTerrainGrid() {
    std::vector<float> vertices;
    std::vector<unsigned int> indices;
    int gridWidth = 150;
    int gridDepth = 150;

    for(int z = 0; z < gridDepth; z++) {
        for(int x = 0; x < gridWidth; x++) {
            vertices.push_back(x - gridWidth / 2.0f);
            vertices.push_back(0.0f); // Ground is at Y = 0
            vertices.push_back(z - gridDepth / 2.0f);
        }
    }

    for(int z = 0; z < gridDepth - 1; z++) {
        for(int x = 0; x < gridWidth - 1; x++) {
            int topLeft = (z * gridWidth) + x;
            int topRight = topLeft + 1;
            int bottomLeft = ((z + 1) * gridWidth) + x;
            int bottomRight = bottomLeft + 1;
            
            indices.push_back(topLeft);
            indices.push_back(bottomLeft);
            indices.push_back(topRight);
            indices.push_back(topRight);
            indices.push_back(bottomLeft);
            indices.push_back(bottomRight);
        }
    }
    indexCount = indices.size();

    glGenVertexArrays(1, &terrainVAO);
    glGenBuffers(1, &terrainVBO);
    glGenBuffers(1, &terrainEBO);

    glBindVertexArray(terrainVAO);
    glBindBuffer(GL_ARRAY_BUFFER, terrainVBO);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, terrainEBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned int), indices.data(), GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glBindVertexArray(0);
}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx; 
    moveY = my; 
    camYaw += lx * 0.005f; 
    camPitch += ly * 0.005f;
    
    if (camPitch > 1.5f) camPitch = 1.5f;
    if (camPitch < -1.5f) camPitch = -1.5f;
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    if (width <= 0 || height <= 0) return;

    if (terrainVAO == 0) {
        generateTerrainGrid();
        setupShaders();
    }

    // Move camera relative to the direction we are facing
    cameraX += (moveX * cos(camYaw) + moveY * sin(camYaw)) * dt * 10.0f;
    cameraZ += (-moveY * cos(camYaw) + moveX * sin(camYaw)) * dt * 10.0f; 

    render(width, height);
}

void GrassRenderer::render(int width, int height) {
    glViewport(0, 0, width, height);
    glClearColor(0.5f, 0.6f, 0.7f, 1.0f); 
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);

    // 1. Calculate Camera Forward Vector
    float camForwardX = sin(camYaw) * cos(camPitch);
    float camForwardY = -sin(camPitch);
    float camForwardZ = -cos(camYaw) * cos(camPitch);

    // 2. Build MVP (Model View Projection) Matrices
    float proj[16];
    perspective(proj, 60.0f * (M_PI / 180.0f), (float)width / (float)height, 0.1f, 1000.0f);

    float view[16];
    float targetX = cameraX + camForwardX;
    float targetY = cameraY + camForwardY;
    float targetZ = cameraZ + camForwardZ;
    lookAt(view, cameraX, cameraY, cameraZ, targetX, targetY, targetZ, 0.0f, 1.0f, 0.0f);

    float mvp[16];
    multiplyMatrix(mvp, proj, view); // Multiply Projection * View

    // 3. Draw Terrain Geometry
    if (terrainProgram != 0) {
        glUseProgram(terrainProgram);
        glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "u_MVP"), 1, GL_FALSE, mvp);
        
        glBindVertexArray(terrainVAO);
        glDrawElements(GL_TRIANGLES, indexCount, GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);
    }
}
