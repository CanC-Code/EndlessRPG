#!/bin/bash
echo "Writing Core C++ Engine and Gameplay Scripts..."

cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
target_link_libraries(procedural_engine log GLESv3)
EOF

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
    static Mat4 ortho(float l, float r, float b, float t, float n, float f) {
        Mat4 res; res.m[0]=2/(r-l); res.m[5]=2/(t-b); res.m[10]=-2/(f-n);
        res.m[12]=-(r+l)/(r-l); res.m[13]=-(t+b)/(t-b); res.m[14]=-(f+n)/(f-n); res.m[15]=1; return res;
    }
    Mat4 mul(const Mat4& b) const {
        Mat4 r; for(int i=0; i<4; i++) for(int j=0; j<4; j++) for(int k=0; k<4; k++) 
            r.m[i*4+j] += m[k*4+j]*b.m[i*4+k]; return r;
    }
    static Mat4 trans(float x, float y, float z) { Mat4 r=identity(); r.m[12]=x; r.m[13]=y; r.m[14]=z; return r; }
    static Mat4 rotY(float a) { Mat4 r=identity(); r.m[0]=cos(a); r.m[2]=-sin(a); r.m[8]=sin(a); r.m[10]=cos(a); return r; }
    static Mat4 rotX(float a) { Mat4 r=identity(); r.m[5]=cos(a); r.m[6]=sin(a); r.m[9]=-sin(a); r.m[10]=cos(a); return r; }
    static Mat4 scale(float x, float y, float z) { Mat4 r=identity(); r.m[0]=x; r.m[5]=y; r.m[10]=z; return r; }
};

bool checkCollision(float x1, float z1, float r1, float x2, float z2, float r2) {
    float dx = x1 - x2, dz = z1 - z2;
    return (sqrt(dx*dx + dz*dz) < (r1 + r2));
}
EOF

cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <vector>
#include <cstdlib>
#include <android/log.h>
#include "GeneratedModels.h"
#include "MathUtils.h"

// 3D Shader
const char* vS = "#version 300 es\nlayout(location=0) in vec3 p; layout(location=1) in vec3 c; uniform mat4 m, v, pr; out vec3 vc; void main(){ gl_Position=pr*v*m*vec4(p,1.0); vc=c; }";
const char* fS = "#version 300 es\nprecision mediump float; in vec3 vc; uniform vec3 tint; out vec4 o; void main(){ o=vec4(vc * tint, 1.0); }";

GLuint prog, vaoHero, vaoEnemy, vaoSword, vaoShield, vaoTree, vaoRock, vaoGround;
float px=0, pz=0, pf=0, wt=0, st=0;
volatile bool slash=false, block=false;
Mat4 proj, orthoProj;
int screenW, screenH;

