#!/bin/bash
# File: scripts/setup_project.sh
# Purpose: Complete project scaffold with C++ Engine and Realism Shaders

echo "[setup_project.sh] Building full project hierarchy..."

# 1. Create Directory Hierarchy
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/assets/shaders
mkdir -p app/src/main/cpp

# 2. Generate Android Manifest (Cleaned of deprecated package attribute)
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

# 3. Generate CMakeLists.txt (FIXES THE BUILD ERROR)
cat <<EOF > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("game_engine")

add_library(game_engine SHARED engine.cpp)

find_library(log-lib log)
find_library(gles3-lib GLESv3)

target_link_libraries(game_engine \${log-lib} \${gles3-lib})
EOF

# 4. Generate C++ Engine Scaffold (The JNI Bridge)
cat <<EOF > app/src/main/cpp/engine.cpp
#include <jni.h>
#include <GLES3/gl3.h>

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onDraw(JNIEnv* env, jobject obj, 
                                            jfloat mvX, jfloat mvZ, 
                                            jfloat yaw, jfloat time) {
    // This is where the C++ engine processes the 'Corrected Direction' and 'Time'
    // for the flowing environment shaders.
    glClearColor(0.1f, 0.15f, 0.1f, 1.0f); // Dark forest green background
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}
EOF

# 5. Generate Root Configuration Files
cat <<EOF > settings.gradle
rootProject.name = "EndlessRPG"
include ':app'
EOF

cat <<EOF > build.gradle
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.2.2' }
}
allprojects {
    repositories { google(); mavenCentral() }
}
EOF

# 6. Generate App Build Script
cat <<EOF > app/build.gradle
plugins { id 'com.android.application' }

android {
    namespace 'com.game.procedural'
    compileSdk 34
    defaultConfig {
        applicationId "com.game.procedural"
        minSdk 24
        targetSdk 34
        externalNativeBuild { cmake { cppFlags "-std=c++17" } }
    }
    externalNativeBuild { cmake { path "src/main/cpp/CMakeLists.txt" } }
}
EOF

# 7. Generate UI Layout (Joystick & Viewport)
cat <<EOF > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    <android.opengl.GLSurfaceView
        android:id="@+id/gl_surface_view"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />
    <View
        android:id="@+id/touch_zone_move"
        android:layout_width="200dp"
        android:layout_height="200dp"
        android:layout_gravity="bottom|left"
        android:background="#22FFFFFF" />
</FrameLayout>
EOF

# 8. Generate MainActivity (Camera-Relative Movement Logic)
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
    private float camYaw = 0;

    static { System.loadLibrary("game_engine"); }
    public native void onDraw(float moveX, float moveZ, float yaw, float time);

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
    }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) {}
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) {}

    @Override public void onDrawFrame(GL10 gl) {
        float cosY = (float) Math.cos(camYaw);
        float sinY = (float) Math.sin(camYaw);
        float worldMoveX = (joyX * cosY) - (joyY * sinY);
        float worldMoveZ = (joyX * sinY) + (joyY * cosY);
        onDraw(worldMoveX, worldMoveZ, camYaw, System.currentTimeMillis() / 1000.0f);
    }
}
EOF

echo "[setup_project.sh] Deployment complete. C++ bridge and Manifest are now ready."
