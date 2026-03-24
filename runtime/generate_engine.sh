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
GLint uMVP, uMod, uSun, uView, uFog;
int sw=1, sh=1;
float pX=0, pZ=0, vY=0, anim=0;
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
        uFog=glGetUniformLocation(prog,"uFogColor");
        vH=mkVAO(M_HEAD,N_HEAD); vB=mkVAO(M_BODY,N_BODY); vL=mkVAO(M_LIMB,N_LIMB);
        vS=mkVAO(M_SWORD,N_SWORD); vSh=mkVAO(M_SHIELD,N_SHIELD);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onDraw(JNIEnv* e, jclass c, float jX, float jY, float yaw, float pitch, bool jump, bool atk) {
        // Physics & Animation Logic
        if(jump && grounded) { vY = 0.25f; grounded = false; }
        if(!grounded) { vY -= 0.015f; }
        float pY = (grounded) ? 0.0f : (vY > -1.0f ? vY : -1.0f); // Simple Floor
        if(pY < 0) { pY=0; grounded=true; vY=0; }
        
        float speed = 0.15f;
        pX += (jX * cos(yaw) + jY * sin(yaw)) * speed;
        pZ += (jY * cos(yaw) - jX * sin(yaw)) * speed;
        if(abs(jX)>0.1 || abs(jY)>0.1) anim += 0.2f; else anim = 0;

        glClearColor(0.7f, 0.85f, 0.95f, 1.0f); glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST); glUseProgram(prog);

        glm::vec3 cp = glm::vec3(12.0f*cos(pitch)*sin(yaw)+pX, 8.0f+pY, 12.0f*cos(pitch)*cos(yaw)+pZ);
        glm::mat4 v = glm::lookAt(cp, {pX, 1.5f+pY, pZ}, {0,1,0});
        glm::mat4 pr = glm::perspective(0.8f, (float)sw/sh, 0.1f, 100.0f);
        glUniform3f(uSun, 1, 2, 1); glUniform3f(uView, cp.x, cp.y, cp.z);
        glUniform3f(uFog, 0.7f, 0.85f, 0.95f);

        auto dr = [&](GLuint vao, int n, glm::mat4 m) {
            glUniformMatrix4fv(uMod, 1, 0, glm::value_ptr(m));
            glUniformMatrix4fv(uMVP, 1, 0, glm::value_ptr(pr*v*m));
            glBindVertexArray(vao); glDrawArrays(GL_TRIANGLES, 0, n);
        };

        glm::mat4 root = glm::translate(glm::mat4(1), {pX, pY, pZ});
        dr(vB, N_BODY, glm::translate(root, {0, 1.2, 0}));
        dr(vH, N_HEAD, glm::translate(root, {0, 2.2, 0}));

        // Limb Animation (Sine-based walk cycle)
        float swing = sin(anim) * 0.5f;
        dr(vL, N_LIMB, glm::translate(root, {-0.5, 1.5, swing}) * glm::rotate(glm::mat4(1), swing, {1,0,0})); // Left Arm
        dr(vL, N_LIMB, glm::translate(root, { 0.5, 1.5, -swing}) * glm::rotate(glm::mat4(1), -swing, {1,0,0})); // Right Arm
        
        // Sword (Attached to Hand)
        dr(vS, N_SWORD, glm::translate(root, {0.6, 1.2, -swing}) * glm::rotate(glm::mat4(1), 1.5f, {1,0,0}));
        // Shield (Attached to Arm)
        dr(vSh, N_SHIELD, glm::translate(root, {-0.7, 1.5, swing}));
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onChanged(JNIEnv* e, jclass c, int w, int h) {
        sw=w; sh=h; glViewport(0,0,w,h);
    }
}
EOF
