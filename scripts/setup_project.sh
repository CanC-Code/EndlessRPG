#!/bin/bash
# File: scripts/setup_project.sh
# Purpose: Full project scaffold — EndlessRPG v6
#   - Fixed MainActivity: correct onDraw signature (no time/zoom args),
#     working joystick, camera orbit with ACTION_DOWN tracking, pinch-to-zoom
#   - CMakeLists.txt compiles native-lib.cpp (not the old engine.cpp stub)

echo "[setup_project.sh] Initializing EndlessRPG v6 project structure..."

mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/cpp

# ── 1. Android Manifest ───────────────────────────────────────────
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

# ── 2. Gradle configs ─────────────────────────────────────────────
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

# ── 3. CMakeLists.txt — compiles native-lib.cpp (NOT engine.cpp) ──
cat <<EOF > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("game_engine")
add_library(game_engine SHARED native-lib.cpp)
find_library(log-lib log)
find_library(gles3-lib GLESv3)
target_link_libraries(game_engine \${log-lib} \${gles3-lib})
EOF

# ── 4. UI Layout — joystick left, orbit zone right ────────────────
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

# ── 5. MainActivity.java ──────────────────────────────────────────
# Key fixes vs old version:
#   - onDraw signature: (float ix, float iy, float yaw, float pitch)
#     — no 'time' arg (engine increments g_time internally)
#     — no 'zoom' arg (zoom is persistent engine state, set via setZoom())
#   - setZoom() native method added; called on surface create + pinch
#   - Joystick: clamped to unit circle, ACTION_CANCEL handled
#   - Orbit: ACTION_DOWN now captures lastX/lastY before first MOVE,
#     preventing a jump on first touch
#   - camPitch clamped 0.05..1.45 (no underground camera)
#   - Pinch-to-zoom via ScaleGestureDetector on the orbit zone
cat <<'EOF' > app/src/main/java/com/game/procedural/MainActivity.java
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

    // Joystick (left zone)
    private float joyX = 0f, joyY = 0f;

    // Camera orbit (right zone)
    private float camYaw = 0.7f, camPitch = 0.35f;
    private float lastOrbitX = 0f, lastOrbitY = 0f;
    private boolean orbitTracking = false;

    // Zoom (pinch)
    private float camZoom = 12.0f;
    private ScaleGestureDetector scaleDetector;

    static { System.loadLibrary("game_engine"); }

    // JNI — must match native-lib.cpp extern "C" signatures exactly
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
    protected void onCreate(Bundle savedState) {
        super.onCreate(savedState);
        setContentView(R.layout.activity_main);

        glView = findViewById(R.id.gl_surface_view);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);
        glView.setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);

        // Pinch-to-zoom detector — attached to the orbit zone
        scaleDetector = new ScaleGestureDetector(this,
            new ScaleGestureDetector.SimpleOnScaleGestureListener() {
                @Override
                public boolean onScale(ScaleGestureDetector d) {
                    camZoom /= d.getScaleFactor();
                    camZoom = Math.max(4.0f, Math.min(40.0f, camZoom));
                    // Push zoom to engine on GL thread
                    glView.queueEvent(() -> setZoom(camZoom));
                    return true;
                }
            });

        // ── LEFT zone: virtual joystick ──────────────────────────
        findViewById(R.id.touch_zone_move).setOnTouchListener((v, e) -> {
            switch (e.getActionMasked()) {
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    joyX = 0f;
                    joyY = 0f;
                    break;
                default:
                    joyX = (e.getX() - v.getWidth()  * 0.5f) / (v.getWidth()  * 0.5f);
                    joyY = (e.getY() - v.getHeight() * 0.5f) / (v.getHeight() * 0.5f);
                    // Clamp to unit circle so diagonal isn't faster
                    float len = (float) Math.sqrt(joyX * joyX + joyY * joyY);
                    if (len > 1.0f) { joyX /= len; joyY /= len; }
                    break;
            }
            return true;
        });

        // ── RIGHT zone: camera orbit + pinch zoom ─────────────────
        findViewById(R.id.touch_zone_orbit).setOnTouchListener((v, e) -> {
            // Always feed pinch detector first
            scaleDetector.onTouchEvent(e);

            // Don't orbit while pinching
            if (scaleDetector.isInProgress()) {
                orbitTracking = false;
                return true;
            }

            switch (e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    lastOrbitX = e.getX();
                    lastOrbitY = e.getY();
                    orbitTracking = true;
                    break;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    orbitTracking = false;
                    break;
                case MotionEvent.ACTION_MOVE:
                    if (orbitTracking) {
                        float dx = e.getX() - lastOrbitX;
                        float dy = e.getY() - lastOrbitY;
                        camYaw   -= dx * 0.008f;
                        camPitch -= dy * 0.008f;
                        // No underground camera, no past straight up
                        camPitch = Math.max(0.05f, Math.min(1.45f, camPitch));
                        lastOrbitX = e.getX();
                        lastOrbitY = e.getY();
                    }
                    break;
            }
            return true;
        });
    }

    @Override
    public void onSurfaceCreated(GL10 gl, EGLConfig cfg) {
        onCreated();
        setZoom(camZoom);   // push initial zoom to engine
    }

    @Override
    public void onSurfaceChanged(GL10 gl, int w, int h) {
        onChanged(w, h);
    }

    @Override
    public void onDrawFrame(GL10 gl) {
        // joyX/joyY are joystick-local (+X=right, +Y=down on screen).
        // Pass -joyY so pushing stick forward (screen-up) moves character forward.
        // C++ engine rotates these into world space using camYaw internally.
        onDraw(joyX, -joyY, camYaw, camPitch);
    }
}
EOF

echo "[setup_project.sh] Deployment complete."
