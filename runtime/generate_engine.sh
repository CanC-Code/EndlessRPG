#!/bin/bash
# File: runtime/generate_engine.sh
# EndlessRPG v6 - High-Fidelity Native Engine with Atmospheric Pipeline
set -e

OUT="app/src/main/cpp/native-lib.cpp"
mkdir -p app/src/main/cpp

cat <<EOF > $OUT
#include <jni.h>
#include <GLES3/gl3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <vector>
#include "models/AllModels.h"
#include "shaders/Shaders.h"

// --- Global Engine State ---
GLuint worldProgram;
GLuint vaoHead, vaoTorso, vaoUpLimb, vaoLowLimb, vaoHand, vaoFoot;
GLuint vaoTree, vaoRock, vaoSword, vaoShield;

GLint uMVP, uModel, uSunDir, uViewPos, uFogColor;

int screenW = 1, screenH = 1;
float camZoom = 12.0f;

// --- Helper: Create VAO for 9-float Vertex Format (Pos, Col, Norm) ---
GLuint makeVAO9(const float* data, int vertexCount) {
    GLuint vao, vbo;
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, vertexCount * 9 * sizeof(float), data, GL_STATIC_DRAW);

    // Attribute 0: Position (3f)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 9 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    
    // Attribute 1: Color (3f)
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 9 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);
    
    // Attribute 2: Normal (3f)
    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 9 * sizeof(float), (void*)(6 * sizeof(float)));
    glEnableVertexAttribArray(2);
    
    return vao;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onCreated(JNIEnv* env, jclass clz) {
        [span_0](start_span)// Compile Shaders from generated Shaders.h[span_0](end_span)
        GLuint vs = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vs, 1, &WORLD_VS, NULL); glCompileShader(vs);
        GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(fs, 1, &WORLD_FS, NULL); glCompileShader(fs);
        
        worldProgram = glCreateProgram();
        glAttachShader(worldProgram, vs);
        glAttachShader(worldProgram, fs);
        glLinkProgram(worldProgram);

        [span_1](start_span)[span_2](start_span)// Map Uniforms[span_1](end_span)[span_2](end_span)
        uMVP      = glGetUniformLocation(worldProgram, "uMVP");
        uModel    = glGetUniformLocation(worldProgram, "uModel");
        uSunDir   = glGetUniformLocation(worldProgram, "uSunDir");
        uViewPos  = glGetUniformLocation(worldProgram, "uViewPos");
        uFogColor = glGetUniformLocation(worldProgram, "uFogColor");

        [span_3](start_span)// Initialize VAOs with 9-float logic (Pos, Col, Norm)[span_3](end_span)
        vaoHead    = makeVAO9(M_HEAD, N_HEAD);
        vaoTorso   = makeVAO9(M_TORSO, N_TORSO);
        vaoUpLimb  = makeVAO9(M_UP_LIMB, N_UP_LIMB);
        vaoLowLimb = makeVAO9(M_LOW_LIMB, N_LOW_LIMB);
        vaoHand    = makeVAO9(M_HAND, N_HAND);
        vaoFoot    = makeVAO9(M_FOOT, N_FOOT);
        
        vaoTree    = makeVAO9(M_TREE, N_TREE);
        vaoRock    = makeVAO9(M_ROCK, N_ROCK);
        vaoSword   = makeVAO9(M_SWORD, N_SWORD);
        vaoShield  = makeVAO9(M_SHIELD, N_SHIELD);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onDraw(JNIEnv* env, jclass clz, 
        jfloat joyX, jfloat joyY, jfloat yaw, jfloat pitch) {
        
        [span_4](start_span)// Atmosphere Setup[span_4](end_span)
        glClearColor(0.7f, 0.85f, 0.95f, 1.0f); // Sky Blue Fog
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST);
        glUseProgram(worldProgram);

        [span_5](start_span)// Camera Logic (Matches skyline perspective)[span_5](end_span)
        glm::vec3 camPos = glm::vec3(
            camZoom * cos(pitch) * sin(yaw),
            camZoom * sin(pitch),
            camZoom * cos(pitch) * cos(yaw)
        );
        glm::mat4 view = glm::lookAt(camPos, glm::vec3(0, 1.0f, 0), glm::vec3(0, 1, 0));
        glm::mat4 proj = glm::perspective(glm::radians(45.0f), (float)screenW/screenH, 0.1f, 200.0f);
        
        [span_6](start_span)// Lighting & Fog Uniforms[span_6](end_span)
        glUniform3f(uSunDir, 1.0f, 2.0f, 1.0f); 
        glUniform3f(uViewPos, camPos.x, camPos.y, camPos.z);
        glUniform3f(uFogColor, 0.7f, 0.85f, 0.95f);

        // --- Character Assembly Rendering ---
        auto drawPart = [&](GLuint vao, int count, glm::mat4 m) {
            glUniformMatrix4fv(uModel, 1, GL_FALSE, glm::value_ptr(m));
            glUniformMatrix4fv(uMVP, 1, GL_FALSE, glm::value_ptr(proj * view * m));
            glBindVertexArray(vao);
            glDrawArrays(GL_TRIANGLES, 0, count);
        };

        glm::mat4 base = glm::mat4(1.0f);
        drawPart(vaoTorso, N_TORSO, glm::translate(base, {0, 1.2, 0}));
        drawPart(vaoHead,  N_HEAD,  glm::translate(base, {0, 2.0, 0}));
        
        // Limbs (L/R)
        for(float side : {-0.55f, 0.55f}) {
            drawPart(vaoUpLimb, N_UP_LIMB, glm::translate(base, {side, 1.5, 0}));
            drawPart(vaoLowLimb, N_LOW_LIMB, glm::translate(base, {side * 0.8f, 0.6, 0}));
        }

        // --- Environment Props ---
        drawPart(vaoTree, N_TREE, glm::translate(base, {-4, 2, -4}));
        drawPart(vaoRock, N_ROCK, glm::translate(base, {3, 0.4, 2}));
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onChanged(JNIEnv* env, jclass clz, jint w, jint h) {
        screenW = w; screenH = h;
        glViewport(0, 0, w, h);
    }
}
EOF

echo "[generate_engine.sh] Success: native-lib.cpp updated with High-Fidelity Fog & Lighting."
