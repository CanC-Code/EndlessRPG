#!/bin/bash
# File: scripts/setup_project.sh
# Purpose: Full project scaffold with Environment Models (Trees/Rocks) and Advanced Math

echo "[setup_project.sh] Initializing EndlessRPG project structure..."

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

# 2. Generate Gradle Files
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

# 3. Generate CMakeLists.txt
cat <<EOF > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("game_engine")
add_library(game_engine SHARED native-lib.cpp)
find_library(log-lib log)
find_library(gles3-lib GLESv3)
target_link_libraries(game_engine \${log-lib} \${gles3-lib})
EOF

# 4. Generate AllModels.h (Includes Character, Trees, and Rocks)
cat <<EOF > app/src/main/cpp/models/AllModels.h
#ifndef ALL_MODELS_H
#define ALL_MODELS_H

#define BOX_VERTS(w, h, d) { \\
    -w,h,d, 0,0,1, w,h,d, 0,0,1, -w,-h,d, 0,0,1, w,h,d, 0,0,1, w,-h,d, 0,0,1, -w,-h,d, 0,0,1, \\
    -w,h,-d, 0,0,-1, -w,-h,-d, 0,0,-1, w,h,-d, 0,0,-1, w,h,-d, 0,0,-1, -w,-h,-d, 0,0,-1, w,-h,-d, 0,0,-1, \\
    -w,h,d, -1,0,0, -w,h,-d, -1,0,0, -w,-h,d, -1,0,0, -w,h,-d, -1,0,0, -w,-h,-d, -1,0,0, -w,-h,d, -1,0,0, \\
    w,h,d, 1,0,0, w,-h,d, 1,0,0, w,h,-d, 1,0,0, w,h,-d, 1,0,0, w,-h,d, 1,0,0, w,-h,-d, 1,0,0, \\
    -w,h,d, 0,1,0, -w,h,-d, 0,1,0, w,h,d, 0,1,0, -w,h,-d, 0,1,0, w,h,-d, 0,1,0, w,h,d, 0,1,0, \\
    -w,-h,d, 0,-1,0, w,-h,d, 0,-1,0, -w,-h,-d, 0,-1,0, w,-h,d, 0,-1,0, w,-h,-d, 0,-1,0, -w,-h,-d, 0,-1,0 }

static const float M_TORSO[]    = BOX_VERTS(0.25f, 0.35f, 0.15f);
static const float M_NECK[]     = BOX_VERTS(0.05f, 0.05f, 0.05f);
static const float M_HEAD[]     = BOX_VERTS(0.12f, 0.12f, 0.12f);
static const float M_UP_LIMB[]  = BOX_VERTS(0.08f, 0.20f, 0.08f);
static const float M_LOW_LIMB[] = BOX_VERTS(0.07f, 0.20f, 0.07f);
static const float M_HAND[]     = BOX_VERTS(0.06f, 0.06f, 0.06f);
static const float M_FOOT[]     = BOX_VERTS(0.08f, 0.05f, 0.15f);
static const float M_SWORD[]    = BOX_VERTS(0.03f, 0.60f, 0.01f);
static const float M_SHIELD[]   = BOX_VERTS(0.20f, 0.30f, 0.02f);
static const float M_TREE[]     = BOX_VERTS(0.40f, 2.00f, 0.40f);
static const float M_ROCK[]     = BOX_VERTS(0.60f, 0.40f, 0.60f);

#define N_TORSO 36
#define N_NECK 36
#define N_HEAD 36
#define N_UP_LIMB 36
#define N_LOW_LIMB 36
#define N_HAND 36
#define N_FOOT 36
#define N_SWORD 36
#define N_SHIELD 36
#define N_TREE 36
#define N_ROCK 36

#endif
EOF

# 5. Generate native-lib.cpp (Includes missing m4RY, m4S, and Environment drawing)
cat <<EOF > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <vector>
#include "models/AllModels.h"

