#include "Renderer.h"
#include "AssetManager.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>
#include <vector>

#define LOG_TAG "GrassEngine"

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
    camPitch = std::clamp(camPitch, -89.0f, 89.0f);
}

[span_2](start_span)// --- FIXED: Implementation of Missing Symbols ---[span_2](end_span)

GLuint GrassRenderer::compileShader(GLenum type, const std::string& source) {
    if (source.empty()) return 0;
    GLuint shader = glCreateShader(type);
    const char* src = source.c_str();
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);
    
    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetShaderInfoLog(shader, 512, nullptr, infoLog);
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, "Shader Error: %s", infoLog);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

GLuint GrassRenderer::createProgram(GLuint vShader, GLuint fShader) {
    if (!vShader || !fShader) return 0;
    GLuint program = glCreateProgram();
    glAttachShader(program, vShader);
    glAttachShader(program, fShader);
    glLinkProgram(program);
    return program;
}

GLuint GrassRenderer::createComputeProgram(GLuint cShader) {
    if (!cShader) return 0;
    GLuint program = glCreateProgram();
    glAttachShader(program, cShader);
    glLinkProgram(program);
    return program;
}

void GrassRenderer::generateTerrainGrid() {
    const int gridSize = 128;
    const float size = 100.0f; 
    std::vector<float> vertices;
    std::vector<unsigned short> indices;

    for(int z = 0; z <= gridSize; ++z) {
        for(int x = 0; x <= gridSize; ++x) {
            vertices.push_back(-size/2.0f + (float)x/gridSize * size);
            vertices.push_back(-size/2.0f + (float)z/gridSize * size);
        }
    }

    for(int z = 0; z < gridSize; ++z) {
        for(int x = 0; x < gridSize; ++x) {
            int row1 = z * (gridSize + 1);
            int row2 = (z + 1) * (gridSize + 1);
            indices.push_back(row1 + x); indices.push_back(row2 + x); indices.push_back(row1 + x + 1);
            indices.push_back(row1 + x + 1); indices.push_back(row2 + x); indices.push_back(row2 + x + 1);
        }
    }

    terrainIndexCount = indices.size();
    glGenVertexArrays(1, &terrainVao);
    glGenBuffers(1, &terrainVbo); glGenBuffers(1, &terrainEbo);
    glBindVertexArray(terrainVao);
    glBindBuffer(GL_ARRAY_BUFFER, terrainVbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, terrainEbo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned short), indices.data(), GL_STATIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

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

    float blade[] = { -0.03f, 0.0f, 0.0f, 0.03f, 0.0f, 0.0f, -0.02f, 0.4f, 0.0f, 0.02f, 0.4f, 0.0f, -0.01f, 0.8f, 0.0f, 0.01f, 0.8f, 0.0f, 0.0f, 1.1f, 0.0f };
    glGenVertexArrays(1, &vao); glGenBuffers(1, &vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(blade), blade, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    float dtSafe = std::min(dt, 0.033f);
    glViewport(0, 0, width, height);
    glClearColor(0.4f, 0.55f, 0.75f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if (!computeProgram || !renderProgram || !terrainProgram) return;
    glEnable(GL_DEPTH_TEST);

    float yawRad = camYaw * (M_PI / 180.0f);
    float pitchRad = camPitch * (M_PI / 180.0f);
    float lookX = cosf(yawRad) * cosf(pitchRad);
    float lookY = sinf(pitchRad);
    float lookZ = sinf(yawRad) * cosf(pitchRad);
    
    float fwdX = cosf(yawRad), fwdZ = sinf(yawRad);
    float rgtX = cosf(yawRad - M_PI / 2.0f), rgtZ = sinf(yawRad - M_PI / 2.0f);

    playerX += (fwdX * moveY + rgtX * moveX) * 10.0f * dtSafe;
    playerZ += (fwdZ * moveY + rgtZ * moveX) * 10.0f * dtSafe;
    playerY = getElevation(playerX, playerZ);

    float tX, tY, tZ;
    if (isThirdPerson) {
        tX = playerX - (lookX * cameraZoom);
        tY = (playerY + 2.0f) - (lookY * cameraZoom);
        tZ = playerZ - (lookZ * cameraZoom);
        float floor = getElevation(tX, tZ) + 0.5f;
        if (tY < floor) tY = floor;
    } else {
        tX = playerX; tY = playerY + 1.8f; tZ = playerZ;
    }

    camX += (tX - camX) * 12.0f * dtSafe;
    camY += (tY - camY) * 12.0f * dtSafe;
    camZ += (tZ - camZ) * 12.0f * dtSafe;

    float proj[16], view[16], vp[16];
    buildPerspective(proj, 0.8f, (float)width / (float)height, 0.1f, 1000.0f);
    if (isThirdPerson) buildLookAt(view, camX, camY, camZ, playerX, playerY + 1.5f, playerZ);
    else buildLookAt(view, camX, camY, camZ, camX + lookX, camY + lookY, camZ + lookZ);
    multiply(vp, proj, view);

    glUseProgram(computeProgram);
    glUniform1f(glGetUniformLocation(computeProgram, "u_Time"), time);
    glUniform3f(glGetUniformLocation(computeProgram, "u_CameraPos"), camX, camY, camZ);
    glDispatchCompute(32, 32, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    glUseProgram(terrainProgram);
    glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glUniform3f(glGetUniformLocation(terrainProgram, "u_CameraPos"), camX, camY, camZ);
    glBindVertexArray(terrainVao);
    glDrawElements(GL_TRIANGLES, terrainIndexCount, GL_UNSIGNED_SHORT, 0);

    glUseProgram(renderProgram);
    glUniformMatrix4fv(glGetUniformLocation(renderProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glBindVertexArray(vao);
    glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 7, GRASS_COUNT);

    if (isThirdPerson) playerModel.render(vp, playerX, playerY, playerZ, camYaw);
}

[span_3](start_span)// --- FIXED: Math Functions ---[span_3](end_span)

float GrassRenderer::getElevation(float x, float z) {
    auto hash = [](float n) { return fmodf(sinf(n) * 43758.5453f, 1.0f); };
    auto noise = [&](float x, float y) {
        float ix = floorf(x), iy = floorf(y);
        float fx = x - ix, fy = y - iy;
        float ux = fx * fx * (3.0f - 2.0f * fx);
        float a = hash(ix + iy * 57.0f), b = hash(ix + 1.0f + iy * 57.0f);
        float c = hash(ix + (iy + 1.0f) * 57.0f), d = hash(ix + 1.0f + (iy + 1.0f) * 57.0f);
        return a + (b-a)*ux + (c-a)*fy*(1.0f-ux) + (d-b)*fy*ux;
    };
    return noise(x * 0.05f, z * 0.05f) * 5.0f + noise(x * 0.1f, z * 0.1f) * 2.0f;
}

void GrassRenderer::buildPerspective(float* m, float fov, float aspect, float zn, float zf) {
    float f = 1.0f / tanf(fov / 2.0f);
    std::fill(m, m+16, 0.0f);
    m[0]=f/aspect; m[5]=f; m[10]=(zf+zn)/(zn-zf); m[11]=-1.0f; m[14]=(2.0f*zf*zn)/(zn-zf);
}

void GrassRenderer::buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz) {
    float fx=cx-ex, fy=cy-ey, fz=cz-ez;
    float rlf=1.0f/sqrtf(fx*fx+fy*fy+fz*fz+0.0001f); fx*=rlf; fy*=rlf; fz*=rlf;
    float sx=fy*0.0f-fz*1.0f, sy=fz*0.0f-fx*0.0f, sz=fx*1.0f-fy*0.0f;
    float rls=1.0f/sqrtf(sx*sx+sy*sy+sz*sz+0.0001f); sx*=rls; sy*=rls; sz*=rls;
    float ux=sy*fz-sz*fy, uy=sz*fx-sx*fz, uz=sx*fy-sy*fx;
    m[0]=sx; m[1]=ux; m[2]=-fx; m[3]=0.0f;
    m[4]=sy; m[5]=uy; m[6]=-fy; m[7]=0.0f;
    m[8]=sz; m[9]=uz; m[10]=-fz; m[11]=0.0f;
    m[12]=-(sx*ex+sy*ey+sz*ez); m[13]=-(ux*ex+uy*ey+uz*ez); m[14]=(fx*ex+fy*ey+fz*ez); m[15]=1.0f;
}

void GrassRenderer::multiply(float* out, const float* a, const float* b) {
    float t[16];
    for(int i=0; i<4; i++) for(int j=0; j<4; j++)
        t[j*4+i] = a[0*4+i]*b[j*4+0] + a[1*4+i]*b[j*4+1] + a[2*4+i]*b[j*4+2] + a[3*4+i]*b[j*4+3];
    std::copy(t, t+16, out);
}
