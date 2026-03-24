#include "Renderer.h"
#include <android/log.h>

#define LOG_TAG "Renderer"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

void GrassRenderer::init() {
    // Note: In a production environment, you would use NativeAssetManager here
    // to load and compile the shaders. Assuming programs are compiled into computeProgram/renderProgram.

    // 1. Set up the Shader Storage Buffer Object (SSBO)
    glGenBuffers(1, &ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    // Allocate memory on the GPU for our grass blades (Position vec4 + Tilt vec4 = 8 floats per blade)
    glBufferData(GL_SHADER_STORAGE_BUFFER, GRASS_COUNT * 8 * sizeof(float), nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);

    // 2. Set up the Base Blade Geometry (A simple triangle pointing up)
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

void GrassRenderer::updateAndRender(float time, float deltaTime) {
    // Prevent rendering if programs aren't compiled yet to avoid crashing
    if (computeProgram == 0 || renderProgram == 0) return;

    // --- COMPUTE PASS (Logic) ---
    glUseProgram(computeProgram);
    
    // Pass time and wind uniforms
    glUniform1f(glGetUniformLocation(computeProgram, "u_Time"), time);
    glUniform2f(glGetUniformLocation(computeProgram, "u_WindDirection"), 1.0f, 0.5f);
    glUniform1f(glGetUniformLocation(computeProgram, "u_WindStrength"), 0.2f);
    glUniform3f(glGetUniformLocation(computeProgram, "u_ChunkOffset"), 0.0f, 0.0f, 0.0f);

    // Dispatch the compute shader in 16x16 work groups
    glDispatchCompute(256 / 16, 256 / 16, 1);
    
    // Ensure the compute shader finishes writing before we try to read/draw it
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // --- RENDER PASS (Visuals) ---
    glUseProgram(renderProgram);
    glBindVertexArray(vao);
    
    // Draw the base triangle geometry GRASS_COUNT times using the SSBO data
    glDrawArraysInstanced(GL_TRIANGLES, 0, 3, GRASS_COUNT);
}
