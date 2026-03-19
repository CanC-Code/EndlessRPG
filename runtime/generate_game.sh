#!/bin/bash
echo "Dynamically Generating Advanced Engine..."

# 1. CMakeLists (Fixes Undefined OpenGL Symbols)
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
target_link_libraries(procedural_engine log GLESv3)
EOF

# 2. Matrix Math Utility
cat << 'EOF' > app/src/main/cpp/MathUtils.h
#pragma once
#include <cmath>
struct Mat4 {
    float m[16] = {0};
    static Mat4 identity() { Mat4 r; r.m[0]=1; r.m[5]=1; r.m[10]=1; r.m[15]=1; return r; }
    static Mat4 perspective(float fov, float asp, float n, float f) {
        Mat4 r; float t = 1.0f / tan(fov/2.0f); r.m[0]=t/asp; r.m[5]=t; 
        r.m[10]=(f+n)/(n-f); r.m[11]=-1; r.m[14]=(2*f*n)/(n-f); return r;
    }
    Mat4 mul(const Mat4& b) const {
        Mat4 r; for(int i=0; i<4; i++) for(int j=0; j<4; j++) for(int k=0; k<4; k++) 
            r.m[i*4+j] += m[k*4+j]*b.m[i*4+k]; return r;
    }
    static Mat4 trans(float x, float y, float z) { Mat4 r=identity(); r.m[12]=x; r.m[13]=y; r.m[14]=z; return r; }
    static Mat4 rotY(float a) { Mat4 r=identity(); r.m[0]=cos(a); r.m[2]=-sin(a); r.m[8]=sin(a); r.m[10]=cos(a); return r; }
    static Mat4 rotX(float a) { Mat4 r=identity(); r.m[5]=cos(a); r.m[6]=sin(a); r.m[9]=-sin(a); r.m[10]=cos(a); return r; }
};
EOF

# 3. Native JNI Engine (Orbital Camera & World Generation)
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <cmath>
#include "GeneratedModels.h"
#include "MathUtils.h"

const char* vS = "#version 300 es\nlayout(location=0) in vec3 p; layout(location=1) in vec3 c; uniform mat4 m, v, pr; out vec3 vc; void main(){ gl_Position=pr*v*m*vec4(p,1.0); vc=c; }";
const char* fS = "#version 300 es\nprecision mediump float; in vec3 vc; out vec4 o; void main(){ o=vec4(vc,1.0); }";

GLuint prog, vaoHero, vaoSword, vaoShield, vaoTree, vaoGround;
float px=0, pz=0, pf=0, wt=0, st=0;
volatile bool slash=false, block=false;
Mat4 proj;

GLuint createVAO(const float* d, int n) {
    GLuint vao, vbo; glGenVertexArrays(1,&vao); glGenBuffers(1,&vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER,vbo); glBufferData(GL_ARRAY_BUFFER, n*24, d, GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,0,24,0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1,3,GL_FLOAT,0,24,(void*)12); glEnableVertexAttribArray(1);
    return vao;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        GLuint vs=glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs,1,&vS,0); glCompileShader(vs);
        GLuint fs=glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs,1,&fS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog); glUseProgram(prog);
        glEnable(GL_DEPTH_TEST); 
        vaoHero=createVAO(M_BODY, N_BODY); vaoSword=createVAO(M_SWORD, N_SWORD); 
        vaoShield=createVAO(M_SHIELD, N_SHIELD); vaoTree=createVAO(M_TREE, N_TREE);
        float g[]={-100,0,-100,0.2,0.5,0.2, 100,0,-100,0.2,0.5,0.2, -100,0,100,0.2,0.5,0.2, 100,0,-100,0.2,0.5,0.2, 100,0,100,0.2,0.5,0.2, -100,0,100,0.2,0.5,0.2};
        vaoGround=createVAO(g,6);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) {
        glViewport(0,0,w,h); proj=Mat4::perspective(1.0f, (float)w/h, 0.1f, 100.0f);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch, jfloat zoom) {
        if(fabs(ix)>0.05f || fabs(iy)>0.05f) {
            float s=sin(yaw), c=cos(yaw), dx=ix*c-(-iy)*s, dz=ix*s+(-iy)*c;
            px+=dx*0.15f; pz-=dz*0.15f; pf=atan2(-dx,dz); wt+=0.2f;
        }
        if(slash) { st+=0.3f; if(st>3.14f){ slash=false; st=0; } }
        glClearColor(0.4f,0.7f,1.0f,1.0f); glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glUniformMatrix4fv(glGetUniformLocation(prog,"pr"),1,0,proj.m);
        Mat4 view = Mat4::trans(0,0,-zoom).mul(Mat4::rotX(-pitch)).mul(Mat4::rotY(-yaw)).mul(Mat4::trans(-px,-1,-pz));
        glUniformMatrix4fv(glGetUniformLocation(prog,"v"),1,0,view.m);
        
        glUniformMatrix4fv(glGetUniformLocation(prog,"m"),1,0,Mat4::identity().m);
        glBindVertexArray(vaoGround); glDrawArrays(GL_TRIANGLES,0,6);

        glBindVertexArray(vaoTree);
        for(int i=-3; i<=3; i++) for(int j=-3; j<=3; j++) {
            float wx=floor(px/8.f)*8.f+i*8.f, wz=floor(pz/8.f)*8.f+j*8.f;
            if(fmod(wx*1.2f+wz*0.7f, 6.f)>4.5f) {
                Mat4 m=Mat4::trans(wx,0,wz); glUniformMatrix4fv(glGetUniformLocation(prog,"m"),1,0,m.m);
                glDrawArrays(GL_TRIANGLES,0,N_TREE);
            }
        }
        Mat4 hero=Mat4::trans(px,sin(wt)*0.08f,pz).mul(Mat4::rotY(pf));
        glUniformMatrix4fv(glGetUniformLocation(prog,"m"),1,0,hero.m);
        glBindVertexArray(vaoHero); glDrawArrays(GL_TRIANGLES,0,N_BODY);
        
        Mat4 sword=hero; if(slash) sword=hero.mul(Mat4::trans(0,0.5,0)).mul(Mat4::rotX(-sin(st)*2.5)).mul(Mat4::trans(0,-0.5,0));
        glUniformMatrix4fv(glGetUniformLocation(prog,"m"),1,0,sword.m);
        glBindVertexArray(vaoSword); glDrawArrays(GL_TRIANGLES,0,N_SWORD);

        Mat4 shield=hero; if(block) shield=hero.mul(Mat4::trans(0,0.2,0.4));
        glUniformMatrix4fv(glGetUniformLocation(prog,"m"),1,0,shield.m);
        glBindVertexArray(vaoShield); glDrawArrays(GL_TRIANGLES,0,N_SHIELD);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) slash=true; else if(id==2) block=true; else block=false;
    }
}
EOF

# 4. Trigger Blender
blender --background --python runtime/build_models.py
