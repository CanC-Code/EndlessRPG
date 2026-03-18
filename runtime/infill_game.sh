#!/bin/bash
echo "Enhancing 3D Engine & Procedural Assets..."

# 1. SMART ASSET GENERATION (ImageMagick Procedural Art)
# Create a 'Dithered' stylized Grass Texture
convert -size 512x512 plasma:fractal \
    \( +clone -charcoal 1 -blur 0x2 -colorspace Gray -auto-level \) \
    -compose Overlay -composite \
    -fill "#2D5A27" -tint 100 \
    -modulate 100,150,100 \
    app/src/main/res/drawable/grass_tex.png

# Create a Stylized Cloud Map (Perlin-based)
convert -size 1024x512 canvas:none \
    -sparse-color Barycentric '0,0 white %w,%h white' \
    -plasma 0x0 -blur 0x15 -shade 120x45 -auto-level \
    -fill "rgba(255,255,255,0.8)" -opaque white \
    app/src/main/res/drawable/sky_clouds.png

# 2. INJECT ENHANCED C++ ENGINE
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <vector>
#include <cmath>
#include <android/log.h>

#define LOG_TAG "GameEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

// Updated Shaders: Supports Vertex Coloring for terrain depth
const char* vShader = "#version 300 es\n"
    "layout(location = 0) in vec4 vPosition;"
    "layout(location = 1) in vec4 vColor;"
    "uniform mat4 uMatrix;"
    "out vec4 fColor;"
    "void main() { "
    "  gl_Position = uMatrix * vPosition;"
    "  fColor = vColor;"
    "}";

const char* fShader = "#version 300 es\n"
    "precision mediump float;"
    "in vec4 fColor;"
    "out vec4 fragColor;"
    "void main() { fragColor = fColor; }";

GLuint program;
float playerX = 0.0f, playerZ = 0.0f;

// Helper to create a procedural tree mesh (Simple low-poly cylinder + sphere)
void drawProceduralTree(GLint matrixLoc, float x, float z) {
    // Tree logic will go here in next iteration
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_nativeSurfaceCreated(JNIEnv*, jobject) {
    GLuint vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs, 1, &vShader, nullptr);
    glCompileShader(vs);

    GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs, 1, &fShader, nullptr);
    glCompileShader(fs);

    program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);
    glUseProgram(program);
    
    glEnable(GL_DEPTH_TEST);
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_nativeSurfaceChanged(JNIEnv*, jobject, jint w, jint h) {
    glViewport(0, 0, w, h);
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_nativeDrawFrame(JNIEnv*, jobject, jfloat inputX, jfloat inputY) {
    playerX += inputX * 0.15f;
    playerZ -= inputY * 0.15f;

    // Sky Gradient
    glClearColor(0.4f, 0.7f, 1.0f, 1.0f); 
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    GLint matrixLoc = glGetUniformLocation(program, "uMatrix");

    // Camera/View Matrix (Perspective approximation)
    float aspect = 1.7f; // Standard phone aspect
    float matrix[16] = {
        1.0f/aspect, 0, 0, 0,
        0, 1.5f, 0.5f, 0, // Tilt for top-down feel
        0, -0.5f, 1, 0,
        -playerX, -1.5f, playerZ - 8.0f, 1
    };
    glUniformMatrix4fv(matrixLoc, 1, GL_FALSE, matrix);

    // Ground Vertices with "Depth Coloring" (Darker green in distance)
    float ground[] = { 
        -50, 0, -50,   50, 0, -50,  -50, 0, 50,   50, 0, 50 
    };
    float colors[] = {
        0.1f, 0.5f, 0.1f, 1.0f,  0.1f, 0.5f, 0.1f, 1.0f,
        0.2f, 0.7f, 0.2f, 1.0f,  0.2f, 0.7f, 0.2f, 1.0f
    };

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, ground);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 0, colors);
    glEnableVertexAttribArray(1);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}
EOF
