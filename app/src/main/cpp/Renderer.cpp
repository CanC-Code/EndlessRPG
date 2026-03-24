void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    glViewport(0, 0, width, height);
    // Background color (Golden Hour Haze)
    glClearColor(0.2f, 0.25f, 0.35f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if (computeProgram == 0 || renderProgram == 0 || terrainProgram == 0) return;

    glEnable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    // --- 1. PHYSICS & INPUT MATH ---
    float yawRad = camYaw * (M_PI / 180.0f);
    float pitchRad = camPitch * (M_PI / 180.0f);

    float lookX = cosf(yawRad) * cosf(pitchRad);
    float lookY = sinf(pitchRad);
    float lookZ = sinf(yawRad) * cosf(pitchRad);
    
    float forwardX = cosf(yawRad), forwardZ = sinf(yawRad);
    float rightX = cosf(yawRad - M_PI / 2.0f), rightZ = sinf(yawRad - M_PI / 2.0f);

    float speed = 8.0f * dt;
    playerX += (forwardX * moveY + rightX * moveX) * speed;
    playerZ += (forwardZ * moveY + rightZ * moveX) * speed; // FIXED: Used rightZ
    playerY = getElevation(playerX, playerZ);

    // --- 2. CAMERA ORBIT & INTERPOLATION ---
    float targetCamX, targetCamY, targetCamZ;
    if (isThirdPerson) {
        targetCamX = playerX - (lookX * cameraZoom);
        targetCamY = (playerY + 2.0f) - (lookY * cameraZoom); 
        targetCamZ = playerZ - (lookZ * cameraZoom);
        
        float floor = getElevation(targetCamX, targetCamZ) + 0.8f;
        if (targetCamY < floor) targetCamY = floor;
    } else {
        targetCamX = playerX; targetCamY = playerY + 1.8f; targetCamZ = playerZ;
    }

    // Smooth camera lag
    float lerpSpeed = 12.0f * dt;
    camX += (targetCamX - camX) * lerpSpeed;
    camY += (targetCamY - camY) * lerpSpeed;
    camZ += (targetCamZ - camZ) * lerpSpeed;

    // --- 3. COMPUTE & MATRICES ---
    glUseProgram(computeProgram);
    glUniform1f(glGetUniformLocation(computeProgram, "u_Time"), time);
    glUniform3f(glGetUniformLocation(computeProgram, "u_CameraPos"), camX, camY, camZ);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
    glDispatchCompute(512 / 16, 512 / 16, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    float proj[16], view[16], vp[16];
    buildPerspective(proj, 0.8f, (float)width / (float)height, 0.1f, 1000.0f);
    
    // --- FIXED: CRITICAL LOOK-AT LOGIC ---
    if (isThirdPerson) {
        // Look at the player
        buildLookAt(view, camX, camY, camZ, playerX, playerY + 1.8f, playerZ);
    } else {
        // Look forward (prevents division by zero)
        buildLookAt(view, camX, camY, camZ, camX + lookX, camY + lookY, camZ + lookZ);
    }
    multiply(vp, proj, view);

    // --- 4. DRAWING ---
    // Ground
    glUseProgram(terrainProgram);
    glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glUniform3f(glGetUniformLocation(terrainProgram, "u_CameraPos"), camX, camY, camZ);
    glBindVertexArray(terrainVao);
    glDrawElements(GL_TRIANGLES, terrainIndexCount, GL_UNSIGNED_SHORT, 0);

    // Grass
    glUseProgram(renderProgram);
    glUniformMatrix4fv(glGetUniformLocation(renderProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glBindVertexArray(vao);
    glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 7, GRASS_COUNT);

    // Character (3rd Person only)
    if (isThirdPerson) {
        playerModel.render(vp, playerX, playerY, playerZ, camYaw);
    }
}
