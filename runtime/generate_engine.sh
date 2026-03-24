#!/bin/bash
# File: runtime/generate_engine.sh
OUT="app/src/main/cpp/native-lib.cpp"
cat <<EOF > $OUT
#include <jni.h>
#include <GLES3/gl3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include "models/AllModels.h"
#include "shaders/Shaders.h"

GLuint prog;
GLuint vaoH, vaoB, vaoL;
GLint uMVP, uModel, uSun, uView;
int sw=1, sh=1;

GLuint mkVAO(const float* d, int c) {
    GLuint v, b;
    glGenVertexArrays(1, &v); glGenBuffers(1, &b);
    glBindVertexArray(v); glBindBuffer(GL_ARRAY_BUFFER, b);
    glBufferData(GL_ARRAY_BUFFER, c * 9 * sizeof(float), d, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, 0, 36, (void*)0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, 0, 36, (void*)12); glEnableVertexAttribArray(1);
    glVertexAttribPointer(2, 3, GL_FLOAT, 0, 36, (void*)24); glEnableVertexAttribArray(2);
    return v;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onCreated(JNIEnv* e, jclass c) {
        GLuint vs = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vs, 1, &WORLD_VS, 0); glCompileShader(vs);
        GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(fs, 1, &WORLD_FS, 0); glCompileShader(fs);
        prog = glCreateProgram(); glAttachShader(prog, vs); glAttachShader(prog, fs); glLinkProgram(prog);
        uMVP = glGetUniformLocation(prog, "uMVP"); uModel = glGetUniformLocation(prog, "uModel");
        uSun = glGetUniformLocation(prog, "uSunDir"); uView = glGetUniformLocation(prog, "uViewPos");
        vaoH = mkVAO(M_HEAD, N_HEAD); vaoB = mkVAO(M_BODY, N_BODY); vaoL = mkVAO(M_LIMB, N_LIMB);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onDraw(JNIEnv* e, jclass c, float jX, float jY, float y, float p) {
        glClearColor(0.7f, 0.85f, 0.95f, 1.0f); glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST); glUseProgram(prog);
        glm::vec3 cp = glm::vec3(12.0f*cos(p)*sin(y), 12.0f*sin(p), 12.0f*cos(p)*cos(y));
        glm::mat4 v = glm::lookAt(cp, {0,1,0}, {0,1,0});
        glm::mat4 pr = glm::perspective(0.8f, (float)sw/sh, 0.1f, 100.0f);
        glUniform3f(uSun, 1, 2, 1); glUniform3f(uView, cp.x, cp.y, cp.z);
        auto dr = [&](GLuint vao, int n, glm::mat4 m) {
            glUniformMatrix4fv(uModel, 1, 0, glm::value_ptr(m));
            glUniformMatrix4fv(uMVP, 1, 0, glm::value_ptr(pr*v*m));
            glBindVertexArray(vao); glDrawArrays(GL_TRIANGLES, 0, n);
        };
        dr(vaoB, N_BODY, glm::translate(glm::mat4(1), {0, 0.8, 0}));
        dr(vaoH, N_HEAD, glm::translate(glm::mat4(1), {0, 1.8, 0}));
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onChanged(JNIEnv* e, jclass c, int w, int h) {
        sw=w; sh=h; glViewport(0,0,w,h);
    }
}
EOF