// Game State
int playerHealth = 100;
struct Enemy { float x, z; int hp; float flashTimer; };
std::vector<Enemy> enemies;

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
        glEnable(GL_DEPTH_TEST); glEnable(GL_CULL_FACE);
        
        vaoHero=createVAO(M_HERO, N_HERO); vaoEnemy=createVAO(M_ENEMY, N_ENEMY);
        vaoSword=createVAO(M_SWORD, N_SWORD); vaoShield=createVAO(M_SHIELD, N_SHIELD); 
        vaoTree=createVAO(M_TREE, N_TREE); vaoRock=createVAO(M_ROCK, N_ROCK);
        
        float g[]={-100,0,-100,0.3,0.6,0.2, 100,0,-100,0.3,0.6,0.2, -100,0,100,0.3,0.6,0.2, 100,0,-100,0.3,0.6,0.2, 100,0,100,0.3,0.6,0.2, -100,0,100,0.3,0.6,0.2};
        vaoGround=createVAO(g,6);

        for(int i=0; i<8; i++) enemies.push_back({(float)(rand()%30-15), (float)(rand()%30-15), 3, 0});
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) {
        glViewport(0,0,w,h); screenW=w; screenH=h;
        proj=Mat4::perspective(1.0f, (float)w/h, 0.1f, 100.0f);
        orthoProj=Mat4::ortho(0, w, 0, h, -1, 1);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch, jfloat zoom) {
        // MOVEMENT LOGIC
        if(fabs(ix)>0.05f || fabs(iy)>0.05f) {
            float s=sin(yaw), c=cos(yaw), dx=ix*c-(-iy)*s, dz=ix*s+(-iy)*c;
            px+=dx*0.12f; pz-=dz*0.12f; pf=atan2(-dx,dz); wt+=0.25f;
        }

        // COMBAT & COLLISION LOGIC
        if(slash) { 
            st+=0.3f; 
            if(st>3.14f) { slash=false; st=0; }
            if(st > 1.0f && st < 1.5f) { // Active Hit Frames
                float hX = px + sin(pf)*1.2f, hZ = pz - cos(pf)*1.2f;
                for(auto& e : enemies) {
                    if(e.hp > 0 && e.flashTimer <= 0 && checkCollision(hX, hZ, 1.0f, e.x, e.z, 0.6f)) {
                        e.hp -= 1; e.flashTimer = 1.0f; // Red hit flash
                    }
                }
            }
        }

        // ENEMY AI
        for(auto& e : enemies) {
            if(e.hp > 0) {
                if(e.flashTimer > 0) e.flashTimer -= 0.05f;
                float dx=px-e.x, dz=pz-e.z, dist=sqrt(dx*dx+dz*dz);
                if(dist > 0.8f && dist < 15.0f) { e.x += (dx/dist)*0.03f; e.z += (dz/dist)*0.03f; }
                else if(dist <= 0.8f && !block && rand()%100 < 5) playerHealth -= 5;
            }
        }
        if(playerHealth < 0) playerHealth = 0;

        glClearColor(0.2f,0.6f,0.9f,1.0f); glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        GLint lp=glGetUniformLocation(prog,"pr"), lv=glGetUniformLocation(prog,"v"), lm=glGetUniformLocation(prog,"m"), lt=glGetUniformLocation(prog,"tint");
        glUniformMatrix4fv(lp,1,0,proj.m);
        glUniform3f(lt, 1, 1, 1); // Reset tint
        
        Mat4 view = Mat4::trans(0,0,-zoom).mul(Mat4::rotX(-pitch)).mul(Mat4::rotY(-yaw)).mul(Mat4::trans(-px,-1,-pz));
        glUniformMatrix4fv(lv,1,0,view.m);
        
        // RENDER WORLD
        glUniformMatrix4fv(lm,1,0,Mat4::identity().m); glBindVertexArray(vaoGround); glDrawArrays(GL_TRIANGLES,0,6);
        for(int i=-4; i<=4; i++) for(int j=-4; j<=4; j++) {
            float wx=floor(px/6.f)*6.f+i*6.f, wz=floor(pz/6.f)*6.f+j*6.f, seed=fmod(wx*1.3f+wz*0.8f, 7.f);
            Mat4 m=Mat4::trans(wx,0,wz); glUniformMatrix4fv(lm,1,0,m.m);
            if(seed>5.5f) { glBindVertexArray(vaoTree); glDrawArrays(GL_TRIANGLES,0,N_TREE); }
            else if(seed>4.8f) { glBindVertexArray(vaoRock); glDrawArrays(GL_TRIANGLES,0,N_ROCK); }
        }

        // RENDER ENEMIES
        glBindVertexArray(vaoEnemy);
        for(auto& e : enemies) {
            if(e.hp > 0) {
                if(e.flashTimer > 0) glUniform3f(lt, 1, 0, 0); // Flash red on hit
                else glUniform3f(lt, 1, 1, 1);
                Mat4 eMat = Mat4::trans(e.x, sin(wt*0.5)*0.05f, e.z).mul(Mat4::rotY(atan2(px-e.x, e.z-pz)));
                glUniformMatrix4fv(lm,1,0,eMat.m); glDrawArrays(GL_TRIANGLES,0,N_ENEMY);
            }
        }
        glUniform3f(lt, 1, 1, 1); // Reset tint

        // RENDER PLAYER
        float bob=sin(wt)*0.08f; Mat4 hero=Mat4::trans(px,bob,pz).mul(Mat4::rotY(pf));
        glUniformMatrix4fv(lm,1,0,hero.m); glBindVertexArray(vaoHero); glDrawArrays(GL_TRIANGLES,0,N_HERO);
        
        Mat4 sword=hero; if(slash) sword=hero.mul(Mat4::trans(0,0.5,0)).mul(Mat4::rotX(-sin(st)*2.5)).mul(Mat4::trans(0,-0.5,0));
        glUniformMatrix4fv(lm,1,0,sword.m); glBindVertexArray(vaoSword); glDrawArrays(GL_TRIANGLES,0,N_SWORD);

        Mat4 shield=hero; if(block) shield=hero.mul(Mat4::trans(0,0.2,0.4));
        glUniformMatrix4fv(lm,1,0,shield.m); glBindVertexArray(vaoShield); glDrawArrays(GL_TRIANGLES,0,N_SHIELD);

        // HEALTH BAR UI OVERLAY (Orthographic)
        glDisable(GL_DEPTH_TEST);
        glUniformMatrix4fv(lp,1,0,orthoProj.m); glUniformMatrix4fv(lv,1,0,Mat4::identity().m);
        float hpWidth = (playerHealth / 100.0f) * 300.0f;
        Mat4 uiMat = Mat4::trans(50, screenH - 50, 0).mul(Mat4::scale(hpWidth, 20.0f, 1.0f));
        glUniformMatrix4fv(lm,1,0,uiMat.m); glUniform3f(lt, 1, 0, 0);
        // Reuse ground quad for UI flat rendering
        glBindVertexArray(vaoGround); glDrawArrays(GL_TRIANGLES,0,6);
        glEnable(GL_DEPTH_TEST);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1 && !slash) { slash=true; st=0; } else if(id==2) block=true; else if(id==3) block=false;
    }
}
EOF