struct Mat4 { float m[16]; };
Mat4 m4I() { Mat4 r={0}; r.m[0]=r.m[5]=r.m[10]=r.m[15]=1.0f; return r; }
Mat4 m4mul(Mat4 a, Mat4 b) {
    Mat4 r;
    for(int i=0; i<4; i++) for(int j=0; j<4; j++) {
        r.m[i*4+j] = a.m[i*4+0]*b.m[0+j] + a.m[i*4+1]*b.m[4+j] + a.m[i*4+2]*b.m[8+j] + a.m[i*4+3]*b.m[12+j];
    }
    return r;
}
Mat4 m4T(float x, float y, float z) { Mat4 r=m4I(); r.m[12]=x; r.m[13]=y; r.m[14]=z; return r; }
Mat4 m4RY(float a) { Mat4 r=m4I(); r.m[0]=cosf(a); r.m[2]=-sinf(a); r.m[8]=sinf(a); r.m[10]=cosf(a); return r; }
Mat4 m4RX(float a) { Mat4 r=m4I(); r.m[5]=cosf(a); r.m[6]=sinf(a); r.m[9]=-sinf(a); r.m[10]=cosf(a); return r; }
Mat4 m4S(float x, float y, float z) { Mat4 r=m4I(); r.m[0]=x; r.m[5]=y; r.m[10]=z; return r; }

GLuint program, mvpLoc;
GLuint g_vaoTorso, g_vaoNeck, g_vaoHead, g_vaoUpLimb, g_vaoLowLimb, g_vaoHand, g_vaoFoot, g_vaoSword, g_vaoShield, g_vaoTree, g_vaoRock;
float playerX=0, playerZ=0, engineZoom=10.0f;

GLuint makeVAO6(const float* d, int c) {
    GLuint vao, vbo;
    glGenVertexArrays(1, &vao); glBindVertexArray(vao);
    glGenBuffers(1, &vbo); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, c * 6 * sizeof(float), d, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), 0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), (void*)(3*sizeof(float))); glEnableVertexAttribArray(1);
    return vao;
}

void drawVAO(GLuint vao, int count, Mat4 model, Mat4 vp) {
    Mat4 mvp = m4mul(vp, model);
    glUniformMatrix4fv(mvpLoc, 1, GL_FALSE, mvp.m);
    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, count);
}

extern "C" {
JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv* env, jobject obj) {
    const char* vs = "#version 300 es\nlayout(location=0) in vec3 p; layout(location=1) in vec3 n; uniform mat4 uMVP; out vec3 vN; void main(){ gl_Position=uMVP*vec4(p,1); vN=n; }";
    const char* fs = "#version 300 es\nprecision mediump float; in vec3 vN; out vec4 f; void main(){ float l=max(0.3, dot(vN, normalize(vec3(0.5,1,0.5)))); f=vec4(vec3(0.6,0.5,0.4)*l,1); }";
    program = glCreateProgram();
    GLuint sV=glCreateShader(GL_VERTEX_SHADER); glShaderSource(sV,1,&vs,0); glCompileShader(sV); glAttachShader(program,sV);
    GLuint sF=glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(sF,1,&fs,0); glCompileShader(sF); glAttachShader(program,sF);
    glLinkProgram(program);
    mvpLoc = glGetUniformLocation(program, "uMVP");
    
    g_vaoTorso=makeVAO6(M_TORSO, N_TORSO); g_vaoNeck=makeVAO6(M_NECK, N_NECK); g_vaoHead=makeVAO6(M_HEAD, N_HEAD);
    g_vaoUpLimb=makeVAO6(M_UP_LIMB, N_UP_LIMB); g_vaoLowLimb=makeVAO6(M_LOW_LIMB, N_LOW_LIMB);
    g_vaoHand=makeVAO6(M_HAND, N_HAND); g_vaoFoot=makeVAO6(M_FOOT, N_FOOT);
    g_vaoSword=makeVAO6(M_SWORD, N_SWORD); g_vaoShield=makeVAO6(M_SHIELD, N_SHIELD);
    g_vaoTree=makeVAO6(M_TREE, N_TREE); g_vaoRock=makeVAO6(M_ROCK, N_ROCK);
    glEnable(GL_DEPTH_TEST);
}

JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv* env, jobject obj, jint w, jint h) { glViewport(0,0,w,h); }

JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv* env, jobject obj, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch) {
    playerX += (ix * cosf(yaw) - iy * sinf(yaw)) * 0.1f;
    playerZ += (ix * sinf(yaw) + iy * cosf(yaw)) * 0.1f;
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); glUseProgram(program);

    Mat4 vp = m4mul(m4T(0,0,-engineZoom), m4mul(m4RX(pitch), m4RY(-yaw)));
    Mat4 pBase = m4T(playerX, 0.7f, playerZ);

    drawVAO(g_vaoTorso, N_TORSO, pBase, vp);
    
    // Draw Environment placeholders (Satisfies errors for N_TREE, N_ROCK)
    drawVAO(g_vaoTree, N_TREE, m4mul(m4T(5, 1, 5), m4S(1, 1, 1)), vp);
    drawVAO(g_vaoRock, N_ROCK, m4mul(m4T(-3, 0.2f, 2), m4S(1.2f, 0.8f, 1.2f)), vp);
}

JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_setZoom(JNIEnv* env, jobject obj, jfloat z) { engineZoom = z; }
JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv* env, jobject obj, jint id) {}
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getCameraYaw(JNIEnv* env, jobject obj) { return 0.0f; }
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getStamina(JNIEnv* env, jobject obj) { return 1.0f; }
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getHealth(JNIEnv* env, jobject obj) { return 1.0f; }
JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_setStamina(JNIEnv* env, jobject obj, jfloat v) {}
}
EOF

# 6. Generate Layout
cat <<EOF > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="match_parent">
    <android.opengl.GLSurfaceView android:id="@+id/gl_surface_view"
        android:layout_width="match_parent" android:layout_height="match_parent" />
    <View android:id="@+id/touch_zone_move"
        android:layout_width="200dp" android:layout_height="200dp"
        android:layout_gravity="bottom|left" android:background="#110000FF" />
    <View android:id="@+id/touch_zone_orbit"
        android:layout_width="match_parent" android:layout_height="match_parent"
        android:layout_marginLeft="200dp" />
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
    private float joyX = 0, joyY = 0;
    private float camYaw = 0.7f, camPitch = 0.35f;
    private float lastOrbitX = 0, lastOrbitY = 0;
    private boolean orbitActive = false;
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
            public boolean onScale(ScaleGestureDetector d) {
                camZoom = Math.max(4.0f, Math.min(40.0f, camZoom / d.getScaleFactor()));
                glView.queueEvent(() -> setZoom(camZoom));
                return true;
            }
        });

        glView.setOnTouchListener((v, e) -> { scaleDetector.onTouchEvent(e); return false; });

        findViewById(R.id.touch_zone_move).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_UP) { joyX = 0; joyY = 0; }
            else {
                joyX = (e.getX() - (v.getWidth()/2f)) / (v.getWidth()/2f);
                joyY = (e.getY() - (v.getHeight()/2f)) / (v.getHeight()/2f);
                float l = (float)Math.sqrt(joyX*joyX+joyY*joyY);
                if(l>1.0f){ joyX/=l; joyY/=l; }
            }
            return true;
        });

        findViewById(R.id.touch_zone_orbit).setOnTouchListener((v, e) -> {
            scaleDetector.onTouchEvent(e);
            if (e.getAction() == MotionEvent.ACTION_DOWN) { lastOrbitX=e.getX(); lastOrbitY=e.getY(); orbitActive=true; }
            else if (e.getAction() == MotionEvent.ACTION_MOVE && orbitActive) {
                camYaw -= (e.getX()-lastOrbitX)*0.008f; 
                camPitch = Math.max(0.05f, Math.min(1.45f, camPitch - (e.getY()-lastOrbitY)*0.008f));
                lastOrbitX=e.getX(); lastOrbitY=e.getY();
            }
            return true;
        });
    }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); setZoom(camZoom); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }
    @Override public void onDrawFrame(GL10 gl) { onDraw(joyX, -joyY, camYaw, camPitch); }
}
EOF

echo "[setup_project.sh] Fixes applied. Run ./gradlew :app:assembleDebug."
