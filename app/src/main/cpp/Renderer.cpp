void GrassRenderer::init() {
    computeProgram = createComputeProgram(compileShader(GL_COMPUTE_SHADER, NativeAssetManager::loadShaderText("shaders/grass.comp")));
    renderProgram = createProgram(compileShader(GL_VERTEX_SHADER, NativeAssetManager::loadShaderText("shaders/grass.vert")), 
                                  compileShader(GL_FRAGMENT_SHADER, NativeAssetManager::loadShaderText("shaders/grass.frag")));
    terrainProgram = createProgram(compileShader(GL_VERTEX_SHADER, NativeAssetManager::loadShaderText("shaders/terrain.vert")), 
                                   compileShader(GL_FRAGMENT_SHADER, NativeAssetManager::loadShaderText("shaders/terrain.frag")));

    playerModel.init();
    generateTerrainGrid();

    glGenBuffers(1, &ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    glBufferData(GL_SHADER_STORAGE_BUFFER, GRASS_COUNT * 8 * sizeof(float), nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);

    // FIXED: Perfect 8-Vertex Rectangular Strip. 
    // This stops the SDF from collapsing into a glitchy triangle at the top.
    float blade[] = { 
        -0.05f, 0.00f, 0.0f,   0.05f, 0.00f, 0.0f, 
        -0.05f, 0.46f, 0.0f,   0.05f, 0.46f, 0.0f, 
        -0.05f, 0.93f, 0.0f,   0.05f, 0.93f, 0.0f, 
        -0.05f, 1.40f, 0.0f,   0.05f, 1.40f, 0.0f 
    };
    
    glGenVertexArrays(1, &vao); glGenBuffers(1, &vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(blade), blade, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

// ... inside updateAndRender() ...
// Make sure to update the draw call from 7 to 8 vertices!
glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 8, GRASS_COUNT); 
