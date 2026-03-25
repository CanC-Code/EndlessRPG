#include "Renderer.h"
#include "AssetManager.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>

#define LOG_TAG "GrassEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define PI 3.1415926535f

GrassRenderer::GrassRenderer() : computeProgram(0), renderProgram(0), terrainProgram(0), 
                                 ssbo(0), vao(0), vbo(0), 
                                 terrainVao(0), terrainVbo(0), terrainEbo(0), terrainIndexCount(0) {}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx; 
    moveY = my;
    isThirdPerson = tp; 
    cameraZoom = std::clamp(zoom, 2.0f, 40.0f);
    
    float sensitivity = 0.15f;
    camYaw += lx * sensitivity;
    camPitch -= ly * sensitivity;
    
    // Clamp pitch to 89 degrees to prevent Matrix NaN (Gimbal Lock)
    camPitch = std::clamp(camPitch, -89.0f, 89.0f);
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    // 1. STABILIZE DELTA TIME
    // Prevents "Teleportation bugs" if the frame rate drops momentarily
    float dtSafe = std::min(dt, 0.05f); 

    glViewport(0, 0, width, height);
    glClearColor(0.45f, 0.55f, 0.75f, 1.0f); // Brighter sky blue
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if (computeProgram == 0 || renderProgram == 0 || terrainProgram == 0) return;

    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);

    // 2. PHYSICS & ORIENTATION
    float yawRad = camYaw * (PI / 180.0f);
    float pitchRad = camPitch * (PI / 180.0f);

    // Spherical to Cartesian for Look Vector
    float lookX = cosf(yawRad) * cosf(pitchRad);
    float lookY = sinf(pitchRad);
    float lookZ = sinf(yawRad) * cosf(pitchRad);
    
    float forwardX = cosf(yawRad), forwardZ = sinf(yawRad);
    float rightX = cosf(yawRad - PI / 2.0f), rightZ = sinf(yawRad - PI / 2.0f);

    // Update Player (The actual physical entity)
    float speed = 10.0f * dtSafe;
    playerX += (forwardX * moveY + rightX * moveX) * speed;
    playerZ += (forwardZ * moveY + rightZ * moveX) * speed; 
    playerY = getElevation(playerX, playerZ);

    // 3. CAMERA ORBIT LOGIC
    float targetCamX, targetCamY, targetCamZ;
    if (isThirdPerson) {
        targetCamX = playerX - (lookX * cameraZoom);
        targetCamY = (playerY + 2.5f) - (lookY * cameraZoom); 
        targetCamZ = playerZ - (lookZ * cameraZoom);
        
        // Safety: Prevent camera from being buried in mountains
        float ground = getElevation(targetCamX, targetCamZ) + 1.2f;
        if (targetCamY < ground) targetCamY = ground;
    } else {
        targetCamX = playerX; 
        targetCamY = playerY + 1.8f; 
        targetCamZ = playerZ;
    }

    // Camera Smoothing (LERP)
    float lerpVal = 12.0f * dtSafe;
    camX += (targetCamX - camX) * lerpVal;
    camY += (targetCamY - camY) * lerpVal;
    camZ += (targetCamZ - camZ) * lerpVal;

    // 4. PREPARE MATRICES
    float proj[16], view[16], vp[16];
    buildPerspective(proj, 0.8f, (float)width / (float)height, 0.1f, 1000.0f);
    
    if (isThirdPerson) {
        buildLookAt(view, camX, camY, camZ, playerX, playerY + 1.5f, playerZ);
    } else {
        buildLookAt(view, camX, camY, camZ, camX + lookX, camY + lookY, camZ + lookZ);
    }
    multiply(vp, proj, view);

    // 5. COMPUTE PASS (Grass)
    glUseProgram(computeProgram);
    glUniform1f(glGetUniformLocation(computeProgram, "u_Time"), time);
    glUniform3f(glGetUniformLocation(computeProgram, "u_CameraPos"), camX, camY, camZ);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
    glDispatchCompute(512 / 16, 512 / 16, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // 6. RENDER PASSES
    // Terrain
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

    // Character
    if (isThirdPerson) {
        playerModel.render(vp, playerX, playerY, playerZ, camYaw);
    }
}

// --- BOILERPLATE & MATH HELPERS ---

void GrassRenderer::buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz) {
    float fx=cx-ex, fy=cy-ey, fz=cz-ez;
    float rlf=1.0f/sqrtf(fx*fx+fy*fy+fz*fz + 0.00001f); // Added epsilon to prevent div by zero
    fx*=rlf; fy*=rlf; fz*=rlf;
    
    // Right Vector
    float sx=fy*0.0f-fz*1.0f, sy=fz*0.0f-fx*0.0f, sz=fx*1.0f-fy*0.0f;
    float rls=1.0f/sqrtf(sx*sx+sy*sy+sz*sz + 0.00001f);
    sx*=rls; sy*=rls; sz*=rls;
    
    // Up Vector
    float ux=sy*fz-sz*fy, uy=sz*fx-sx*fz, uz=sx*fy-sy*fx;
    
    m[0]=sx; m[1]=sy; m[2]=sz; m[3]=0.0f;
    m[4]=ux; m[5]=uy; m[6]=uz; m[7]=0.0f;
    m[8]=-fx; m[9]=-fy; m[10]=-fz; m[11]=0.0f;
    m[12]=-(sx*ex+sy*ey+sz*ez); m[13]=-(ux*ex+uy*ey+uz*ez); m[14]=(fx*ex+fy*ey+fz*ez); m[15]=1.0f;
}

// Ensure fract and noise match GLSL standard exactly
float GrassRenderer::fract(float x) { return x - std::floor(x); }
float GrassRenderer::hash(float px, float py) {
    float x = fract(px * 0.1031f);
    float y = fract(py * 0.1030f);
    float z = fract(px * 0.0973f);
    x += dot(vec2(x, y), vec2(y, z) + 33.33f);
    return fract((x + y) * z);
}

// Rest of the math (buildPerspective, multiply, fbm, noise, getElevation) 
// should be kept from the combined file, ensuring they use the safe 'fract' above.
