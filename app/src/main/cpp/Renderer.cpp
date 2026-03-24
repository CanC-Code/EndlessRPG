#include "Renderer.h"
#include "AssetManager.h"
#include <android/log.h>
#include <cmath>

#define LOG_TAG "GrassEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

GrassRenderer::GrassRenderer() : computeProgram(0), renderProgram(0), ssbo(0), vao(0), vbo(0) {}

GLuint GrassRenderer::compileShader(GLenum type, const std::string& source) {
    if (source.empty()) return 0;
    GLuint shader = glCreateShader(type);
    const char* src = source.c_str();
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);
    GLint success; glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) { glDeleteShader(shader); return 0; }
    return shader;
}

GLuint GrassRenderer::createProgram(GLuint vShader, GLuint fShader) {
    if (!vShader || !fShader) return 0;
    GLuint program = glCreateProgram();
    glAttachShader(program, vShader); glAttachShader(program, fShader);
    glLinkProgram(program);
    GLint success; glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) return 0;
    return program;
}

GLuint GrassRenderer::createComputeProgram(GLuint cShader) {
    if (!cShader) return 0;
    GLuint program = glCreateProgram();
    glAttachShader(program, cShader); glLinkProgram(program);
    GLint success; glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) return 0;
    return program;
}

void GrassRenderer::init() {
    std::string cSrc = NativeAssetManager::loadShaderText("shaders/grass.comp");
    std::string vSrc = NativeAssetManager::loadShaderText("shaders/grass.vert");
    std::string fSrc = NativeAssetManager::loadShaderText("shaders/grass.frag");
    
    computeProgram = createComputeProgram(compileShader(GL_COMPUTE_SHADER, cSrc));
    renderProgram = createProgram(compileShader(GL_VERTEX_SHADER, vSrc), compileShader(GL_FRAGMENT_SHADER, fSrc));

    glGenBuffers(1, &ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    glBufferData(GL_SHADER_STORAGE_BUFFER, GRASS_COUNT * 8 * sizeof(float), nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);

    float bladeVertices[] = {
        -0.03f, 0.0f, 0.0f,  0.03f, 0.0f, 0.0f, 
        -0.02f, 0.4f, 0.0f,  0.02f, 0.4f, 0.0f, 
        -0.01f, 0.8f, 0.0f,  0.01f, 0.8f, 0.0f, 
         0.0f,  1.1f, 0.0f 
    };

    glGenVertexArrays(1, &vao); glGenBuffers(1, &vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(bladeVertices), bladeVertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    glViewport(0, 0, width, height);
    glClearColor(0.5f, 0.75f, 1.0f, 1.0f); // Bright Sky Blue
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if (computeProgram == 0 || renderProgram == 0) return;

    glEnable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    // Slowly move the camera forward automatically to demonstrate the endless world
    camZ -= dt * 2.0f; 

    // Compute Pass (Infinite Grid Generation)
    glUseProgram(computeProgram);
    glUniform1f(glGetUniformLocation(computeProgram, "u_Time"), time);
    glUniform3f(glGetUniformLocation(computeProgram, "u_CameraPos"), camX, camY, camZ);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
    glDispatchCompute(512 / 16, 512 / 16, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // Render Pass
    glUseProgram(renderProgram);
    float proj[16], view[16], vp[16];
    buildPerspective(proj, 0.8f, (float)width / (float)height, 0.1f, 1000.0f);
    
    // Look slightly ahead of the camera
    buildLookAt(view, camX, camY, camZ, camX, camY - 0.2f, camZ - 5.0f);
    multiply(vp, proj, view);

    glUniformMatrix4fv(glGetUniformLocation(renderProgram, "u_ViewProjection"), 1, GL_FALSE, vp);
    glBindVertexArray(vao);
    glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 7, GRASS_COUNT);
}

// Math Helpers
void GrassRenderer::buildPerspective(float* m, float fov, float aspect, float zn, float zf) {
    float f = 1.0f / tanf(fov / 2.0f);
    for(int i=0; i<16; i++) m[i] = 0.0f;
    m[0]=f/aspect; m[5]=f; m[10]=(zf+zn)/(zn-zf); m[11]=-1.0f; m[14]=(2.0f*zf*zn)/(zn-zf);
}
void GrassRenderer::buildLookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz) {
    float fx=cx-ex, fy=cy-ey, fz=cz-ez;
    float rlf=1.0f/sqrtf(fx*fx+fy*fy+fz*fz); fx*=rlf; fy*=rlf; fz*=rlf;
    float sx=fy*0.0f-fz*1.0f, sy=fz*0.0f-fx*0.0f, sz=fx*1.0f-fy*0.0f;
    float rls=1.0f/sqrtf(sx*sx+sy*sy+sz*sz); sx*=rls; sy*=rls; sz*=rls;
    float ux=sy*fz-sz*fy, uy=sz*fx-sx*fz, uz=sx*fy-sy*fx;
    m[0]=sx; m[4]=ux; m[8]=-fx; m[12]=-(m[0]*ex+m[4]*ey+m[8]*ez); 
    m[1]=sy; m[5]=uy; m[9]=-fy; m[13]=-(m[1]*ex+m[5]*ey+m[9]*ez);
    m[2]=sz; m[6]=uz; m[10]=-fz; m[14]=-(m[2]*ex+m[6]*ey+m[10]*ez); 
    m[3]=0.0f; m[7]=0.0f; m[11]=0.0f; m[15]=1.0f;
}
void GrassRenderer::multiply(float* out, const float* a, const float* b) {
    float temp[16];
    for (int i=0; i<4; i++) for (int j=0; j<4; j++)
        temp[j*4+i] = a[0*4+i]*b[j*4+0] + a[1*4+i]*b[j*4+1] + a[2*4+i]*b[j*4+2] + a[3*4+i]*b[j*4+3];
    for (int i=0; i<16; i++) out[i] = temp[i];
}
