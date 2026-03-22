#!/bin/bash
echo "Injecting Physics Engine with Jump Gravity and Fixed Rotation..."

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
            r.m[i*4+j] += m[k*4+j]*b.m[i*4+k]; return r;
    }
    static Mat4 trans(float x, float y, float z) { Mat4 r=identity(); r.m[12]=x; r.m[13]=y; r.m[14]=z; return r; }
    static Mat4 rotY(float a) { Mat4 r=identity(); r.m[0]=cos(a); r.m[2]=-sin(a); r.m[8]=sin(a); r.m[10]=cos(a); return r; }
    static Mat4 rotX(float a) { Mat4 r=identity(); r.m[5]=cos(a); r.m[6]=sin(a); r.m[9]=-sin(a); r.m[10]=cos(a); return r; }
    static Mat4 rotZ(float a) { Mat4 r=identity(); r.m[0]=cos(a); r.m[1]=sin(a); r.m[4]=-sin(a); r.m[5]=cos(a); return r; }
};

float getTerrainHeight(float x, float z) {
    return sin(x * 0.4f) * cos(z * 0.4f) * 1.5f;
}

GLuint prog, vaoTorso, vaoHead, vaoUpLimb, vaoLowLimb, vaoSword, vaoShield, vaoTree, vaoChest, vaoCloud, vaoTerrain;
float px=0, py=0, pz=0, pf=0, wt=0, st=0;
float vy = 0.0f; // Vertical Velocity
bool isGrounded = true;
int comboState = 0; 
volatile bool block=false;
volatile bool shieldBash=false;
Mat4 proj;
auto lastTime = std::chrono::steady_clock::now();

