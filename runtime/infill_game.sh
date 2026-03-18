#!/bin/bash
echo "Infilling 3D Game Engine..."

# 1. GENERATE ASSETS (The "Smart" Way)
# Generate a stylized grass texture using ImageMagick
convert -size 256x256 plasma:fractal -colorspace Gray -negate -threshold 50% \
        -fill "#4CAF50" -opaque white -fill "#388E3C" -opaque black \
        -blur 0x1 app/src/main/res/drawable/grass_tex.png

# 2. INJECT JAVA RENDERER & TOUCH LOGIC
cat << 'EOF' > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;

import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity implements GLSurfaceView.Renderer {
    private GLSurfaceView glView;
    private float touchX, touchY;

    static { System.loadLibrary("procedural_engine"); }
    private native void nativeSurfaceCreated();
    private native void nativeSurfaceChanged(int w, int h);
    private native void nativeDrawFrame(float inputX, float inputY);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        glView = findViewById(R.id.game_surface);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);

        // Thumbstick Logic (Simplified)
        findViewById(R.id.thumbstick).setOnTouchListener((v, event) -> {
            if (event.getAction() == MotionEvent.ACTION_MOVE) {
                touchX = (event.getX() / v.getWidth()) * 2 - 1;
                touchY = (event.getY() / v.getHeight()) * 2 - 1;
            } else if (event.getAction() == MotionEvent.ACTION_UP) {
                touchX = 0; touchY = 0;
            }
            return true;
        });
    }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig config) { nativeSurfaceCreated(); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { nativeSurfaceChanged(w, h); }
    @Override public void onDrawFrame(GL10 gl) { nativeDrawFrame(touchX, touchY); }
}
EOF

# 3. INJECT C++ ENGINE (OpenGL ES 3.0)
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <vector>
#include <string>
#include <android/log.h>

#define LOG_TAG "GameEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

// Simple Shaders for that N64/Retro Look
const char* vShader = "#version 300 es\n"
    "layout(location = 0) in vec4 vPosition;"
    "uniform mat4 uMatrix;"
    "void main() { gl_Position = uMatrix * vPosition; }";

const char* fShader = "#version 300 es\n"
    "precision mediump float;"
    "out vec4 fragColor;"
    "uniform vec4 uColor;"
    "void main() { fragColor = uColor; }";

GLuint program;
float cameraZ = -5.0f;
float playerX = 0.0f;
float playerZ = 0.0f;

GLuint compileShader(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCreateShader(shader);
    glCompileShader(shader);
    return shader;
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_nativeSurfaceCreated(JNIEnv*, jobject) {
    GLuint vs = compileShader(GL_VERTEX_SHADER, vShader);
    GLuint fs = compileShader(GL_FRAGMENT_SHADER, fShader);
    program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);
    glUseProgram(program);
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_nativeSurfaceChanged(JNIEnv*, jobject, jint w, jint h) {
    glViewport(0, 0, w, h);
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_nativeDrawFrame(JNIEnv*, jobject, jfloat inputX, jfloat inputY) {
    // 1. Update Player Position based on Thumbstick
    playerX += inputX * 0.1f;
    playerZ -= inputY * 0.1f;

    // 2. Clear Screen (Sky Blue)
    glClearColor(0.53f, 0.81f, 0.92f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // 3. Render Ground (Green Plane)
    GLint colorLoc = glGetUniformLocation(program, "uColor");
    GLint matrixLoc = glGetUniformLocation(program, "uMatrix");

    // Very basic projection/view matrix (Identity for now, but shifted)
    float matrix[16] = {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        -playerX, -1.0f, playerZ + cameraZ, 1
    };
    
    glUniformMatrix4fv(matrixLoc, 1, GL_FALSE, matrix);
    glUniform4f(colorLoc, 0.1f, 0.8f, 0.1f, 1.0f); // Grass Green

    float vertices[] = { -10, 0, -10,  10, 0, -10,  -10, 0, 10,  10, 0, 10 };
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glEnableVertexAttribArray(0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}
EOF

echo "Engine Infilled! Ready for Action trigger."
