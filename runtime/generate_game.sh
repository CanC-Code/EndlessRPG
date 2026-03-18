#!/bin/bash
echo "Dynamically Generating C++ Engine..."

# 1. CMakeLists
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
find_library(log-lib log)
find_library(gles3-lib GLESv3)
target_link_libraries(procedural_engine ${log-lib} ${gles3-lib})
EOF

# 2. Math Library
cat << 'EOF' > app/src/main/cpp/MathUtils.h
#pragma once
#include <cmath>
struct Mat4 {
    float m[16] = {0};
    static Mat4 identity() { Mat4 res; res.m[0]=1; res.m[5]=1; res.m[10]=1; res.m[15]=1; return res; }
    static Mat4 perspective(float fov, float aspect, float nearZ, float farZ) {
        Mat4 res; float f = 1.0f / tan(fov / 2.0f);
        res.m[0] = f / aspect; res.m[5] = f;
        res.m[10] = (farZ + nearZ) / (nearZ - farZ); res.m[11] = -1.0f;
        res.m[14] = (2.0f * farZ * nearZ) / (nearZ - farZ); return res;
    }
    Mat4 multiply(const Mat4& right) const {
        Mat4 res;
        for (int c=0; c<4; ++c) for (int r=0; r<4; ++r)
            res.m[c*4+r] = m[0*4+r]*right.m[c*4+0] + m[1*4+r]*right.m[c*4+1] + m[2*4+r]*right.m[c*4+2] + m[3*4+r]*right.m[c*4+3];
        return res;
    }
    static Mat4 translate(float x, float y, float z) {
        Mat4 res = identity(); res.m[12]=x; res.m[13]=y; res.m[14]=z; return res;
    }
    static Mat4 rotateY(float angle) {
        Mat4 res = identity(); float c=cos(angle), s=sin(angle);
        res.m[0]=c; res.m[2]=-s; res.m[8]=s; res.m[10]=c; return res;
    }
    static Mat4 rotateX(float angle) {
        Mat4 res = identity(); float c=cos(angle), s=sin(angle);
        res.m[5]=c; res.m[6]=s; res.m[9]=-s; res.m[10]=c; return res;
    }
};
EOF

# 3. Game Engine Core
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include "GeneratedModels.h"
#include "MathUtils.h"

const char* vS = "#version 300 es\nlayout(location=0) in vec3 p; layout(location=1) in vec3 c;\nuniform mat4 uProj, uView, uModel;\nout vec3 vCol; void main(){ gl_Position = uProj * uView * uModel * vec4(p,1.0); vCol = c; }";
const char* fS = "#version 300 es\nprecision mediump float; in vec3 vCol; out vec4 o; void main(){ o = vec4(vCol, 1.0); }";

GLuint prog, vaoBody, vaoHead, vaoCape, vaoSword, vaoShield, vaoTree, vaoGround;
float pX = 0, pZ = 0, pFace = 0, walkTimer = 0, slashTimer = 0;
volatile bool isSlashing = false, isBlocking = false;
Mat4 projMatrix;

