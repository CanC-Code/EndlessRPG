// Inside Renderer.cpp

// 1. Advanced Terrain Math for Photorealism
float getTerrainHeight(float x, float z) {
    // Layer 1: Large Rolling Hills
    float h = sinf(x * 0.02f) * 6.0f + cosf(z * 0.02f) * 6.0f;
    // Layer 2: Medium Terrain Jaggies (Bumps)
    h += sinf(x * 0.1f + z * 0.05f) * 1.5f;
    // Layer 3: Small Soil Variations
    h += sinf(x * 0.5f) * cosf(z * 0.5f) * 0.2f;
    return h;
}

// 2. The Updated Update Loop
void GrassRenderer::updateAndRender(float time, float dt, int width, int height, AAssetManager* assetManager) {
    if (width <= 0 || height <= 0) return;
    gTime = time;

    if (terrainVAO == 0) { 
        generateTerrainGrid(); 
        setupShaders(assetManager); 
    }

    // Calculate height of ground at the character's NEXT possible position
    float currentGround = getTerrainHeight(playerCharacter.getX(), playerCharacter.getZ());

    // Update the Character Physics (This handles clipping and gravity)
    playerCharacter.update(dt, moveX, moveY, camYaw, currentGround);

    // Sync camera to character eyes
    cameraX = playerCharacter.getX();
    cameraZ = playerCharacter.getZ();
    cameraY = playerCharacter.getY() + 1.8f; // Eye level

    render(width, height);
}
