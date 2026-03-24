#include "Renderer.h"
#include "AssetManager.h"
#include <android/log.h>
#include <cmath>

#define LOG_TAG "Renderer"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

GrassRenderer::GrassRenderer() : computeProgram(0), renderProgram(0), ssbo(0), vao(0), vbo(0) {}

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
    
    GLint success;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetProgramInfoLog(program, 512, nullptr, infoLog);
        LOGE("Render Program Link Error: %s", infoLog);
        glDeleteProgram(program);
        return 0;
    }
    return program;
}

GLuint GrassRenderer::createComputeProgram(GLuint computeShader) {
    GLuint program = glCreateProgram();
    glAttachShader(program, computeShader);
    glLinkProgram(program);
    
    GLint success;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetProgramInfoLog(program, 512, nullptr, infoLog);
        LOGE("Compute Program Link Error: %s", infoLog);
        glDeleteProgram(program);
        return 0;
    }
    return program;
}

void GrassRenderer::buildPerspective(float* m, float fov, float aspect, float zNear, float zFar) {
    float f = 1.0f / tanf(fov / 2.0f);
    for(int i=0; i<16; i++) m[i] = 0.0f;
    m[0] = f / aspect; m[5] = f;
    m[10] = (zFar + zNear) / (zNear - zFar); m[11] = -1.0f;
    m[14] = (2.0f * zFar * zNear) / (zNear - zFar);
}

void GrassRenderer::buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz) {
    float fx = cx - ex; float fy = cy - ey; float fz = cz - ez;
    float rlf = 1.0f / sqrtf(fx*fx + fy*fy + fz*fz);
    fx *= rlf; fy *= rlf; fz *= rlf;
    
    float sx = fy * 0.0f - fz * 1.0f; float sy = fz * 0.0f - fx * 0.0f; float sz = fx * 1.0f - fy * 0.0f;
    float rls = 1.0f / sqrtf(sx*sx + sy*sy + sz*sz);
    sx *= rls; sy *= rls; sz *= rls;
    
    float ux = sy * fz - sz * fy; float uy = sz * fx - sx * fz; float uz = sx * fy - sy * fx;
    
    m[0] = sx; m[4] = ux; m[8]  = -fx; m[12] = 0.0f;
    m[1] = sy; m[5] = uy; m[9]  = -fy; m[13] = 0.0f;
    m[2] = sz; m[6] = uz; m[10] = -fz; m[14] = 0.0f;
    m[3] = 0.0f; m[7] = 0.0f; m[11] = 0.0f; m[15] = 1.0f;

    m[12] += m[0]*-ex + m[4]*-ey + m[8]*-ez;
    m[13] += m[1]*-ex + m[5]*-ey + m[9]*-ez;
    m[14] += m[2]*-ex + m[6]*-ey + m[10]*-ez;
}

void GrassRenderer::multiply(float* out, const float* a, const float* b) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            out[j * 4 + i] = a[0 * 4 + i] * b[j * 4 + 0] + a[1 * 4 + i] * b[j * 4 + 1] + 
                             a[2 * 4 + i] * b[j * 4 + 2] + a[3 * 4 + i] * b[j * 4 + 3];
        }
    }
}

void GrassRenderer::init() {
    std::string compSource = NativeAssetManager::loadShaderText("shaders/grass.comp");
    std::string vertSource = NativeAssetManager::loadShaderText("shaders/grass.vert");
    std::string fragSource = NativeAssetManager::loadShaderText("shaders/grass.frag");

    GLuint compShader = compileShader(GL_COMPUTE_SHADER, compSource);
    GLuint vertShader = compileShader(GL_VERTEX_SHADER, vertSource);
    GLuint fragShader = compileShader(GL_FRAGMENT_SHADER, fragSource);

    computeProgram = createComputeProgram(compShader);
    renderProgram = createProgram(vertShader, fragShader);

    glGenBuffers(1, &ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    // 8 floats per blade (vec4 pos, vec4 wind)
    glBufferData(GL_SHADER_STORAGE_BUFFER, GRASS_COUNT * 8 * sizeof(float), nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
    
    // 7 vertices for a smooth, curved grass blade
    float bladeVertices[] = {
        -0.03f, 0.0f, 0.0f,
         0.03f, 0.0f, 0.0f,
        -0.02f, 0.4f, 0.0f,
         0.02f, 0.4f, 0.0f,
        -0.01f, 0.7f, 0.0f,
         0.01f, 0.7f, 0.0f,
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
    if (computeProgram == 0 || renderProgram == 0 || screenWidth <= 0 || screenHeight <= 0) return;
    
    glViewport(0, 0, screenWidth, screenHeight);
    
    // Background color roughly matches the sky in the photo
    glClearColor(0.65f, 0.80f, 0.95f, 1.0f); 
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glEnable(GL_DEPTH_TEST);
    // Disable face culling so we see both sides of the blade
    glDisable(GL_CULL_FACE); 
    
    // --- COMPUTE PASS ---
    glUseProgram(computeProgram);
    glUniform1f(glGetUniformLocation(computeProgram, "u_Time"), time);
    
    // Dispatch enough work groups to cover 512x512 grid
    glDispatchCompute(512 / 16, 512 / 16, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
    
    // --- RENDER PASS ---
    glUseProgram(renderProgram);

    float aspect = (float)screenWidth / (float)screenHeight;
    float proj[16], view[16], vp[16];
    
    buildPerspective(proj, 0.785f, aspect, 0.1f, 100.0f);
    // Camera placed low to the ground (-8.0 on Z axis), looking slightly down at the origin
    buildLookAt(view, 0.0f, 1.5f, -8.0f, 0.0f, 0.5f, 0.0f);
    multiply(vp, proj, view);

    glUniformMatrix4fv(glGetUniformLocation(renderProgram, "u_ViewProjection"), 1, GL_FALSE, vp);

    glBindVertexArray(vao);
    // Draw 7 vertices per instance using GL_TRIANGLE_STRIP
    glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 7, GRASS_COUNT);
}
