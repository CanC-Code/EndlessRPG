#include "Renderer.h"
#include <cmath>
#include <android/log.h>

#define LOG_TAG "ProceduralEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

GrassRenderer::GrassRenderer() : terrainVAO(0), terrainVBO(0), terrainEBO(0), terrainProgram(0), grassProgram(0), grassComputeProgram(0), grassSSBO(0), indexCount(0) {}

GrassRenderer::~GrassRenderer() {
    // Safely Cleanup GL resources
    if (terrainVAO != 0) glDeleteVertexArrays(1, &terrainVAO);
    if (terrainVBO != 0) glDeleteBuffers(1, &terrainVBO);
    if (terrainEBO != 0) glDeleteBuffers(1, &terrainEBO);
    if (grassSSBO != 0) glDeleteBuffers(1, &grassSSBO);
}

void GrassRenderer::init() {
    // We intentionally leave this empty! 
    // Android calls JNI initialization BEFORE the EGL context exists.
    // If we call glGenBuffers here, the app will instantly crash.
    // We moved generation to lazy-loading in updateAndRender().
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
            vertices.push_back(0.0f); // Y is calculated in the vertex shader dynamically
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

    // Stride is exactly 3 * sizeof(float)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    
    glBindVertexArray(0);
}

void GrassRenderer::setupShaders() {
    // Generate the SSBO for the Compute Shader
    glGenBuffers(1, &grassSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, grassSSBO);
    
    // Allocate space for 256x256 blades (65536). 
    // Each blade needs 2 vec4s (pos + dir) = 8 floats = 32 bytes per blade.
    // Total size = 2,097,152 bytes.
    glBufferData(GL_SHADER_STORAGE_BUFFER, 65536 * 32, nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, grassSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

    // *Note: In your actual engine, ensure your AssetManager loads and compiles 
    // the terrainProgram, grassComputeProgram, and grassProgram here!
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

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    // LAZY INITIALIZATION: Only run GL generation if the context is definitively alive
    if (terrainVAO == 0) {
        generateTerrainGrid();
        setupShaders();
    }

    // Update Physics / Camera Logic
    cameraX += (moveX * cos(camYaw) + moveY * sin(camYaw)) * dt * 10.0f;
    cameraZ += (-moveY * cos(camYaw) + moveX * sin(camYaw)) * dt * 10.0f; 

    // Calculate Forward Vector for Frustum Culling
    float camForwardX = sin(camYaw) * cos(camPitch);
    float camForwardY = -sin(camPitch);
    float camForwardZ = -cos(camYaw) * cos(camPitch);

    render(width, height);
}

void GrassRenderer::render(int width, int height) {
    glViewport(0, 0, width, height);
    glClearColor(0.5f, 0.6f, 0.7f, 1.0f); // Sky color
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);

    // 1. Dispatch Compute Shader for Grass Generation
    if (grassComputeProgram != 0) {
        glUseProgram(grassComputeProgram);
        
        // Push uniforms to Compute Shader
        glUniform3f(glGetUniformLocation(grassComputeProgram, "u_CameraPos"), cameraX, cameraY, cameraZ);
        
        // Push the forward vector we calculated for Frustum Culling!
        glUniform3f(glGetUniformLocation(grassComputeProgram, "u_CamForward"), 
                    sin(camYaw) * cos(camPitch), -sin(camPitch), -cos(camYaw) * cos(camPitch));
        
        // 256x256 grid dispatched
        glDispatchCompute(256, 1, 1);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT); // Wait for compute to finish
    }

    // 2. Render High-Resolution Terrain
    if (terrainProgram != 0) {
        glUseProgram(terrainProgram);
        glUniform3f(glGetUniformLocation(terrainProgram, "u_CameraPos"), cameraX, cameraY, cameraZ);
        
        // Assuming your standard MVP matrix passes are handled here
        
        glBindVertexArray(terrainVAO);
        glDrawElements(GL_TRIANGLES, indexCount, GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);
    }
    
    // 3. Render Photo-Realistic Grass
    if (grassProgram != 0) {
        glUseProgram(grassProgram);
        glUniform3f(glGetUniformLocation(grassProgram, "u_CameraPos"), cameraX, cameraY, cameraZ);
        
        // Assuming standard MVP passes are handled here
        
        // Since we are using an SSBO, you would use glDrawArraysInstanced
        // Example: glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 15, 65536);
    }
}
