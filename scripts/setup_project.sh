#!/bin/bash
# File: scripts/setup_project.sh
# Purpose: Full project scaffold including Manifest, Realism Shaders, and Control Logic

echo "[setup_project.sh] Initializing EndlessRPG project structure..."

# 1. Create Directory Hierarchy
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/assets/shaders
mkdir -p app/src/main/cpp

# 2. Generate Android Manifest (FIXES THE BUILD ERROR)
cat <<EOF > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.game.procedural">
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

# 3. Generate Root Configuration Files
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

# 4. Generate App Build Script (C++ & Graphics Support)
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

# 5. Generate UI Layout (Joystick & Viewport)
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

# 6. Generate MainActivity (Camera-Relative Movement Logic)
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
    private float camYaw = 0; // Rotational offset of the camera

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
        // --- CORRECTED CONTROLLER INPUT ---
        // Transform the 2D joystick input based on where the camera is looking.
        float cosY = (float) Math.cos(camYaw);
        float sinY = (float) Math.sin(camYaw);

        // This ensures "Forward" on the joystick always moves toward the horizon.
        float worldMoveX = (joyX * cosY) - (joyY * sinY);
        float worldMoveZ = (joyX * sinY) + (joyY * cosY);

        onDraw(worldMoveX, worldMoveZ, camYaw, System.currentTimeMillis() / 1000.0f);
    }
}
EOF

# 7. Generate Realism Shaders (Wind Sway & Atmospheric Fog)
cat <<EOF > app/src/main/assets/shaders/environment.vert
#version 300 es
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 aTex;
uniform mat4 uMVP;
uniform float uTime;
out vec2 vTex;
out float vFogDepth;

void main() {
    vec3 pos = aPos;
    // Real-world realism: Procedural wind sway for grass and trees
    if (pos.y > 0.1) {
        float sway = sin(uTime * 1.5 + pos.x) * (pos.y * 0.1);
        pos.x += sway;
    }
    gl_Position = uMVP * vec4(pos, 1.0);
    vTex = aTex;
    vFogDepth = -(uMVP * vec4(pos, 1.0)).z;
}
EOF

cat <<EOF > app/src/main/assets/shaders/environment.frag
#version 300 es
precision highp float;
in vec2 vTex;
in float vFogDepth;
uniform sampler2D uTexture;
out vec4 fragColor;

void main() {
    vec4 texColor = texture(uTexture, vTex);
    // Real-world atmosphere: Exponential fog for depth
    float fogFactor = exp(-pow(vFogDepth * 0.02, 2.0));
    vec3 fogColor = vec3(0.5, 0.6, 0.7); // Hazy forest blue
    fragColor = vec4(mix(fogColor, texColor.rgb, clamp(fogFactor, 0.0, 1.0)), texColor.a);
}
EOF

echo "[setup_project.sh] Complete. Ready for ./gradlew assembleDebug"
