#ifndef RENDERER_H
#define RENDERER_H

#include <GLES3/gl31.h>
#include <android/asset_manager.h>
#include "Character.h" // Ensures the Renderer knows what a 'Character' is

class GrassRenderer {
public:
    GrassRenderer();
    ~GrassRenderer();

    // Updated to accept the AssetManager for loading files from /assets/shaders
    void updateAndRender(float time, float dt, int width, int height, AAssetManager* assetManager);
    
    void updateInput(float mx, float my, float lx, float ly, bool tp, float zoom);

private:
    void render(int width, int height);
    void setupShaders(AAssetManager* assetManager);
    void generateTerrainGrid();
    
    // Helper to read shader source from the Android assets
    char* loadShaderFile(AAssetManager* assetManager, const char* filename);

    // ========================================================================
    // THE FIX: This declaration allows the Renderer to track the player
    // consistently across every frame. Without this, playerCharacter 
    // is an "undeclared identifier" and the build fails.
    // ========================================================================
    Character playerCharacter; 

    // OpenGL State Handles
    GLuint terrainVAO, terrainVBO, terrainEBO;
    GLuint terrainProgram, grassProgram, grassComputeProgram;
    GLuint grassSSBO;
    int indexCount;

    // Camera/View State
    float cameraX, cameraY, cameraZ;
    float camYaw, camPitch;
    float moveX, moveY;
};

#endif
