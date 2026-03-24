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
GLuint vaoHead, vaoBody, vaoLimb;
GLint uMVP, uModel, uSunDir, uViewPos;
int screenW=1, screenH=1;

GLuint createVAO(const float* data, int count) {
    GLuint vao, vbo;
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, count * 9 * sizeof(float), data, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 9*sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 9*sizeof(float), (void*)(3*sizeof(float)));
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 9*sizeof(float), (void*)(6*sizeof(float)));
    glEnableVertexAttribArray(2);
    return vao;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onCreated(JNIEnv* env, jclass clz) {
        GLuint vs = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vs, 1, &WORLD_VS, NULL); glCompileShader(vs);
        GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(fs, 1, &WORLD_FS, NULL); glCompileShader(fs);
        prog = glCreateProgram();
        glAttachShader(prog, vs); glAttachShader(prog, fs);
        glLinkProgram(prog);

        uMVP = glGetUniformLocation(prog, "uMVP");
        uModel = glGetUniformLocation(prog, "uModel");
        uSunDir = glGetUniformLocation(prog, "uSunDir");
        uViewPos = glGetUniformLocation(prog, "uViewPos");

        vaoHead = createVAO(M_HEAD, N_HEAD);
        vaoBody = createVAO(M_BODY, N_BODY);
        vaoLimb = createVAO(M_LIMB, N_LIMB);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onDraw(JNIEnv* env, jclass clz, 
        float jX, float jY, float yaw, float pitch) {
        
        glClearColor(0.7f, 0.8f, 0.9f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST);
        glUseProgram(prog);

        glm::vec3 camPos = glm::vec3(10.0f * cos(pitch) * sin(yaw), 10.0f * sin(pitch), 10.0f * cos(pitch) * cos(yaw));
        glm::mat4 view = glm::lookAt(camPos, glm::vec3(0, 1.0f, 0), glm::vec3(0, 1, 0));
        glm::mat4 proj = glm::perspective(glm::radians(45.0f), (float)screenW/screenH, 0.1f, 100.0f);

        glUniform3f(uSunDir, 1.0f, 1.0f, 1.0f);
        glUniform3f(uViewPos, camPos.x, camPos.y, camPos.z);

        auto draw = [&](GLuint vao, int n, glm::mat4 m) {
            glUniformMatrix4fv(uModel, 1, GL_FALSE, glm::value_ptr(m));
            glUniformMatrix4fv(uMVP, 1, GL_FALSE, glm::value_ptr(proj * view * m));
            glBindVertexArray(vao);
            glDrawArrays(GL_TRIANGLE_STRIP, 0, n);
        };

        draw(vaoBody, N_BODY, glm::translate(glm::mat4(1.0f), {0, 0.5, 0}));
        draw(vaoHead, N_HEAD, glm::translate(glm::mat4(1.0f), {0, 1.6, 0}));
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onChanged(JNIEnv* env, jclass clz, int w, int h) {
        screenW = w; screenH = h; glViewport(0, 0, w, h);
    }
}
EOF
