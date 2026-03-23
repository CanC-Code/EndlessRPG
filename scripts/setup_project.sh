#!/bin/bash
# File: scripts/setup_project.sh
# Purpose: Full project scaffold with functional C++ 3D Rendering Pipeline

echo "[setup_project.sh] Initializing EndlessRPG project structure..."

mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/cpp

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
}
EOF

# 3. Generate CMakeLists.txt
cat <<EOF > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("game_engine")
add_library(game_engine SHARED engine.cpp)
find_library(log-lib log)
find_library(gles3-lib GLESv3)
target_link_libraries(game_engine \${log-lib} \${gles3-lib})
EOF

# 4. Generate the FULL C++ Engine (Fixes the Green Screen)
cat <<EOF > app/src/main/cpp/engine.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <vector>

// --- Simple 3D Math ---
struct Mat4 {
    float m[16] = {0};
    Mat4() { m[0]=1; m[5]=1; m[10]=1; m[15]=1; } // Identity
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

// --- Shader Sources ---
const char* VERTEX_SHADER = R"(
    #version 300 es
    layout(location = 0) in vec3 aPos;
    uniform mat4 uMVP;
    uniform float uTime;
    out float vFogDepth;
    void main() {
        vec3 pos = aPos;
        // The Real-World Wind Sway Logic
        if (pos.y > 0.1) {
            pos.x += sin(uTime * 1.5 + pos.x) * (pos.y * 0.1);
        }
        gl_Position = uMVP * vec4(pos, 1.0);
        vFogDepth = -(uMVP * vec4(pos, 1.0)).z;
    }
)";