GLuint createVAO(const float* data, int numVerts) {
    GLuint vao, vbo; glGenVertexArrays(1, &vao); glGenBuffers(1, &vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, numVerts * 6 * sizeof(float), data, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)(3 * sizeof(float))); glEnableVertexAttribArray(1);
    glBindVertexArray(0); return vao;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        GLuint vs = glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs, 1, &vS, 0); glCompileShader(vs);
        GLuint fs = glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs, 1, &fS, 0); glCompileShader(fs);
        prog = glCreateProgram(); glAttachShader(prog, vs); glAttachShader(prog, fs); glLinkProgram(prog);
        glUseProgram(prog); glEnable(GL_DEPTH_TEST); glEnable(GL_CULL_FACE);

        vaoBody = createVAO(M_BODY, N_BODY); vaoHead = createVAO(M_HEAD, N_HEAD);
        vaoCape = createVAO(M_CAPE, N_CAPE); vaoSword = createVAO(M_SWORD, N_SWORD);
        vaoShield = createVAO(M_SHIELD, N_SHIELD); vaoTree = createVAO(M_TREE, N_TREE);

        float g[] = { -100,0,-100, 0.2f,0.5f,0.2f, 100,0,-100, 0.2f,0.5f,0.2f, -100,0,100, 0.2f,0.5f,0.2f,
                       100,0,-100, 0.2f,0.5f,0.2f, 100,0,100, 0.2f,0.5f,0.2f, -100,0,100, 0.2f,0.5f,0.2f };
        vaoGround = createVAO(g, 6);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) {
        glViewport(0, 0, w, h); projMatrix = Mat4::perspective(3.14159f / 3.0f, (float)w / h, 0.1f, 100.0f);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy) {
        bool moving = (fabs(ix) > 0.05f || fabs(iy) > 0.05f);
        if(!isBlocking && moving) { pX += ix * 0.15f; pZ -= iy * 0.15f; walkTimer += 0.2f; pFace = atan2(-ix, -iy); } 
        else if (!moving) { walkTimer = 0; }
        if(isSlashing) { slashTimer += 0.3f; if(slashTimer > 3.14f) { isSlashing = false; slashTimer = 0; } }

        glClearColor(0.4f, 0.7f, 1.0f, 1.0f); glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        GLint lProj = glGetUniformLocation(prog, "uProj"), lView = glGetUniformLocation(prog, "uView"), lModl = glGetUniformLocation(prog, "uModel");
        glUniformMatrix4fv(lProj, 1, GL_FALSE, projMatrix.m);

        Mat4 viewMatrix = Mat4::translate(-pX, -3.5f, -pZ - 9.0f).multiply(Mat4::rotateX(0.3f));
        glUniformMatrix4fv(lView, 1, GL_FALSE, viewMatrix.m);

        glUniformMatrix4fv(lModl, 1, GL_FALSE, Mat4::identity().m);
        glBindVertexArray(vaoGround); glDrawArrays(GL_TRIANGLES, 0, 6);

        // Infinite World Generation
        glBindVertexArray(vaoTree);
        for(int i=-3; i<=3; i++) {
            for(int j=-3; j<=3; j++) {
                float wx = floor(pX/8.0f)*8.0f + i*8.0f, wz = floor(pZ/8.0f)*8.0f + j*8.0f;
                if(fmod(wx*1.2f + wz*0.7f, 6.0f) > 4.5f) {
                    Mat4 tMat = Mat4::translate(wx, 0, wz);
                    glUniformMatrix4fv(lModl, 1, GL_FALSE, tMat.m); glDrawArrays(GL_TRIANGLES, 0, N_TREE);
                }
            }
        }

        // Action & Animation Sequences
        float bob = sin(walkTimer) * 0.08f;
        Mat4 baseTrans = Mat4::translate(pX, bob, pZ).multiply(Mat4::rotateY(pFace));

        glUniformMatrix4fv(lModl, 1, GL_FALSE, baseTrans.m);
        glBindVertexArray(vaoBody); glDrawArrays(GL_TRIANGLES, 0, N_BODY);
        glBindVertexArray(vaoHead); glDrawArrays(GL_TRIANGLES, 0, N_HEAD);

        Mat4 capeTrans = baseTrans.multiply(Mat4::rotateX(moving ? -0.4f : -0.1f));
        glUniformMatrix4fv(lModl, 1, GL_FALSE, capeTrans.m);
        glBindVertexArray(vaoCape); glDrawArrays(GL_TRIANGLES, 0, N_CAPE);

        Mat4 swordTrans = baseTrans;
        if(isSlashing) swordTrans = baseTrans.multiply(Mat4::translate(0, 0.5f, 0)).multiply(Mat4::rotateX(-sin(slashTimer) * 2.5f)).multiply(Mat4::translate(0, -0.5f, 0));
        glUniformMatrix4fv(lModl, 1, GL_FALSE, swordTrans.m);
        glBindVertexArray(vaoSword); glDrawArrays(GL_TRIANGLES, 0, N_SWORD);

        Mat4 shieldTrans = baseTrans;
        if(isBlocking) shieldTrans = baseTrans.multiply(Mat4::translate(0, 0.2f, 0.4f));
        else if(moving) shieldTrans = baseTrans.multiply(Mat4::translate(0, -bob*2.0f, 0));
        glUniformMatrix4fv(lModl, 1, GL_FALSE, shieldTrans.m);
        glBindVertexArray(vaoShield); glDrawArrays(GL_TRIANGLES, 0, N_SHIELD);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1 && !isSlashing) { isSlashing = true; slashTimer = 0; } 
        else if(id==2) isBlocking = true; else if(id==3) isBlocking = false;
    }
}
EOF

# Execute the Blender modeler script directly from the engine generator
echo "Running Headless Blender Pipeline..."
blender --background --python runtime/build_models.py
