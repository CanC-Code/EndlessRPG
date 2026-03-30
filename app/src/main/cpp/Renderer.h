#ifndef RENDERER_H
#define RENDERER_H

#include <GLES3/gl31.h>
#include <android/asset_manager.h>

class GrassRenderer {
public:
    GrassRenderer();
    ~GrassRenderer();

    void init();
    
    // Updated: Now accepts the AssetManager to facilitate loading external shader files
    void updateAndRender(float time, float dt, int width, int height, AAssetManager* assetManager);
    
    void updateInput(float mx, float my, float lx, float ly, bool tp, float zoom);

private:
    void render(int width, int height);
    
    // Updated: setupShaders now requires the AssetManager to pull files from the assets folder
    void setupShaders(AAssetManager* assetManager);
    
    void generateTerrainGrid();
    
    // NEW: Helper function to read shader source code from the Android assets directory
    char* loadShaderFile(AAssetManager* assetManager, const char* filename);

    // OpenGL Handles
    GLuint terrainVAO, terrainVBO, terrainEBO;
    GLuint terrainProgram, grassProgram, grassComputeProgram;
    GLuint grassSSBO;
    int indexCount;

    // Camera and Movement State
    float cameraX, cameraY, cameraZ;
    float camYaw, camPitch;
    float moveX, moveY;
};

#endif
