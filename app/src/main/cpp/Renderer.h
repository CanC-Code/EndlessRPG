#ifndef RENDERER_H
#define RENDERER_H

#include <GLES3/gl31.h>
#include <android/asset_manager.h>
#include "Character.h" // ADDED: Required for playerCharacter member

class GrassRenderer {
public:
    GrassRenderer();
    ~GrassRenderer();

    void updateAndRender(float time, float dt, int width, int height, AAssetManager* assetManager);
    void updateInput(float mx, float my, float lx, float ly, bool tp, float zoom);

private:
    void render(int width, int height);
    void setupShaders(AAssetManager* assetManager);
    void generateTerrainGrid();
    char* loadShaderFile(AAssetManager* assetManager, const char* filename);

    // Physics Engine Object
    Character playerCharacter; // ADDED: The physical body of the player

    // OpenGL State
    GLuint terrainVAO, terrainVBO, terrainEBO;
    GLuint terrainProgram, grassProgram, grassComputeProgram;
    GLuint grassSSBO;
    int indexCount;

    // Camera Variables
    float cameraX, cameraY, cameraZ;
    float camYaw, camPitch;
    float moveX, moveY;
};

#endif
