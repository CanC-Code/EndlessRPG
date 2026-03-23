#!/bin/bash
# File: scripts/setup_project.sh
# Purpose: Full project scaffold with Integrated Custom MainActivity, Models directory, and C++ Sync

echo "[setup_project.sh] Initializing EndlessRPG project structure..."

# Create directory structure including the missing models folder
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/cpp/models

# 1. Generate Android Manifest
cat <<EOF > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:allowBackup="true"
        android:label="EndlessRPG"
        android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:screenOrientation="landscape">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# 2. Generate Root & App Gradle Configs
cat <<EOF > settings.gradle
rootProject.name = "EndlessRPG"
include ':app'
EOF

cat <<EOF > build.gradle
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.2.2' }
}
allprojects { repositories { google(); mavenCentral() } }
EOF

cat <<EOF > app/build.gradle
plugins { id 'com.android.application' }
android {
    namespace 'com.game.procedural'
    compileSdk 34
    defaultConfig {
        applicationId "com.game.procedural"
        minSdk 24
        targetSdk 34
        externalNativeBuild { cmake { cppFlags "-std=c++17 -lm" } }
    }
    externalNativeBuild { cmake { path "src/main/cpp/CMakeLists.txt" } }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
EOF

# 3. Generate CMakeLists.txt (Updated to use native-lib.cpp)
cat <<EOF > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("game_engine")

# Using native-lib.cpp to match your environment's build requirements
add_library(game_engine SHARED native-lib.cpp)

find_library(log-lib log)
find_library(gles3-lib GLESv3)
target_link_libraries(game_engine \${log-lib} \${gles3-lib})
EOF

# 4. Generate the required Models Header
cat <<EOF > app/src/main/cpp/models/AllModels.h
#ifndef ALL_MODELS_H
#define ALL_MODELS_H

// Placeholder for procedural model data
// This file is required by native-lib.cpp

#endif
EOF

# 5. Generate the FULL C++ Engine (native-lib.cpp)
cat <<EOF > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <vector>
#include "models/AllModels.h"

// --- Simple 3D Math ---
struct Mat4 {
    float m[16] = {0};
    Mat4() { m[0]=1; m[5]=1; m[10]=1; m[15]=1; }
};

void multiply(Mat4& out, const Mat4& a, const Mat4& b) {
    for(int r=0; r<4; ++r) {
        for(int c=0; c<4; ++c) {
            float sum = 0;
            for(int i=0; i<4; ++i) sum += a.m[c*4 + i] * b.m[i*4 + r];
            out.m[c*4 + r] = sum;
        }
    }
}

void perspective(Mat4& out, float fov, float aspect, float nearZ, float farZ) {
    float f = 1.0f / tanf(fov / 2.0f);
    out = Mat4();
    out.m[0] = f / aspect;
    out.m[5] = f;
    out.m[10] = (farZ + nearZ) / (nearZ - farZ);
    out.m[11] = -1.0f;
    out.m[14] = (2.0f * farZ * nearZ) / (nearZ - farZ);
    out.m[15] = 0.0f;
}

// --- Shaders ---
const char* VERTEX_SHADER = R"(
    #version 300 es
    layout(location = 0) in vec3 aPos;
    uniform mat4 uMVP;
    out float vFogDepth;
    void main() {
        gl_Position = uMVP * vec4(aPos, 1.0);
        vFogDepth = -(uMVP * vec4(aPos, 1.0)).z;
    }
)";

const char* FRAGMENT_SHADER = R"(
    #version 300 es
    precision highp float;
    in float vFogDepth;
    out vec4 fragColor;
    void main() {
        float fogFactor = exp(-pow(vFogDepth * 0.05, 2.0));
        vec3 fogColor = vec3(0.5, 0.6, 0.7);
        vec3 groundColor = vec3(0.2, 0.4, 0.2);
        fragColor = vec4(mix(fogColor, groundColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
    }
)";

// --- Engine State ---
GLuint programId;
GLint mvpLoc;
float screenAspect = 1.0f;
float playerX = 0.0f, playerZ = 0.0f;
float engineZoom = 12.0f;
GLuint vao, vbo;

GLuint compileShader(GLenum type, const char* src) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);
    return shader;
}

