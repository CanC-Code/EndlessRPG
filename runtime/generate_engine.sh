#!/bin/bash
echo "Injecting Physics Engine and Combo Combat System..."

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

// PHYSICS: Mathematical Terrain Alignment
float getTerrainHeight(float x, float z) {
    return sin(x * 0.4f) * cos(z * 0.4f) * 1.2f;
}

GLuint prog, vaoHero, vaoSword, vaoTree, vaoTerrain;
float px=0, pz=0, pf=0, wt=0, st=0;
int comboState = 0; // 0: Idle, 1: Swipe L, 2: Swipe R, 3: Overhead
volatile bool block=false;
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
        // GPU Shader exactly matches the CPU physics formula
        const char* vS = "#version 300 es\nlayout(location=0) in vec3 p; layout(location=1) in vec3 c; uniform mat4 m,v,pr; uniform float isT; out vec3 vc; out vec4 viewPos; void main(){ vec4 w=m*vec4(p,1.0); if(isT>0.5) w.y += sin(w.x*0.4)*cos(w.z*0.4)*1.2; viewPos=v*w; gl_Position=pr*viewPos; vc=c; }";
        const char* fS = "#version 300 es\nprecision mediump float; in vec3 vc; in vec4 viewPos; out vec4 o; void main(){ float dist=length(viewPos.xyz); float fog=clamp((dist-10.0)/40.0, 0.0, 1.0); vec3 sky=vec3(0.5,0.7,0.9); o=vec4(mix(vc,sky,fog), 1.0); }";
        
        GLuint vs=glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs,1,&vS,0); glCompileShader(vs);
        GLuint fs=glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs,1,&fS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog); glUseProgram(prog);
        glEnable(GL_DEPTH_TEST); glEnable(GL_CULL_FACE);
        
        vaoHero=createVAO(M_HERO, N_HERO); vaoSword=createVAO(M_SWORD, N_SWORD); 
        vaoTree=createVAO(M_TREE, N_TREE); vaoTerrain=createVAO(M_TERRAIN, N_TERRAIN);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) {
        glViewport(0,0,w,h); proj=Mat4::perspective(1.0f, (float)w/h, 0.1f, 100.0f);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch, jfloat zoom) {
        if(fabs(ix)>0.05f || fabs(iy)>0.05f) {
            float s=sin(yaw), c=cos(yaw), dx=ix*c-(-iy)*s, dz=ix*s+(-iy)*c;
            px+=dx*0.14f; pz-=dz*0.14f; pf=atan2(-dx,dz); wt+=0.2f;
        }

        if(comboState > 0) {
            st += 0.3f;
            if(st > 3.14f) { comboState = 0; st = 0; }
        }

        glClearColor(0.5f, 0.7f, 0.9f, 1.0f); 
        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT); 
        
        GLint lp=glGetUniformLocation(prog,"pr"), lv=glGetUniformLocation(prog,"v"), lm=glGetUniformLocation(prog,"m"), lt=glGetUniformLocation(prog,"isT");
        glUniformMatrix4fv(lp,1,0,proj.m);
        
        float py = getTerrainHeight(px, pz);
        Mat4 v=Mat4::trans(0,0,-zoom).mul(Mat4::rotX(-pitch)).mul(Mat4::rotY(-yaw)).mul(Mat4::trans(-px,-(py+1.5f),-pz));
        glUniformMatrix4fv(lv,1,0,v.m);
        
        glUniform1f(lt, 1.0f); 
        for(int i=-4; i<=4; i++) for(int j=-4; j<=4; j++) {
            float tx=floor(px/8.f)*8.f+i*8.f, tz=floor(pz/8.f)*8.f+j*8.f;
            Mat4 tm=Mat4::trans(tx,0,tz); glUniformMatrix4fv(lm,1,0,tm.m);
            glBindVertexArray(vaoTerrain); glDrawArrays(GL_TRIANGLES,0,N_TERRAIN);
        }
        
        glUniform1f(lt, 0.0f); 
        glBindVertexArray(vaoTree);
        for(int i=-4; i<=4; i++) for(int j=-4; j<=4; j++) {
            float tx=floor(px/8.f)*8.f+i*8.f, tz=floor(pz/8.f)*8.f+j*8.f;
            if(fmod(tx*1.2f+tz*0.8f, 6.f)>4.8f) {
                float ty = getTerrainHeight(tx, tz);
                Mat4 tm=Mat4::trans(tx,ty,tz); glUniformMatrix4fv(lm,1,0,tm.m);
                glDrawArrays(GL_TRIANGLES,0,N_TREE);
            }
        }
        
        Mat4 h=Mat4::trans(px,py + (sin(wt)*0.08f),pz).mul(Mat4::rotY(pf));
        glUniformMatrix4fv(lm,1,0,h.m); glBindVertexArray(vaoHero); glDrawArrays(GL_TRIANGLES,0,N_HERO);
        
        Mat4 s=h; 
        if(comboState == 1) s=h.mul(Mat4::trans(0,0.5,0)).mul(Mat4::rotY(-sin(st)*2.0)).mul(Mat4::rotX(-1.5)).mul(Mat4::trans(0,-0.5,0));
        else if(comboState == 2) s=h.mul(Mat4::trans(0,0.5,0)).mul(Mat4::rotY(sin(st)*2.0)).mul(Mat4::rotX(-1.5)).mul(Mat4::trans(0,-0.5,0));
        else if(comboState == 3) s=h.mul(Mat4::trans(0,0.5,0)).mul(Mat4::rotX(-sin(st)*3.0)).mul(Mat4::trans(0,-0.5,0));
        
        glUniformMatrix4fv(lm,1,0,s.m); glBindVertexArray(vaoSword); glDrawArrays(GL_TRIANGLES,0,N_SWORD);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) {
            if(comboState == 0 || st > 2.0f) { 
                comboState++; 
                if(comboState > 3) comboState = 1; 
                st = 0; 
            }
        } 
    }
}
EOF
