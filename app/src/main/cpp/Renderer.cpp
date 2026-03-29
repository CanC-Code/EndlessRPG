GrassRenderer::~GrassRenderer() {
    // REMOVED glDelete calls here! 
    // Android destroys the EGL context before the C++ object is destroyed on app exit.
    // Calling glDelete without a context causes an immediate SegFault crash.
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    // SAFEGUARD: Do not execute any OpenGL code if the surface isn't ready
    if (width <= 0 || height <= 0) return;

    // LAZY INITIALIZATION: Only run GL generation if the context is definitively alive
    if (terrainVAO == 0) {
        generateTerrainGrid();
        setupShaders();
    }

    // Update Physics / Camera Logic
    cameraX += (moveX * cos(camYaw) + moveY * sin(camYaw)) * dt * 10.0f;
    cameraZ += (-moveY * cos(camYaw) + moveX * sin(camYaw)) * dt * 10.0f; 

    render(width, height);
}