GLuint createVAO(const float* d, int n) {
    GLuint vao, vbo; glGenVertexArrays(1,&vao); glGenBuffers(1,&vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER,vbo); glBufferData(GL_ARRAY_BUFFER, n*24, d, GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,0,24,0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1,3,GL_FLOAT,0,24,(void*)12); glEnableVertexAttribArray(1);
    return vao;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        const char* vS = "#version 300 es\nlayout(location=0) in vec3 p; layout(location=1) in vec3 c; uniform mat4 m,v,pr; uniform float isT; out vec3 vc; out vec4 viewPos; void main(){ vec4 w=m*vec4(p,1.0); if(isT>0.5) w.y += sin(w.x*0.4)*cos(w.z*0.4)*1.5; viewPos=v*w; gl_Position=pr*viewPos; vc=c; }";
        const char* fS = "#version 300 es\nprecision mediump float; in vec3 vc; in vec4 viewPos; out vec4 o; void main(){ float dist=length(viewPos.xyz); float fog=clamp((dist-20.0)/80.0, 0.0, 1.0); vec3 sky=vec3(0.5,0.7,0.9); o=vec4(mix(vc,sky,fog), 1.0); }";
        
        GLuint vs=glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs,1,&vS,0); glCompileShader(vs);
        GLuint fs=glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs,1,&fS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog); glUseProgram(prog);
        glEnable(GL_DEPTH_TEST); glEnable(GL_CULL_FACE);
        
        vaoTorso=createVAO(M_TORSO, N_TORSO); vaoHead=createVAO(M_HEAD, N_HEAD);
        vaoUpLimb=createVAO(M_UP_LIMB, N_UP_LIMB); vaoLowLimb=createVAO(M_LOW_LIMB, N_LOW_LIMB);
        vaoSword=createVAO(M_SWORD, N_SWORD); vaoShield=createVAO(M_SHIELD, N_SHIELD);
        vaoTree=createVAO(M_TREE, N_TREE); vaoChest=createVAO(M_CHEST, N_CHEST);
        vaoCloud=createVAO(M_CLOUD, N_CLOUD); vaoTerrain=createVAO(M_TERRAIN, N_TERRAIN);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) {
        glViewport(0,0,w,h); proj=Mat4::perspective(1.0f, (float)w/h, 0.1f, 300.0f);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch, jfloat zoom) {
        auto currentTime = std::chrono::steady_clock::now();
        float dt = std::chrono::duration<float>(currentTime - lastTime).count();
        lastTime = currentTime;
        static float globalTime = 0; globalTime += dt;

        float speed = 0.0f;
        if(fabs(ix)>0.05f || fabs(iy)>0.05f) {
            float s=sin(yaw), c=cos(yaw);
            float dx=ix*c - (-iy)*s; 
            float dz=ix*s + (-iy)*c;
            px+=dx*6.0f*dt; pz-=dz*6.0f*dt; 
            
            // FIXED ROTATION: Atan2 logic aligned with actual movement vector
            pf=atan2(dx, dz); 
            wt+=15.0f*dt; speed = 1.0f;
        } else { wt = 0; }

        // JUMP PHYSICS & GRAVITY
        float groundY = getTerrainHeight(px, pz);
        py += vy * dt;
        vy -= 20.0f * dt; // Gravity
        
        if (py <= groundY) {
            py = groundY;
            vy = 0.0f;
            isGrounded = true;
        }

        // SWORD/SHIELD ANIMATION PROGRESS
        if(comboState > 0 || shieldBash) { 
            st += 12.0f * dt; 
            if(st > 3.14f) { comboState = 0; shieldBash = false; st = 0; } 
        }

        glClearColor(0.5f, 0.7f, 0.9f, 1.0f); 
        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT); 
        GLint lp=glGetUniformLocation(prog,"pr"), lv=glGetUniformLocation(prog,"v"), lm=glGetUniformLocation(prog,"m"), lt=glGetUniformLocation(prog,"isT");
        glUniformMatrix4fv(lp,1,0,proj.m);
        
        float hipHeight = py + 0.8f + (sin(wt*2.0f)*0.05f * speed);
        Mat4 v=Mat4::trans(0,0,-zoom).mul(Mat4::rotX(-pitch)).mul(Mat4::rotY(-yaw)).mul(Mat4::trans(-px,-(hipHeight+0.5f),-pz));
        glUniformMatrix4fv(lv,1,0,v.m);
        
        glUniform1f(lt, 1.0f); // Terrain pass
        for(int i=-6; i<=6; i++) for(int j=-6; j<=6; j++) {
            float tx=floor(px/16.f)*16.f+i*16.f, tz=floor(pz/16.f)*16.f+j*16.f;
            Mat4 tm=Mat4::trans(tx,0,tz); glUniformMatrix4fv(lm,1,0,tm.m);
            glBindVertexArray(vaoTerrain); glDrawArrays(GL_TRIANGLES,0,N_TERRAIN);
        }
        
        glUniform1f(lt, 0.0f); // Objects pass
        for(int i=-4; i<=4; i++) for(int j=-4; j<=4; j++) {
            float tx=floor(px/16.f)*16.f+i*16.f, tz=floor(pz/16.f)*16.f+j*16.f;
            float seed = fmod(tx*1.2f+tz*0.8f, 6.f);
            if(seed > 4.8f) {
                Mat4 tm=Mat4::trans(tx,getTerrainHeight(tx, tz),tz); glUniformMatrix4fv(lm,1,0,tm.m);
                glBindVertexArray(vaoTree); glDrawArrays(GL_TRIANGLES,0,N_TREE);
            } else if (seed > 4.5f && seed < 4.6f) {
                Mat4 cm=Mat4::trans(tx,getTerrainHeight(tx, tz),tz); glUniformMatrix4fv(lm,1,0,cm.m);
                glBindVertexArray(vaoChest); glDrawArrays(GL_TRIANGLES,0,N_CHEST);
            }
        }
        
        // Clouds Render Layer
        glBindVertexArray(vaoCloud);
        for(int c=0; c<10; c++) {
            float cx = fmod(c * 30.0f + globalTime * 2.0f, 200.0f) - 100.0f + px;
            float cz = (c * 15.0f) - 50.0f + pz;
            Mat4 clm = Mat4::trans(cx, 40.0f, cz); glUniformMatrix4fv(lm,1,0,clm.m);
            glDrawArrays(GL_TRIANGLES,0,N_CLOUD);
        }
        
        // --- HIERARCHICAL KINEMATIC BINDINGS ---
        Mat4 root = Mat4::trans(px, hipHeight, pz).mul(Mat4::rotY(pf));
        
        glUniformMatrix4fv(lm,1,0,root.m); glBindVertexArray(vaoTorso); glDrawArrays(GL_TRIANGLES,0,N_TORSO);
        Mat4 head = root.mul(Mat4::trans(0,0.7f,0));
        glUniformMatrix4fv(lm,1,0,head.m); glBindVertexArray(vaoHead); glDrawArrays(GL_TRIANGLES,0,N_HEAD);

        // Legs (Jump stretches them, walk swings them)
        float swingL = isGrounded ? sin(wt) * 0.8f * speed : 0.2f; 
        float swingR = isGrounded ? sin(wt + 3.1415f) * 0.8f * speed : -0.2f;
        
        Mat4 hipL = root.mul(Mat4::trans(0.18f,0,0)).mul(Mat4::rotX(swingL));
        glUniformMatrix4fv(lm,1,0,hipL.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
        Mat4 kneeL = hipL.mul(Mat4::trans(0,-0.4f,0)).mul(Mat4::rotX(swingL > 0 ? swingL : 0));
        glUniformMatrix4fv(lm,1,0,kneeL.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);
        
        Mat4 hipR = root.mul(Mat4::trans(-0.18f,0,0)).mul(Mat4::rotX(swingR));
        glUniformMatrix4fv(lm,1,0,hipR.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
        Mat4 kneeR = hipR.mul(Mat4::trans(0,-0.4f,0)).mul(Mat4::rotX(swingR > 0 ? swingR : 0));
        glUniformMatrix4fv(lm,1,0,kneeR.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);

        // Arms & Combat
        float armL = -swingL * 0.6f; float armR = -swingR * 0.6f;
        Mat4 shL = root.mul(Mat4::trans(-0.35f,0.5f,0));
        
        if(shieldBash) shL = shL.mul(Mat4::rotX(-1.5f)).mul(Mat4::trans(0,0,sin(st)*0.5f)); // Thrust forward
        else if (block) shL = shL.mul(Mat4::rotX(-1.5f)); // Hold block
        else shL = shL.mul(Mat4::rotX(armL)); // Regular swing
        
        Mat4 elbL = shL.mul(Mat4::trans(0,-0.4f,0)).mul(Mat4::rotX((block || shieldBash) ? -1.0f : -0.2f));
        
        Mat4 shR = root.mul(Mat4::trans(0.35f,0.5f,0));
        // FIXED SWORD ARCS: Swings gracefully across the body
        if(comboState == 1) shR = shR.mul(Mat4::rotY(-sin(st)*2.0f)).mul(Mat4::rotX(-1.5f));
        else if(comboState == 2) shR = shR.mul(Mat4::rotY(sin(st)*2.0f)).mul(Mat4::rotX(-1.5f));
        else if(comboState == 3) shR = shR.mul(Mat4::rotX(-sin(st)*3.0f));
        else shR = shR.mul(Mat4::rotX(armR));
        Mat4 elbR = shR.mul(Mat4::trans(0,-0.4f,0)).mul(Mat4::rotX(-0.2f));

        glUniformMatrix4fv(lm,1,0,shL.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
        glUniformMatrix4fv(lm,1,0,elbL.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);
        glUniformMatrix4fv(lm,1,0,shR.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
        glUniformMatrix4fv(lm,1,0,elbR.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);
        
        // FIXED SHIELD: Attaches firmly to forearm facing outward
        Mat4 shield = elbL.mul(Mat4::trans(-0.15f,-0.2f,0.0f)).mul(Mat4::rotZ(1.57f)).mul(Mat4::rotX(1.57f));
        glUniformMatrix4fv(lm,1,0,shield.m); glBindVertexArray(vaoShield); glDrawArrays(GL_TRIANGLES,0,N_SHIELD);
        
        Mat4 sword = elbR.mul(Mat4::trans(0,-0.4f,0.0f)).mul(Mat4::rotX(1.57f));
        glUniformMatrix4fv(lm,1,0,sword.m); glBindVertexArray(vaoSword); glDrawArrays(GL_TRIANGLES,0,N_SWORD);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) { if(comboState == 0 || st > 2.0f) { comboState++; if(comboState > 3) comboState = 1; st = 0; } } 
        else if(id==2) block=true; 
        else if(id==3) block=false;
        else if(id==4) { if(isGrounded) { vy = 9.0f; isGrounded = false; } } // JUMP
        else if(id==6) { shieldBash = true; st = 0; } // SHIELD BASH
    }
}
EOF
