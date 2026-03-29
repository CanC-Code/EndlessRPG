#include "Renderer.h"
#include "AssetManager.h"
#include <cmath>
#include <android/log.h>

#define LOG_TAG "ProceduralEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

GrassRenderer::GrassRenderer() : terrainVAO(0), terrainVBO(0), terrainEBO(0), grassSSBO(0) {}

void GrassRenderer::generateTerrainGrid() {
    std::vector<float> vertices;
    std::vector<unsigned int> indices;
    int gridWidth = 150, gridDepth = 150;

    [span_0](start_span)[span_1](start_span)// Fixed: Using 3 floats (X, Y, Z) per vertex to match shader vec3 expectation[span_0](end_span)[span_1](end_span)
    for(int z = 0; z < gridDepth; z++) {
        for(int x = 0; x < gridWidth; x++) {
            vertices.push_back(x - gridWidth / 2.0f);
            vertices.push_back(0.0f); 
            vertices.push_back(z - gridDepth / 2.0f);
        }
    }

    for(int z = 0; z < gridDepth - 1; z++) {
        for(int x = 0; x < gridWidth - 1; x++) {
            int topLeft = (z * gridWidth) + x;
            int topRight = topLeft + 1;
            int bottomLeft = ((z + 1) * gridWidth) + x;
            int bottomRight = bottomLeft + 1;
            indices.push_back(topLeft); indices.push_back(bottomLeft); indices.push_back(topRight);
            indices.push_back(topRight); indices.push_back(bottomLeft); indices.push_back(bottomRight);
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

    // Stride is 3 * sizeof(float)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx; 
    moveY = my; [span_2](start_span)// Normalized from Kotlin[span_2](end_span)
    camYaw += lx * 0.005f; 
    camPitch += ly * 0.005f;
    if (camPitch > 1.5f) camPitch = 1.5f;
    if (camPitch < -1.5f) camPitch = -1.5f;
    isThirdPerson = tp;
    cameraZoom = zoom;
}
