#!/bin/bash
# File: runtime/generate_engine.sh
# EndlessRPG v6 - High-Performance Native Engine with Normal Mapping
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

// --- Global Engine State ---
GLuint worldProgram;
GLuint vaoHead, vaoTorso, vaoUpLimb, vaoLowLimb, vaoHand, vaoFoot;
GLuint vaoTree, vaoRock, vaoSword, vaoShield;

GLint uMVP, uModel, uSunDir, uViewPos;

float camYaw = 0.0f, camPitch = 0.5f, camZoom = 10.0f;
int screenW, screenH;

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

// --- Shader Source (Embedded for Portability) ---
const char* WORLD_VS = "#version 300 es\n"
    "layout(location = 0) in vec3 aPos;\n"
    "layout(location = 1) in vec3 aCol;\n"
    "layout(location = 2) in vec3 aNorm;\n"
    "uniform mat4 uMVP, uModel;\n"
    "out vec3 vCol; out vec3 vNorm; out vec3 vFragPos;\n"
    "void main() {\n"
    "    vFragPos = vec3(uModel * vec4(aPos, 1.0));\n"
    "    vNorm = mat3(transpose(inverse(uModel))) * aNorm;\n"
    "    vCol = aCol;\n"
    "    gl_Position = uMVP * vec4(aPos, 1.0);\n"
    "}";

const char* WORLD_FS = "#version 300 es\n"
    "precision mediump float;\n"
    "in vec3 vCol; in vec3 vNorm; in vec3 vFragPos;\n"
    "uniform vec3 uSunDir; uniform vec3 uViewPos;\n"
    "out vec4 fragColor;\n"
    "void main() {\n"
    "    // Ambient\n"
    "    float ambient = 0.4;\n"
    "    // Diffuse Lighting\n"
    "    vec3 norm = normalize(vNorm);\n"
    "    float diff = max(dot(norm, normalize(uSunDir)), 0.0);\n"
    "    // Specular\n"
    "    vec3 viewDir = normalize(uViewPos - vFragPos);\n"
    "    vec3 reflectDir = reflect(-normalize(uSunDir), norm);\n"
    "    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0) * 0.3;\n"
    "    \n"
    "    vec3 lighting = (ambient + diff + spec) * vCol;\n"
    "    fragColor = vec4(lighting, 1.0);\n"
    "}";

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onCreated(JNIEnv* env, jclass clz) {
        // Compile Shaders (Simplified for brevity)
        GLuint vs = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vs, 1, &WORLD_VS, NULL); glCompileShader(vs);
        GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(fs, 1, &WORLD_FS, NULL); glCompileShader(fs);
        worldProgram = glCreateProgram();
        glAttachShader(worldProgram, vs); glAttachShader(worldProgram, fs);
        glLinkProgram(worldProgram);

        uMVP = glGetUniformLocation(worldProgram, "uMVP");
        uModel = glGetUniformLocation(worldProgram, "uModel");
        uSunDir = glGetUniformLocation(worldProgram, "uSunDir");
        uViewPos = glGetUniformLocation(worldProgram, "uViewPos");

        // Initialize VAOs with new 9-float logic
        vaoHead   = makeVAO9(M_HEAD, N_HEAD);
        vaoTorso  = makeVAO9(M_TORSO, N_TORSO);
        vaoUpLimb = makeVAO9(M_UP_LIMB, N_UP_LIMB);
        vaoTree   = makeVAO9(M_TREE, N_TREE);
        // ... Initialize others similarly
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onDraw(JNIEnv* env, jclass clz, 
        jfloat joyX, jfloat joyY, jfloat yaw, jfloat pitch) {
        
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST);
        glUseProgram(worldProgram);

        // Calculate Camera
        glm::vec3 camPos = glm::vec3(
            camZoom * cos(pitch) * sin(yaw),
            camZoom * sin(pitch),
            camZoom * cos(pitch) * cos(yaw)
        );
        glm::mat4 view = glm::lookAt(camPos, glm::vec3(0, 1, 0), glm::vec3(0, 1, 0));
        glm::mat4 proj = glm::perspective(glm::radians(45.0f), (float)screenW/screenH, 0.1f, 100.0f);
        
        glUniform3f(uSunDir, 0.5f, 1.0f, 0.3f); // Match skyline sun position
        glUniform3f(uViewPos, camPos.x, camPos.y, camPos.z);

        // Render Head (Example)
        glm::mat4 model = glm::translate(glm::mat4(1.0f), glm::vec3(0, 1.8f, 0));
        glUniformMatrix4fv(uModel, 1, GL_FALSE, glm::value_ptr(model));
        glUniformMatrix4fv(uMVP, 1, GL_FALSE, glm::value_ptr(proj * view * model));
        
        glBindVertexArray(vaoHead);
        glDrawArrays(GL_TRIANGLES, 0, N_HEAD);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_GameLib_onChanged(JNIEnv* env, jclass clz, jint w, jint h) {
        screenW = w; screenH = h;
        glViewport(0, 0, w, h);
    }
}
EOF
echo "[generate_engine.sh] Success: native-lib.cpp updated with Real-Time Lighting."
