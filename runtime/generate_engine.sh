#!/bin/bash
# File: runtime/generate_engine.sh
OUT="app/src/main/cpp/native-lib.cpp"
cat <<EOF > $OUT
#include <jni.h>
#include <GLES3/gl3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <math.h>
#include "models/AllModels.h"
#include "shaders/Shaders.h"

GLuint prog, vH, vB, vL, vS, vSh;
GLint uMVP, uMod, uSun, uView;
int sw=1, sh=1;

// Physics and Animation State
float pX=0, pZ=0, vY=0, animTime=0, attackSwing=0;
bool grounded = true;

GLuint mkVAO(const float* d, int c) {
    GLuint v, b; glGenVertexArrays(1, &v); glGenBuffers(1, &b);
    glBindVertexArray(v); glBindBuffer(GL_ARRAY_BUFFER, b);
    glBufferData(GL_ARRAY_BUFFER, c*9*sizeof(float), d, GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,0,36,0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1,3,GL_FLOAT,0,36,(void*)12); glEnableVertexAttribArray(1);
    glVertexAttribPointer(2,3,GL_FLOAT,0,36,(void*)24); glEnableVertexAttribArray(2);
    return v;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onCreated(JNIEnv* e, jclass c) {
        GLuint vs=glCreateShader(GL_VERTEX_SHADER), fs=glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(vs,1,&WORLD_VS,0); glCompileShader(vs);
        glShaderSource(fs,1,&WORLD_FS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog);
        
        uMVP=glGetUniformLocation(prog,"uMVP"); uMod=glGetUniformLocation(prog,"uModel");
        uSun=glGetUniformLocation(prog,"uSunDir"); uView=glGetUniformLocation(prog,"uViewPos");
        
        vH=mkVAO(M_HEAD,N_HEAD); vB=mkVAO(M_BODY,N_BODY); vL=mkVAO(M_LIMB,N_LIMB);
        vS=mkVAO(M_SWORD,N_SWORD); vSh=mkVAO(M_SHIELD,N_SHIELD);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onDraw(JNIEnv* e, jclass c, float jX, float jY, float yaw, float pitch, jboolean jump, jboolean atk) {
        
        // 1. Actions & Physics
        if(jump && grounded) { vY = 0.35f; grounded = false; }
        if(!grounded) { vY -= 0.02f; } // Gravity
        float pY = (grounded) ? 0.0f : (vY > -1.0f ? vY : -1.0f);
        if(pY <= 0) { pY=0; grounded=true; vY=0; }
        
        if(atk) { attackSwing = 3.14f; } // Trigger Sword Swing Arc
        if(attackSwing > 0) attackSwing -= 0.25f; else attackSwing = 0;

        // 2. Thumbstick Movement
        float speed = 0.15f;
        pX += (jX * cos(yaw) + jY * sin(yaw)) * speed;
        pZ += (jY * cos(yaw) - jX * sin(yaw)) * speed;
        
        if(abs(jX)>0.1 || abs(jY)>0.1) animTime += 0.2f; else animTime = 0;

        // 3. Render Setup
        glClearColor(0.7f, 0.85f, 0.95f, 1.0f); glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST); glUseProgram(prog);

        glm::vec3 cp = glm::vec3(12.0f*cos(pitch)*sin(yaw)+pX, 8.0f+pY, 12.0f*cos(pitch)*cos(yaw)+pZ);
        glm::mat4 v = glm::lookAt(cp, {pX, 1.5f+pY, pZ}, {0,1,0});
        glm::mat4 pr = glm::perspective(0.8f, (float)sw/sh, 0.1f, 100.0f);
        glUniform3f(uSun, 1.0f, 2.0f, 1.0f); glUniform3f(uView, cp.x, cp.y, cp.z);

        auto dr = [&](GLuint vao, int n, glm::mat4 m) {
            glUniformMatrix4fv(uMod, 1, 0, glm::value_ptr(m));
            glUniformMatrix4fv(uMVP, 1, 0, glm::value_ptr(pr*v*m));
            glBindVertexArray(vao); glDrawArrays(GL_TRIANGLES, 0, n);
        };

        // 4. Character Assembly with Animations
        glm::mat4 root = glm::translate(glm::mat4(1), {pX, pY, pZ});
        dr(vB, N_BODY, glm::translate(root, {0, 1.2, 0})); // Body
        dr(vH, N_HEAD, glm::translate(root, {0, 2.2, 0})); // Head

        // Walk Cycle (Sine wave based on thumbstick input)
        float walkSwing = sin(animTime) * 0.5f;
        
        // Left Arm (Shield)
        glm::mat4 lArm = glm::translate(root, {-0.5, 1.5, walkSwing}) * glm::rotate(glm::mat4(1), walkSwing, {1,0,0});
        dr(vL, N_LIMB, lArm);
        dr(vSh, N_SHIELD, glm::translate(lArm, {-0.2, 0.0, 0.2})); 

        // Right Arm (Sword + Attack Animation)
        float rightArmRot = -walkSwing - (sin(attackSwing) * 2.0f); // Combine walk and attack arcs
        glm::mat4 rArm = glm::translate(root, {0.5, 1.5, -walkSwing}) * glm::rotate(glm::mat4(1), rightArmRot, {1,0,0});
        dr(vL, N_LIMB, rArm);
        dr(vS, N_SWORD, glm::translate(rArm, {0.1, -0.4, 0.5}) * glm::rotate(glm::mat4(1), 1.57f, {1,0,0})); 
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onChanged(JNIEnv* e, jclass c, int w, int h) {
        sw=w; sh=h; glViewport(0,0,w,h);
    }
}
EOF
