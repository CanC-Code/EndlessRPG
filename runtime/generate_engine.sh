#!/bin/bash
# File: runtime/generate_engine.sh
# Purpose: High-fidelity engine with restored gameplay mechanics and fix for CXX1400.

# Ensure the directory exists before writing files
mkdir -p app/src/main/cpp/models

cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
target_link_libraries(procedural_engine log GLESv3)
EOF

cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <cmath>
#include "models/AllModels.h"

struct Mat4 {
    float m[16] = {0};
    static Mat4 identity() { Mat4 r; r.m[0]=1; r.m[5]=1; r.m[10]=1; r.m[15]=1; return r; }
    static Mat4 perspective(float f, float a, float n, float fr) {
        Mat4 r; float t = 1.0f/tan(f/2.0f); r.m[0]=t/a; r.m[5]=t; r.m[10]=(fr+n)/(n-fr); r.m[11]=-1; r.m[14]=(2*fr*n)/(n-fr); return r;
    }
    Mat4 mul(const Mat4& b) const {
        Mat4 r; for(int i=0; i<4; i++) for(int j=0; j<4; j++) for(int k=0; k<4; k++) r.m[i*4+j]+=m[k*4+j]*b.m[i*4+k]; return r;
    }
    static Mat4 trans(float x, float y, float z) { Mat4 r=identity(); r.m[12]=x; r.m[13]=y; r.m[14]=z; return r; }
    static Mat4 rotY(float a) { Mat4 r=identity(); r.m[0]=cos(a); r.m[2]=-sin(a); r.m[8]=sin(a); r.m[10]=cos(a); return r; }
    static Mat4 rotX(float a) { Mat4 r=identity(); r.m[5]=cos(a); r.m[6]=sin(a); r.m[9]=-sin(a); r.m[10]=cos(a); return r; }
};

GLuint prog, vaoTorso, vaoHead, vaoUpLimb, vaoLowLimb, vaoSword, vaoShield, vaoTree, vaoTerrain;
Mat4 proj; // Global projection matrix
float px=0, py=0, pz=0, pf=0, wt=0;
float jumpT=0, slashT=0, bashT=0; 
bool block=false;

