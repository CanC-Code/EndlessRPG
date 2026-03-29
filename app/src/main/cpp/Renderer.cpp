void GrassRenderer::generateTerrainGrid() {
    std::vector<float> vertices;
    std::vector<unsigned int> indices;

    int gridWidth = 150;
    int gridDepth = 150;

    // CRITICAL FIX: Push 3 floats per vertex (X, Y, Z) so the layout(location = 0) in vec3 works perfectly.
    for(int z = 0; z < gridDepth; z++) {
        for(int x = 0; x < gridWidth; x++) {
            vertices.push_back(x - gridWidth / 2.0f);
            vertices.push_back(0.0f); // Default Y, elevated in shader
            vertices.push_back(z - gridDepth / 2.0f);
        }
    }

    // Generate indices for drawing triangles
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

    // Ensure your vertex array buffer setup maps size=3, stride=3*sizeof(float)
    // Example: glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) { 
    // mx and my come in normalized between -1.0 and +1.0 from Kotlin
    moveX = mx; 
    moveY = my; // Acts as Forward/Backward on Z axis
    
    // Dampen look speeds to prevent violent camera snapping
    camYaw += lx * 0.005f; 
    camPitch += ly * 0.005f;

    // Prevent gimbal lock
    if (camPitch > 1.5f) camPitch = 1.5f;
    if (camPitch < -1.5f) camPitch = -1.5f; 

    isThirdPerson = tp; 
    cameraZoom = zoom;
}