const char* FRAGMENT_SHADER = R"(
    #version 300 es
    precision highp float;
    in float vFogDepth;
    out vec4 fragColor;
    void main() {
        // Atmospheric Fog Math
        float fogFactor = exp(-pow(vFogDepth * 0.05, 2.0));
        vec3 fogColor = vec3(0.5, 0.6, 0.7);
        vec3 groundColor = vec3(0.2, 0.5, 0.2); // Grass green
        fragColor = vec4(mix(fogColor, groundColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
    }
)";

// --- Global Engine State ---
GLuint programId;
GLint mvpLoc;
GLint timeLoc;
float screenAspect = 1.0f;
float playerX = 0.0f, playerZ = 0.0f;
GLuint vao, vbo;

GLuint compileShader(GLenum type, const char* src) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);
    return shader;
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onCreated(JNIEnv* env, jobject obj) {
    programId = glCreateProgram();
    glAttachShader(programId, compileShader(GL_VERTEX_SHADER, VERTEX_SHADER));
    glAttachShader(programId, compileShader(GL_FRAGMENT_SHADER, FRAGMENT_SHADER));
    glLinkProgram(programId);
    mvpLoc = glGetUniformLocation(programId, "uMVP");
    timeLoc = glGetUniformLocation(programId, "uTime");

    // Generate a simple repeating ground plane (The grass floor)
    std::vector<float> vertices = {
        -50.0f, 0.0f, -50.0f,  50.0f, 0.0f, -50.0f,  -50.0f, 0.0f,  50.0f,
         50.0f, 0.0f, -50.0f,  50.0f, 0.0f,  50.0f,  -50.0f, 0.0f,  50.0f
    };
    
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onChanged(JNIEnv* env, jobject obj, jint width, jint height) {
    glViewport(0, 0, width, height);
    screenAspect = (float)width / (float)height;
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onDraw(JNIEnv* env, jobject obj, jfloat mvX, jfloat mvZ, jfloat yaw, jfloat pitch, jfloat time) {
    // 1. Update Player Position from Controller input
    playerX += mvX * 0.1f;
    playerZ += mvZ * 0.1f;

    // 2. Clear Screen to Fog Color
    glClearColor(0.5f, 0.6f, 0.7f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glUseProgram(programId);
    glUniform1f(timeLoc, time);

    // 3. Build Matrices
    Mat4 proj, view, mvp;
    perspective(proj, 1.047f, screenAspect, 0.1f, 100.0f); // 60 degrees FOV

    // Simple View Matrix (Camera behind player, looking forward based on Yaw/Pitch)
    float cosY = cosf(yaw), sinY = sinf(yaw);
    float cosP = cosf(pitch), sinP = sinf(pitch);
    
    // Rotate and Translate View
    view.m[0] = cosY;  view.m[4] = 0;     view.m[8]  = -sinY;
    view.m[1] = sinY*sinP; view.m[5] = cosP;  view.m[9]  = cosY*sinP;
    view.m[2] = sinY*cosP; view.m[6] = -sinP; view.m[10] = cosY*cosP;
    
    view.m[12] = -(playerX * view.m[0] + 1.5f * view.m[4] + playerZ * view.m[8]); // Camera Height 1.5
    view.m[13] = -(playerX * view.m[1] + 1.5f * view.m[5] + playerZ * view.m[9]);
    view.m[14] = -(playerX * view.m[2] + 1.5f * view.m[6] + playerZ * view.m[10]);

    multiply(mvp, proj, view);
    glUniformMatrix4fv(mvpLoc, 1, GL_FALSE, mvp.m);

    // 4. Draw Geometry
    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);
}
EOF

# 5. Generate UI Layout (Move Joystick Left, Orbit View Right)
cat <<EOF > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="match_parent">
    <android.opengl.GLSurfaceView android:id="@+id/gl_surface_view"
        android:layout_width="match_parent" android:layout_height="match_parent" />
    <View android:id="@+id/touch_zone_move"
        android:layout_width="200dp" android:layout_height="200dp"
        android:layout_gravity="bottom|left" android:background="#220000FF" />
    <View android:id="@+id/touch_zone_orbit"
        android:layout_width="match_parent" android:layout_height="match_parent"
        android:layout_marginLeft="200dp" />
</FrameLayout>
EOF

# 6. Generate MainActivity (Linked to new C++ functions)
cat <<EOF > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;

import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity implements GLSurfaceView.Renderer {
    private GLSurfaceView glView;
    private float joyX = 0, joyY = 0;
    private float camYaw = 0, camPitch = 0, lastX = 0, lastY = 0;

    static { System.loadLibrary("game_engine"); }
    public native void onCreated();
    public native void onChanged(int w, int h);
    public native void onDraw(float mX, float mZ, float yaw, float pitch, float time);

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        setContentView(R.layout.activity_main);
        glView = findViewById(R.id.gl_surface_view);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);

        findViewById(R.id.touch_zone_move).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_UP) { joyX = 0; joyY = 0; }
            else {
                joyX = (e.getX() - (v.getWidth()/2f)) / (v.getWidth()/2f);
                joyY = (e.getY() - (v.getHeight()/2f)) / (v.getHeight()/2f);
            }
            return true;
        });

        findViewById(R.id.touch_zone_orbit).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_MOVE) {
                camYaw -= (e.getX() - lastX) * 0.01f;
                camPitch -= (e.getY() - lastY) * 0.01f;
                camPitch = Math.max(-1.5f, Math.min(1.5f, camPitch)); // Limit look up/down
            }
            lastX = e.getX(); lastY = e.getY();
            return true;
        });
    }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }

    @Override public void onDrawFrame(GL10 gl) {
        float cosY = (float) Math.cos(camYaw);
        float sinY = (float) Math.sin(camYaw);
        // Corrected directional input logic based on camera facing
        float worldMoveX = (joyX * cosY) - (joyY * sinY);
        float worldMoveZ = (joyX * sinY) + (joyY * cosY);
        onDraw(worldMoveX, worldMoveZ, camYaw, camPitch, System.currentTimeMillis() / 1000.0f);
    }
}
EOF

echo "[setup_project.sh] Deployment complete."
