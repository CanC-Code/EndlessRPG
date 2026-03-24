#include "Renderer.h"
#include <android/log.h>

void GrassRenderer::init() {
    glGenBuffers(1, &ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    glBufferData(GL_SHADER_STORAGE_BUFFER, GRASS_COUNT * 8 * sizeof(float), nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);

    float bladeVertices[] = { -0.05f, 0.0f, 0.0f, 0.05f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f };
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(bladeVertices), bladeVertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

void GrassRenderer::updateAndRender(float time, float deltaTime) {
    if (computeProgram == 0 || renderProgram == 0) return;
    glUseProgram(computeProgram);
    glDispatchCompute(256 / 16, 256 / 16, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
    glUseProgram(renderProgram);
    glBindVertexArray(vao);
    glDrawArraysInstanced(GL_TRIANGLES, 0, 3, GRASS_COUNT);
}
