#include "Renderer.h"
#include <cmath>
#include <android/log.h>

#define LOG_TAG "ProceduralEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

GrassRenderer::GrassRenderer() : terrainVAO(0), terrainVBO(0), terrainEBO(0), terrainProgram(0), grassProgram(0), grassComputeProgram(0), grassSSBO(0), indexCount(0) {}

GrassRenderer::~GrassRenderer() {
    // Cleanup GL resources
    glDeleteVertexArrays(1, &terrainVAO);
    glDeleteBuffers(1, &terrainVBO);
    glDeleteBuffers(1, &terrainEBO);
}

void GrassRenderer::init() {
    generateTerrainGrid();
    // Assuming setupShaders() is implemented elsewhere in your file to compile the GLSL
    // setupShaders(); 
}

void GrassRenderer::generateTerrainGrid() {
    std::vector<float> vertices;
    std::vector<unsigned int> indices;
    int gridWidth = 150;
    int gridDepth = 150;

    // Build the grid using exactly 3 floats (X, Y, Z) per vertex
    for(int z = 0; z < gridDepth; z++) {
        for(int x = 0; x < gridWidth; x++) {
            vertices.push_back(x - gridWidth / 2.0f);
            vertices.push_back(0.0f); // Y is calculated in the vertex shader
            vertices.push_back(z - gridDepth / 2.0f);
        }
    }

    // Generate indices
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

    // Stride is 3 * sizeof(float)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    
    glBindVertexArray(0);
}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx; 
    moveY = my; 
    camYaw += lx * 0.005f; 
    camPitch += ly * 0.005f;
    
    // Clamp pitch to prevent the camera from flipping upside down
    if (camPitch > 1.5f) camPitch = 1.5f;
    if (camPitch < -1.5f) camPitch = -1.5f;
    
    isThirdPerson = tp;
    cameraZoom = zoom;
}

void GrassRenderer::render(int width, int height) {
    // Basic render loop placeholder
}

// NEW: Implementation to satisfy RenderLoop.cpp and pass time to shaders
void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    // Here we can eventually pass 'time' to the shader for wind animation!
    // u_Time = time;
    
    render(width, height);
}
