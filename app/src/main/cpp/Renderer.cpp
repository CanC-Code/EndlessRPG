#include "Renderer.h"
#include "AssetManager.h"
#include <android/log.h>
#include <cmath>
#include <vector>

#define LOG_TAG "Renderer"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// --- Shader Compilation Helpers ---

GLuint GrassRenderer::compileShader(GLenum type, const std::string& source) {
    GLuint shader = glCreateShader(type);
    const char* src = source.c_str();
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);
    
    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetShaderInfoLog(shader, 512, nullptr, infoLog);
        LOGE("Shader Compilation Error: %s", infoLog);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

GLuint GrassRenderer::createProgram(GLuint vertexShader, GLuint fragmentShader) {
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);
    return program;
}

GLuint GrassRenderer::createComputeProgram(GLuint computeShader) {
    GLuint program = glCreateProgram();
    glAttachShader(program, computeShader);
    glLinkProgram(program);
    return program;
}

// --- Matrix Math Helpers (No external libraries required) ---

void GrassRenderer::buildPerspectiveMatrix(float* m, float fov, float aspect, float zNear, float zFar) {
    float f = 1.0f / tan(fov / 2.0f);
    for(int i=0; i<16; i++) m[i] = 0.0f;
    m[0] = f / aspect;
    m[5] = f;
    m[10] = (zFar + zNear) / (zNear - zFar);
    m[11] = -1.0f;
    m[14] = (2.0f * zFar * zNear) / (zNear - zFar);
}

void GrassRenderer::buildLookAtMatrix(float* m, float ex, float ey, float ez, float cx, float cy, float cz) {
    // Forward vector
    float fx = cx - ex; float fy = cy - ey; float fz = cz - ez;
    float rlf = 1.0f / sqrt(fx*fx + fy*fy + fz*fz);
    fx *= rlf; fy *= rlf; fz *= rlf;
    
    // Up vector (0, 1, 0) crossed with Forward yields Right vector
    float sx = fy * 0.0f - fz * 1.0f;
    float sy = fz * 0.0f - fx * 0.0f;
    float sz = fx * 1.0f - fy * 0.0f;
    float rls = 1.0f / sqrt(sx*sx + sy*sy + sz*sz);
    sx *= rls; sy *= rls; sz *= rls;
    
    // Forward crossed with Right yields recalculated Up vector
    float ux = sy * fz - sz * fy;
    float uy = sz * fx - sx * fz;
    float uz = sx * fy - sy * fx;

    m[0] = sx; m[4] = ux; m[8]  = -fx; m[12] = 0.0f;
    m[1] = sy; m[5] = uy; m[9]  = -fy; m[13] = 0.0f;
    m[2] = sz; m[6] = uz; m[10] = -fz; m[14] = 0.0f;
    m[3] = 0.0f; m[7] = 0.0f; m[11] = 0.0f; m[15] = 1.0f;

    // Apply translation
    m[12] += m[0]*-ex + m[4]*-ey + m[8]*-ez;
    m[13] += m[1]*-ex + m[5]*-ey + m[9]*-ez;
    m[14] += m[2]*-ex + m[6]*-ey + m[10]*-ez;
}

void GrassRenderer::multiplyMatrix(float* out, const float* a, const float* b) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            out[i * 4 + j] = a[i * 4 + 0] * b[0 * 4 + j] +
                             a[i * 4 + 1] * b[1 * 4 + j] +
                             a[i * 4 + 2] * b[2 * 4 + j] +
                             a[i * 4 + 3] * b[3 * 4 + j];
        }
    }
}

// --- Lifecycle & Rendering ---

void GrassRenderer::init() {
    // 1. Load and compile shaders from APK assets
    std::string compSource = NativeAssetManager::loadShaderText("shaders/grass.comp");
    std::string vertSource = NativeAssetManager::loadShaderText("shaders/grass.vert");
    std::string fragSource = NativeAssetManager::loadShaderText("shaders/grass.frag");

    GLuint compShader = compileShader(GL_COMPUTE_SHADER, compSource);
    GLuint vertShader = compileShader(GL_VERTEX_SHADER, vertSource);
    GLuint fragShader = compileShader(GL_FRAGMENT_SHADER, fragSource);

    computeProgram = createComputeProgram(compShader);
    renderProgram = createProgram(vertShader, fragShader);

    // 2. Set up the SSBO for Compute Outputs
    glGenBuffers(1, &ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    glBufferData(GL_SHADER_STORAGE_BUFFER, GRASS_COUNT * 8 * sizeof(float), nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);

    // 3. Set up the Base Blade Geometry
    float bladeVertices[] = {
        -0.05f, 0.0f, 0.0f,
         0.05f, 0.0f, 0.0f,
         0.0f,  1.0f, 0.0f
    };
    
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(bladeVertices), bladeVertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

void GrassRenderer::updateAndRender(float time, float deltaTime, int screenWidth, int screenHeight) {
    if (computeProgram == 0 || renderProgram == 0 || screenWidth == 0 || screenHeight == 0) return;

    // Set Viewport and clear the black screen to a sky blue
    glViewport(0, 0, screenWidth, screenHeight);
    glClearColor(0.5f, 0.7f, 1.0f, 1.0f); 
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);

    // --- COMPUTE PASS (Calculate Grass Physics) ---
    glUseProgram(computeProgram);
    glUniform1f(glGetUniformLocation(computeProgram, "u_Time"), time);
    glUniform2f(glGetUniformLocation(computeProgram, "u_WindDirection"), 1.0f, 0.5f);
    glUniform1f(glGetUniformLocation(computeProgram, "u_WindStrength"), 0.5f);
    glUniform3f(glGetUniformLocation(computeProgram, "u_ChunkOffset"), 0.0f, 0.0f, 0.0f);
    
    glDispatchCompute(256 / 16, 256 / 16, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // --- RENDER PASS (Draw the Grass) ---
    glUseProgram(renderProgram);

    // Build the Camera Matrix viewing the center of our 256x256 grid
    float aspect = (float)screenWidth / (float)screenHeight;
    float proj[16], view[16], vp[16];
    
    // Position camera at x=128, height=30, z=-50 looking at the center x=128, y=0, z=128
    buildPerspectiveMatrix(proj, 1.047f, aspect, 0.1f, 1000.0f); // 60 degree FOV
    buildLookAtMatrix(view, 128.0f, 30.0f, -50.0f, 128.0f, 0.0f, 128.0f);
    multiplyMatrix(vp, proj, view);

    glUniformMatrix4fv(glGetUniformLocation(renderProgram, "u_ViewProjection"), 1, GL_FALSE, vp);

    glBindVertexArray(vao);
    glDrawArraysInstanced(GL_TRIANGLES, 0, 3, GRASS_COUNT);
}
