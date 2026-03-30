#ifndef RENDERER_H
#define RENDERER_H

#include <GLES3/gl31.h>
#include <android/asset_manager.h>
#include "Character.h" // CRITICAL: Header must be included to use Character class

class GrassRenderer {
public:
    GrassRenderer();
    ~GrassRenderer();

    // Updated to accept AssetManager for loading external shader files
    void updateAndRender(float time, float dt, int width, int height, AAssetManager* assetManager);
    
    void updateInput(float mx, float my, float lx, float ly, bool tp, float zoom);

private:
    void render(int width, int height);
    void setupShaders(AAssetManager* assetManager);
    void generateTerrainGrid();
    
    // Helper to read GLSL code from the assets/shaders folder
    char* loadShaderFile(AAssetManager* assetManager, const char* filename);

    // ========================================================================
    // THE FIX: The Renderer now officially owns the Character physics body.
    // This allows the engine to track the player's world position and height.
    // ========================================================================
    Character playerCharacter; 

    // OpenGL Handle State
    GLuint terrainVAO, terrainVBO, terrainEBO;
    GLuint terrainProgram, grassProgram, grassComputeProgram;
    GLuint grassSSBO;
    int indexCount;

    // Camera and Viewing State
    float cameraX, cameraY, cameraZ;
    float camYaw, camPitch;
    float moveX, moveY;
};

#endif