extern "C" {

JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onCreated(JNIEnv* env, jobject obj) {
    programId = glCreateProgram();
    glAttachShader(programId, compileShader(GL_VERTEX_SHADER, VERTEX_SHADER));
    glAttachShader(programId, compileShader(GL_FRAGMENT_SHADER, FRAGMENT_SHADER));
    glLinkProgram(programId);
    mvpLoc = glGetUniformLocation(programId, "uMVP");

    std::vector<float> vertices = {
        -100.0f, 0.0f, -100.0f,  100.0f, 0.0f, -100.0f,  -100.0f, 0.0f,  100.0f,
         100.0f, 0.0f, -100.0f,  100.0f, 0.0f,  100.0f,  -100.0f, 0.0f,  100.0f
    };
    
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glEnable(GL_DEPTH_TEST);
}

JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onChanged(JNIEnv* env, jobject obj, jint width, jint height) {
    glViewport(0, 0, width, height);
    screenAspect = (float)width / (float)height;
}

JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onDraw(JNIEnv* env, jobject obj, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch) {
    // Basic movement
    playerX += (ix * cosf(yaw) - iy * sinf(yaw)) * 0.15f;
    playerZ += (ix * sinf(yaw) + iy * cosf(yaw)) * 0.15f;

    glClearColor(0.5f, 0.6f, 0.7f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glUseProgram(programId);

    Mat4 proj, view, mvp;
    perspective(proj, 0.8f, screenAspect, 0.1f, 200.0f);

    float camX = playerX + engineZoom * cosf(pitch) * sinf(yaw);
    float camY = engineZoom * sinf(pitch) + 1.0f; 
    float camZ = playerZ + engineZoom * cosf(pitch) * cosf(yaw);

    view.m[12] = -camX; view.m[13] = -camY; view.m[14] = -camZ;

    multiply(mvp, proj, view);
    glUniformMatrix4fv(mvpLoc, 1, GL_FALSE, mvp.m);

    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);
}

JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_setZoom(JNIEnv* env, jobject obj, jfloat z) { engineZoom = z; }
JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv* env, jobject obj, jint id) {}
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getCameraYaw(JNIEnv* env, jobject obj) { return 0.0f; }
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getStamina(JNIEnv* env, jobject obj) { return 1.0f; }
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getHealth(JNIEnv* env, jobject obj) { return 1.0f; }
JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_setStamina(JNIEnv* env, jobject obj, jfloat v) {}

}
EOF

# 6. Generate UI Layout
cat <<EOF > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="match_parent">
    <android.opengl.GLSurfaceView android:id="@+id/gl_surface_view"
        android:layout_width="match_parent" android:layout_height="match_parent" />
    <View android:id="@+id/touch_zone_move"
        android:layout_width="250dp" android:layout_height="250dp"
        android:layout_gravity="bottom|left" android:background="#110000FF" />
    <View android:id="@+id/touch_zone_orbit"
        android:layout_width="match_parent" android:layout_height="match_parent"
        android:layout_marginLeft="250dp" android:background="#11FF0000" />
</FrameLayout>
EOF

# 7. Generate MainActivity
cat <<EOF > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;

import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity implements GLSurfaceView.Renderer {
    private GLSurfaceView glView;

    // Joystick state (left touch zone)
    private float joyX = 0, joyY = 0;

    // Camera orbit state (right touch zone)
    private float camYaw = 0.7f, camPitch = 0.35f;
    private float lastOrbitX = 0, lastOrbitY = 0;
    private boolean orbitActive = false;

    // Pinch-to-zoom
    private float camZoom = 12.0f;
    private ScaleGestureDetector scaleDetector;

    static { System.loadLibrary("game_engine"); }
    public native void onCreated();
    public native void onChanged(int w, int h);
    public native void onDraw(float ix, float iy, float yaw, float pitch);
    public native void triggerAction(int id);
    public native void setZoom(float zoom);
    public native float getCameraYaw();
    public native float getStamina();
    public native float getHealth();
    public native void  setStamina(float v);

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        setContentView(R.layout.activity_main);

        glView = findViewById(R.id.gl_surface_view);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);
        glView.setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);

        scaleDetector = new ScaleGestureDetector(this, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
            @Override
            public boolean onScale(ScaleGestureDetector detector) {
                camZoom /= detector.getScaleFactor();
                camZoom = Math.max(4.0f, Math.min(40.0f, camZoom));
                glView.queueEvent(() -> setZoom(camZoom));
                return true;
            }
        });
        
        glView.setOnTouchListener((v, e) -> {
            scaleDetector.onTouchEvent(e);
            return false;
        });

        findViewById(R.id.touch_zone_move).setOnTouchListener((v, e) -> {
            switch (e.getAction()) {
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    joyX = 0; joyY = 0;
                    break;
                default:
                    joyX = (e.getX() - (v.getWidth() / 2f)) / (v.getWidth() / 2f);
                    joyY = (e.getY() - (v.getHeight() / 2f)) / (v.getHeight() / 2f);
                    float len = (float) Math.sqrt(joyX * joyX + joyY * joyY);
                    if (len > 1.0f) { joyX /= len; joyY /= len; }
                    break;
            }
            return true;
        });

        findViewById(R.id.touch_zone_orbit).setOnTouchListener((v, e) -> {
            scaleDetector.onTouchEvent(e);
            switch (e.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    lastOrbitX = e.getX(); lastOrbitY = e.getY();
                    orbitActive = true;
                    break;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    orbitActive = false;
                    break;
                case MotionEvent.ACTION_MOVE:
                    if (orbitActive) {
                        float dx = e.getX() - lastOrbitX;
                        float dy = e.getY() - lastOrbitY;
                        camYaw   -= dx * 0.008f;
                        camPitch -= dy * 0.008f;
                        camPitch = Math.max(0.05f, Math.min(1.45f, camPitch));
                        lastOrbitX = e.getX(); lastOrbitY = e.getY();
                    }
                    break;
            }
            return true;
        });
    }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) {
        onCreated();
        setZoom(camZoom);
    }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }

    @Override public void onDrawFrame(GL10 gl) {
        onDraw(joyX, -joyY, camYaw, camPitch);
    }
}
EOF

echo "[setup_project.sh] Deployment complete. Ready for gradlew assembleDebug."
