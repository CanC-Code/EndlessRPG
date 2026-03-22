#!/bin/bash
# File: runtime/generate_engine.sh
# Purpose: Non-deforming kinematic mapping, procedural high-res texturing.

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
#include <chrono>
#include "models/AllModels.h"

struct Mat4 {
    float m[16] = {0};
    static Mat4 identity() { Mat4 r; r.m[0]=1; r.m[5]=1; r.m[10]=1; r.m[15]=1; return r; }
    static Mat4 perspective(float fov, float asp, float n, float f) {
        Mat4 r; float t = 1.0f / tan(fov/2.0f); r.m[0]=t/asp; r.m[5]=t; 
        r.m[10]=(f+n)/(n-f); r.m[11]=-1; r.m[14]=(2*f*n)/(n-f); return r;
    }
    Mat4 mul(const Mat4& b) const {
        Mat4 r; for(int i=0; i<4; i++) for(int j=0; j<4; j++) for(int k=0; k<4; k++) 
            r.m[i*4+j] += m[k*4+j]*b.m[i*4+k];
        return r;
    }
    static Mat4 trans(float x, float y, float z) { Mat4 r=identity(); r.m[12]=x; r.m[13]=y; r.m[14]=z; return r; }
    static Mat4 rotY(float a) { Mat4 r=identity(); r.m[0]=cos(a); r.m[2]=-sin(a); r.m[8]=sin(a); r.m[10]=cos(a); return r; }
    static Mat4 rotX(float a) { Mat4 r=identity(); r.m[5]=cos(a); r.m[6]=sin(a); r.m[9]=-sin(a); r.m[10]=cos(a); return r; }
    static Mat4 rotZ(float a) { Mat4 r=identity(); r.m[0]=cos(a); r.m[1]=sin(a); r.m[4]=-sin(a); r.m[5]=cos(a); return r; }
    static Mat4 scale(float x, float y, float z) { Mat4 r=identity(); r.m[0]=x; r.m[5]=y; r.m[10]=z; return r; }
};

float getTerrainHeight(float x, float z) { return sin(x * 0.4f) * cos(z * 0.4f) * 1.5f; }

GLuint prog, vaoTorso, vaoHead, vaoUpLimb, vaoLowLimb, vaoSword, vaoShield, vaoTree, vaoTerrain;
Mat4 proj; // <-- FIX: Declared the projection matrix globally
float px=0, py=0, pz=0, pf=0, wt=0, st=0;
bool block=false;

