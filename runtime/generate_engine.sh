#!/bin/bash
# File: runtime/generate_engine.sh

cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(game_engine SHARED native-lib.cpp)
target_link_libraries(game_engine GLESv3 log)
EOF

cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <android/log.h>
#include "models/GeneratedModels.h"

float pX=0, pZ=0, vY=0, animTime=0, attackSwing=0;
bool grounded = true;

const char* VS = R"(#version 300 es
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aCol;
uniform mat4 uMVP, uModel;
out vec3 vCol; 
out vec3 vFragPos;
void main() {
    vFragPos = vec3(uModel * vec4(aPos, 1.0));
    // Voxel Grass & Mud Pattern
    vec3 grassCol = vec3(0.18, 0.48, 0.18);
    vec3 mudCol = vec3(0.35, 0.25, 0.15);
    vec3 col = mix(mudCol, grassCol, aCol.g);
    vCol = aCol;
    gl_Position = uMVP * vec4(aPos, 1.0);
})";

const char* FS = R"(#version 300 es
precision mediump float;
in vec3 vCol;
out vec4 fragColor;
void main() {
    fragColor = vec4(vCol, 1.0);
})";

GLuint prog, uMVP, uMod, vHero, vSword, vTree;

struct Mat4 {
    float m[16] = {0};
    static Mat4 identity() { Mat4 r; r.m[0]=1; r.m[5]=1; r.m[10]=1; r.m[15]=1; return r; }
    static Mat4 trans(float x, float y, float z) { Mat4 r=identity(); r.m[12]=x; r.m[13]=y; r.m[14]=z; return r; }
    static Mat4 rotX(float a) { Mat4 r=identity(); float c=cos(a), s=sin(a); r.m[5]=c; r.m[6]=s; r.m[9]=-s; r.m[10]=c; return r; }
    static Mat4 rotY(float a) { Mat4 r=identity(); float c=cos(a), s=sin(a); r.m[0]=c; r.m[2]=-s; r.m[8]=s; r.m[10]=c; return r; }
    Mat4 mul(Mat4 o) {
        Mat4 r;
        for(int i=0; i<4; i++) for(int j=0; j<4; j++)
            for(int k=0; k<4; k++) r.m[i*4+j] += m[k*4+j] * o.m[i*4+k];
        return r;
    }
};

Mat4 pr;

GLuint mkVAO(const float* d, int c) {
    GLuint v, b; glGenVertexArrays(1, &v); glGenBuffers(1, &b);
    glBindVertexArray(v); glBindBuffer(GL_ARRAY_BUFFER, b);
    glBufferData(GL_ARRAY_BUFFER, c*6*sizeof(float), d, GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,0,24,0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1,3,GL_FLOAT,0,24,(void*)12); glEnableVertexAttribArray(1);
    return v;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onCreated(JNIEnv*, jclass) {
        GLuint vs=glCreateShader(GL_VERTEX_SHADER), fs=glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(vs,1,&VS,0); glCompileShader(vs);
        glShaderSource(fs,1,&FS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog);
        uMVP=glGetUniformLocation(prog,"uMVP"); uMod=glGetUniformLocation(prog,"uModel");
        vHero = mkVAO(M_HERO, N_HERO); vSword = mkVAO(M_SWORD, N_SWORD); vTree = mkVAO(M_TREE, N_TREE);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onChanged(JNIEnv*, jclass, int w, int h) {
        glViewport(0,0,w,h);
        float a = (float)w/h;
        float f=1.0f/tan(0.8f/2.0f);
        pr=Mat4::identity(); pr.m[0]=f/a; pr.m[5]=f; pr.m[10]=(100.0f+0.1f)/(0.1f-100.0f); pr.m[11]=-1; pr.m[14]=(2*100.0f*0.1f)/(0.1f-100.0f); pr.m[15]=0;
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onDraw(JNIEnv*, jclass, float jX, float jY, float yaw, float pitch, jboolean jump, jboolean atk) {
        // Physics & Animation
        if(jump && grounded) { vY = 0.35f; grounded = false; }
        if(!grounded) { vY -= 0.02f; }
        float pY = (grounded) ? 0.0f : (vY > -1.0f ? vY : -1.0f);
        if(pY <= 0) { pY=0; grounded=true; vY=0; }
        
        if(atk) { attackSwing = 3.14f; } // Swing Arc
        if(attackSwing > 0) attackSwing -= 0.25f; else attackSwing = 0;
        
        float speed = 0.15f;
        pX += (jX * cos(yaw) + jY * sin(yaw)) * speed;
        pZ += (jY * cos(yaw) - jX * sin(yaw)) * speed;
        if(fabs(jX)>0.1 || fabs(jY)>0.1) animTime += 0.2f; else animTime = 0;

        glClearColor(0.5f, 0.7f, 1.0f, 1.0f); 
        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST); glUseProgram(prog);

        // Orbital Math 
        float zoom = 12.0f;
        Mat4 view = Mat4::trans(0,0,-zoom).mul(Mat4::rotX(-pitch)).mul(Mat4::rotY(-yaw)).mul(Mat4::trans(-pX,-1.5f-pY,-pZ));

        auto draw = [&](GLuint vao, int n, Mat4 m) {
            glUniformMatrix4fv(uMod, 1, GL_FALSE, m.m);
            Mat4 mvp = pr.mul(view.mul(m));
            glUniformMatrix4fv(uMVP, 1, GL_FALSE, mvp.m);
            glBindVertexArray(vao); glDrawArrays(GL_TRIANGLES, 0, n);
        };

        // Draw Player
        Mat4 mHero = Mat4::trans(pX, pY, pZ);
        draw(vHero, N_HERO, mHero);

        // Draw Sword (Animated Swing Arc)
        float walkSwing = sin(animTime) * 0.5f;
        Mat4 mSword = mHero.mul(Mat4::trans(0.5f, 1.5f, -walkSwing)).mul(Mat4::rotX(-walkSwing - (sin(attackSwing) * 2.0f)));
        draw(vSword, N_SWORD, mSword);
        
        // RENDER TREES
        for(int i=-2; i<=2; i++) {
            for(int j=-2; j<=2; j++) {
                float tx=floor(pX/16.f)*16.f+i*16.f;
                float tz=floor(pZ/16.f)*16.f+j*16.f;
                draw(vTree, N_TREE, Mat4::trans(tx, 0, tz));
            }
        }
    }
}
EOF