GLuint createVAO(const float* d, int n) {
    GLuint vao, vbo; glGenVertexArrays(1,&vao); glGenBuffers(1,&vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glBufferData(GL_ARRAY_BUFFER, n*32, d, GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,32,0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,32,(void*)12); glEnableVertexAttribArray(1);
    glVertexAttribPointer(2,2,GL_FLOAT,GL_FALSE,32,(void*)24); glEnableVertexAttribArray(2);
    return vao;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        const char* vS = "#version 300 es\n"
            "layout(location=0) in vec3 p; layout(location=1) in vec3 c; layout(location=2) in vec2 uv;\n"
            "uniform mat4 m,v,pr; uniform float isT;\n"
            "out vec3 vc; out vec4 wPos;\n"
            "void main(){\n"
            "  vec4 w=m*vec4(p,1.0);\n"
            "  if(isT>0.5) w.y += sin(w.x*0.4)*cos(w.z*0.4)*1.5;\n"
            "  wPos = w;\n"
            "  gl_Position=pr*v*w; vc=c;\n"
            "}";
        
        const char* fS = "#version 300 es\n"
            "precision mediump float;\n"
            "in vec3 vc; in vec4 wPos;\n"
            "uniform float isT;\n"
            "out vec4 o;\n"
            "float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }\n"
            "void main(){\n"
            "  vec3 col = vc;\n"
            "  if(isT>0.5) {\n"
            "    float n = hash(floor(wPos.xz * 15.0));\n"
            "    vec3 grassCol = mix(vec3(0.1, 0.4, 0.1), vec3(0.3, 0.6, 0.2), n);\n"
            "    vec3 mudCol = mix(vec3(0.3, 0.2, 0.1), vec3(0.4, 0.3, 0.2), n);\n"
            "    col = mix(grassCol, mudCol, smoothstep(0.4, 0.6, hash(floor(wPos.xz * 2.0)))) * vc;\n"
            "  }\n"
            "  o = vec4(col, 1.0);\n"
            "}";

        GLuint vs=glCreateShader(GL_VERTEX_SHADER), fs=glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(vs,1,&vS,0); glCompileShader(vs);
        glShaderSource(fs,1,&fS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog);

        vaoTorso = createVAO(M_TORSO, N_TORSO);
        vaoHead = createVAO(M_HEAD, N_HEAD);
        vaoUpLimb = createVAO(M_UP_LIMB, N_UP_LIMB);
        vaoLowLimb = createVAO(M_LOW_LIMB, N_LOW_LIMB);
        vaoSword = createVAO(M_SWORD, N_SWORD);
        vaoShield = createVAO(M_SHIELD, N_SHIELD);
        vaoTree = createVAO(M_TREE, N_TREE);
        vaoTerrain = createVAO(M_TERRAIN, N_TERRAIN);
        glEnable(GL_DEPTH_TEST);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) {
        glViewport(0,0,w,h);
        proj = Mat4::perspective(1.0f, (float)w/h, 0.1f, 100.0f);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) slashT=1.0f;
        if(id==2) block=true;
        if(id==3) block=false;
        if(id==4) jumpT=1.0f;
        if(id==6) bashT=1.0f;
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch, jfloat zoom) {
        if(slashT > 0) slashT -= 0.05f;
        if(jumpT > 0) jumpT -= 0.04f;
        if(bashT > 0) bashT -= 0.08f;
        if(fabs(ix)>0.0f || fabs(iy)>0.0f) {
            float s=sin(yaw), c=cos(yaw), dx=ix*c-(-iy)*s, dz=ix*s+(-iy)*c;
            px+=dx*0.1f; pz-=dz*0.1f; pf=atan2(-dx,dz); wt+=0.15f;
        } else { wt=0; }
        
        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glUseProgram(prog);
        glUniformMatrix4fv(glGetUniformLocation(prog,"pr"),1,GL_FALSE,proj.m);
        
        float jumpY = 4.0f * jumpT * (1.0f - jumpT);
        float th = sin(px*0.4f)*cos(pz*0.4f)*1.5f;
        Mat4 v=Mat4::trans(0,0,-zoom).mul(Mat4::rotX(-pitch)).mul(Mat4::rotY(-yaw)).mul(Mat4::trans(-px,-1-jumpY-th,-pz));
        glUniformMatrix4fv(glGetUniformLocation(prog,"v"),1,GL_FALSE,v.m);
        
        GLint lm=glGetUniformLocation(prog,"m"), lt=glGetUniformLocation(prog,"isT");
        Mat4 tBase = Mat4::trans(px, th+1.0f+jumpY, pz).mul(Mat4::rotY(pf));

        // Render Terrain
        glUniform1f(lt, 1.0f);
        for(int i=-4; i<=4; i++) for(int j=-4; j<=4; j++) {
            float tx=floor(px/16.f)*16.f+i*16.f, tz=floor(pz/16.f)*16.f+j*16.f;
            Mat4 tm=Mat4::trans(tx,0,tz);
            glUniformMatrix4fv(lm,1,GL_FALSE,tm.m); glBindVertexArray(vaoTerrain); glDrawArrays(GL_TRIANGLES,0,N_TERRAIN);
        }

        // Render Character (Matrix separation ensures no deformation)
        glUniform1f(lt, 0.0f);
        glUniformMatrix4fv(lm,1,GL_FALSE,tBase.m); glBindVertexArray(vaoTorso); glDrawArrays(GL_TRIANGLES,0,N_TORSO);
        
        // Shield (Vertical Fix + Bash Animation)
        float sRot = block ? -1.5f : (bashT > 0 ? -1.8f : sin(wt)*0.5f);
        Mat4 mRArm = tBase.mul(Mat4::trans(-0.35f, 0.6f, 0)).mul(Mat4::rotX(sRot));
        Mat4 mShield = mRArm.mul(Mat4::trans(0, -0.9f, 0)).mul(Mat4::rotX(1.57f)); 
        glUniformMatrix4fv(lm,1,GL_FALSE,mShield.m); glBindVertexArray(vaoShield); glDrawArrays(GL_TRIANGLES,0,N_SHIELD);

        // Sword (Attack Swing)
        float swRot = (slashT > 0) ? -2.5f * sin(slashT * 3.14f) : -sin(wt)*0.5f;
        Mat4 mLArm = tBase.mul(Mat4::trans(0.35f, 0.6f, 0)).mul(Mat4::rotX(swRot));
        Mat4 mSword = mLArm.mul(Mat4::trans(0,-0.9f,0));
        glUniformMatrix4fv(lm,1,GL_FALSE,mSword.m); glBindVertexArray(vaoSword); glDrawArrays(GL_TRIANGLES,0,N_SWORD);
    }
}
EOF