GLuint createVAO(const float* d, int n) {
    GLuint vao, vbo; glGenVertexArrays(1,&vao); glGenBuffers(1,&vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER,vbo); 
    // Format: X, Y, Z, R, G, B, U, V (8 floats * 4 bytes = 32 stride)
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
            "out vec3 vc; out vec2 vuv; out vec4 wPos;\n"
            "void main(){\n"
            "  vec4 w=m*vec4(p,1.0);\n"
            "  if(isT>0.5) w.y += sin(w.x*0.4)*cos(w.z*0.4)*1.5;\n"
            "  wPos = w;\n"
            "  gl_Position=pr*v*w; vc=c; vuv=uv;\n"
            "}";
        
        // High-Resolution Procedural Texture Shader
        const char* fS = "#version 300 es\n"
            "precision mediump float;\n"
            "in vec3 vc; in vec2 vuv; in vec4 wPos;\n"
            "uniform float isT;\n"
            "out vec4 o;\n"
            "float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }\n"
            "float noise(vec2 p) {\n"
            "  vec2 i = floor(p); vec2 f = fract(p);\n"
            "  vec2 u = f*f*(3.0-2.0*f);\n"
            "  return mix(mix(hash(i+vec2(0.0,0.0)), hash(i+vec2(1.0,0.0)), u.x),\n"
            "             mix(hash(i+vec2(0.0,1.0)), hash(i+vec2(1.0,1.0)), u.x), u.y);\n"
            "}\n"
            "void main(){\n"
            "  vec3 col = vc;\n"
            "  if(isT>0.5) {\n"
            "    // Real Grass and Mud Generation\n"
            "    float n = noise(wPos.xz * 15.0) * 0.5 + noise(wPos.xz * 30.0) * 0.25;\n"
            "    float mudMap = noise(wPos.xz * 2.0);\n"
            "    vec3 grassCol = mix(vec3(0.1, 0.4, 0.1), vec3(0.3, 0.6, 0.2), n);\n"
            "    vec3 mudCol = mix(vec3(0.3, 0.2, 0.1), vec3(0.4, 0.3, 0.2), n);\n"
            "    col = mix(grassCol, mudCol, smoothstep(0.4, 0.6, mudMap)) * vc;\n"
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
        glClearColor(0.5f, 0.7f, 0.9f, 1.0f);
        glEnable(GL_DEPTH_TEST);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) {
        glViewport(0,0,w,h); proj = Mat4::perspective(1.0f, (float)w/h, 0.1f, 100.0f);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch, jfloat zoom) {
        if(fabs(ix)>0.0f || fabs(iy)>0.0f) {
            float s=sin(yaw), c=cos(yaw), dx=ix*c-(-iy)*s, dz=ix*s+(-iy)*c;
            px+=dx*0.1f; pz-=dz*0.1f; pf=atan2(-dx,dz); wt+=0.15f;
        } else { wt=0; }
        
        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glUseProgram(prog);
        glUniformMatrix4fv(glGetUniformLocation(prog,"pr"),1,0,proj.m);
        
        Mat4 v=Mat4::trans(0,0,-zoom).mul(Mat4::rotX(-pitch)).mul(Mat4::rotY(-yaw)).mul(Mat4::trans(-px,-1,-pz));
        glUniformMatrix4fv(glGetUniformLocation(prog,"v"),1,0,v.m);
        GLint lm=glGetUniformLocation(prog,"m"), lt=glGetUniformLocation(prog,"isT");

        // TERRAIN
        glUniform1f(lt, 1.0f);
        for(int i=-4; i<=4; i++) for(int j=-4; j<=4; j++) {
            float tx=floor(px/16.f)*16.f+i*16.f, tz=floor(pz/16.f)*16.f+j*16.f;
            Mat4 tm=Mat4::trans(tx,0,tz);
            glUniformMatrix4fv(lm,1,0,tm.m); glBindVertexArray(vaoTerrain); glDrawArrays(GL_TRIANGLES,0,N_TERRAIN);
        }
        
        // TREES
        glUniform1f(lt, 0.0f);
        for(int i=-2; i<=2; i++) for(int j=-2; j<=2; j++) {
            float tx=floor(px/16.f)*16.f+i*16.f, tz=floor(pz/16.f)*16.f+j*16.f;
            if(fmod(tx*1.2f+tz*0.8f, 6.f) > 4.5f) {
                Mat4 tm=Mat4::trans(tx,getTerrainHeight(tx,tz),tz);
                glUniformMatrix4fv(lm,1,0,tm.m); glBindVertexArray(vaoTree); glDrawArrays(GL_TRIANGLES,0,N_TREE);
            }
        }

        // PLAYER RENDER (Matrix separation fixes deformation)
        float th = getTerrainHeight(px,pz);
        Mat4 tBase = Mat4::trans(px, th+1.0f, pz).mul(Mat4::rotY(pf));

        // Torso
        glUniformMatrix4fv(lm,1,0,tBase.m); glBindVertexArray(vaoTorso); glDrawArrays(GL_TRIANGLES,0,N_TORSO);
        // Head
        Mat4 mHead = tBase.mul(Mat4::trans(0,0.85f,0));
        glUniformMatrix4fv(lm,1,0,mHead.m); glBindVertexArray(vaoHead); glDrawArrays(GL_TRIANGLES,0,N_HEAD);

        // Right Arm (Shield)
        float sArmRot = block ? -1.5f : sin(wt)*0.5f;
        Mat4 mRArmNode = tBase.mul(Mat4::trans(-0.35f, 0.6f, 0)).mul(Mat4::rotX(sArmRot));
        glUniformMatrix4fv(lm,1,0,mRArmNode.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
        
        Mat4 mRForeArm = mRArmNode.mul(Mat4::trans(0, -0.45f, 0));
        glUniformMatrix4fv(lm,1,0,mRForeArm.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);
        
        // SHIELD FIX: Apply explicit rotation at the wrist so it stands vertically
        Mat4 mShield = mRForeArm.mul(Mat4::trans(0, -0.48f, 0)).mul(Mat4::rotX(1.57f));
        glUniformMatrix4fv(lm,1,0,mShield.m); glBindVertexArray(vaoShield); glDrawArrays(GL_TRIANGLES,0,N_SHIELD);

        // Left Arm
        Mat4 mLArmNode = tBase.mul(Mat4::trans(0.35f, 0.6f, 0)).mul(Mat4::rotX(-sin(wt)*0.5f));
        glUniformMatrix4fv(lm,1,0,mLArmNode.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
        Mat4 mLForeArm = mLArmNode.mul(Mat4::trans(0, -0.45f, 0));
        glUniformMatrix4fv(lm,1,0,mLForeArm.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);

        // Legs
        Mat4 mRLeg = tBase.mul(Mat4::trans(-0.15f, 0.0f, 0)).mul(Mat4::rotX(-sin(wt)*0.8f));
        glUniformMatrix4fv(lm,1,0,mRLeg.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
        Mat4 mRLegLow = mRLeg.mul(Mat4::trans(0, -0.45f, 0));
        glUniformMatrix4fv(lm,1,0,mRLegLow.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);

        Mat4 mLLeg = tBase.mul(Mat4::trans(0.15f, 0.0f, 0)).mul(Mat4::rotX(sin(wt)*0.8f));
        glUniformMatrix4fv(lm,1,0,mLLeg.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
        Mat4 mLLegLow = mLLeg.mul(Mat4::trans(0, -0.45f, 0));
        glUniformMatrix4fv(lm,1,0,mLLegLow.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==2) block=true; else block=false;
    }
}
EOF
