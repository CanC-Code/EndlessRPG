#!/bin/bash
# File: scripts/setup_project.sh
# Purpose: Full structural scaffold for EndlessRPG + Realism Logic

echo "[setup_project.sh] Building full project hierarchy..."

# 1. Create Root Directory Structure
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/assets/shaders
mkdir -p app/src/main/cpp

# 2. Generate Root settings.gradle
cat <<EOF > settings.gradle
rootProject.name = "EndlessRPG"
include ':app'
EOF

# 3. Generate Root build.gradle
cat <<EOF > build.gradle
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.2.2'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
EOF

# 4. Generate App-level build.gradle (Configured for C++ & JNI)
cat <<EOF > app/build.gradle
plugins {
    id 'com.android.application'
}

android {
    namespace 'com.game.procedural'
    compileSdk 34

    defaultConfig {
        applicationId "com.game.procedural"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"

        externalNativeBuild {
            cmake {
                cppFlags "-std=c++17"
            }
        }
    }

    buildTypes {
        release {
            minifyEnabled false
        }
    }
    
    externalNativeBuild {
        cmake {
            path "src/main/cpp/CMakeLists.txt"
        }
    }
}
EOF

# 5. Generate the MainActivity (Camera-Relative Movement Logic)
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

    public native void onDraw(float mvX, float mvZ, float yaw, float time);

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        glView = new GLSurfaceView(this);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);
        setContentView(glView);
    }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) {}
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) {}

    @Override public void onDrawFrame(GL10 gl) {
        // --- CORRECTED CONTROLLER INPUT ---
        // Transform 2D joystick input based on Camera Yaw
        float cosY = (float) Math.cos(camYaw);
        float sinY = (float) Math.sin(camYaw);

        float worldMoveX = (joyX * cosY) - (joyY * sinY);
        float worldMoveZ = (joyX * sinY) + (joyY * cosY);

        onDraw(worldMoveX, worldMoveZ, camYaw, System.currentTimeMillis() / 1000.0f);
    }
}
EOF

echo "[setup_project.sh] Deployment complete."
