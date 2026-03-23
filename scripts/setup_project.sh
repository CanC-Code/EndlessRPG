#!/bin/bash
# File: scripts/setup_project.sh
# EndlessRPG v6 — Full project scaffold.
# Writes: AndroidManifest, Gradle files, CMakeLists, layout XML, MainActivity.java

echo "[setup_project.sh] Initializing EndlessRPG v6..."

mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/cpp

# ── 1. AndroidManifest ────────────────────────────────────────────
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

# ── 2. Gradle ─────────────────────────────────────────────────────
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

# ── 3. CMakeLists.txt — must match generate_engine.sh output ─────
# (generate_engine.sh also writes this; setup_project.sh writes it
#  first so the project scaffolds correctly before engine generation.)
cat <<EOF > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("game_engine")
add_library(game_engine SHARED native-lib.cpp)
find_library(log-lib log)
find_library(gles3-lib GLESv3)
target_link_libraries(game_engine \${log-lib} \${gles3-lib})
EOF

# ── 4. Layout: joystick bottom-left, action buttons bottom-right ──
cat <<EOF > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <!-- GL surface fills the screen -->
    <android.opengl.GLSurfaceView
        android:id="@+id/gl_surface_view"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <!-- Left: virtual joystick zone (200x200 dp, bottom-left) -->
    <View
        android:id="@+id/touch_zone_move"
        android:layout_width="200dp"
        android:layout_height="200dp"
        android:layout_gravity="bottom|left"
        android:background="#220000FF" />

    <!-- Right: camera orbit zone (everything to the right of the joystick) -->
    <View
        android:id="@+id/touch_zone_orbit"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:layout_marginLeft="200dp" />

</FrameLayout>
EOF

# ── 5. MainActivity.java ──────────────────────────────────────────
# Uses single-quote heredoc to prevent shell variable expansion.
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

    // ── Joystick state (left zone) ────────────────────────────────
    private float joyX = 0f, joyY = 0f;

    // ── Camera orbit state (right zone) ──────────────────────────
    private float camYaw   = 0.7f;   // radians — start slightly behind player
    private float camPitch = 0.35f;  // radians — 0=horizon, PI/2=top-down
    private float lastOrbitX = 0f, lastOrbitY = 0f;
    private boolean orbitTracking = false;

    // ── Pinch-to-zoom ─────────────────────────────────────────────
    private float camZoom = 12.0f;   // world units camera sits behind player
    private ScaleGestureDetector scaleDetector;

    // ── JNI — signatures MUST match native-lib.cpp extern "C" ────
    static { System.loadLibrary("game_engine"); }
    public native void  onCreated();
    public native void  onChanged(int w, int h);
    public native void  onDraw(float ix, float iy, float yaw, float pitch);
    public native void  triggerAction(int id);
    public native void  setZoom(float zoom);
    public native float getCameraYaw();
    public native float getStamina();
    public native float getHealth();
    public native void  setStamina(float v);

    @Override
    protected void onCreate(Bundle savedState) {
        super.onCreate(savedState);
        setContentView(R.layout.activity_main);

        // GL surface
        glView = findViewById(R.id.gl_surface_view);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);
        glView.setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);

        // Pinch-to-zoom detector (used inside the orbit zone touch handler)
        scaleDetector = new ScaleGestureDetector(this,
            new ScaleGestureDetector.SimpleOnScaleGestureListener() {
                @Override
                public boolean onScale(ScaleGestureDetector d) {
                    camZoom /= d.getScaleFactor();
                    camZoom = Math.max(4.0f, Math.min(40.0f, camZoom));
                    // Must call setZoom on the GL thread
                    glView.queueEvent(() -> setZoom(camZoom));
                    return true;
                }
            });

        // ── LEFT zone: virtual joystick ───────────────────────────
        // Touch position relative to zone centre → normalised -1..1
        // Clamped to unit circle so diagonals aren't faster.
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
                    float len = (float) Math.sqrt(joyX * joyX + joyY * joyY);
                    if (len > 1.0f) { joyX /= len; joyY /= len; }
                    break;
            }
            return true;
        });

        // ── RIGHT zone: camera orbit + pinch zoom ─────────────────
        // ACTION_DOWN records the start position so the first MOVE
        // delta is always zero — no jump on touch-down.
        // Pinch takes priority: orbit is disabled while pinching.
        findViewById(R.id.touch_zone_orbit).setOnTouchListener((v, e) -> {
            // Feed every event to the pinch detector first
            scaleDetector.onTouchEvent(e);

            if (scaleDetector.isInProgress()) {
                // Swallow orbit tracking during pinch
                orbitTracking = false;
                return true;
            }

            switch (e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    lastOrbitX   = e.getX();
                    lastOrbitY   = e.getY();
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
                        // Horizontal drag rotates yaw; vertical drag changes pitch
                        camYaw   -= dx * 0.008f;
                        camPitch -= dy * 0.008f;
                        // Clamp pitch: can't look underground or past straight-up
                        camPitch  = Math.max(0.05f, Math.min(1.45f, camPitch));
                        lastOrbitX = e.getX();
                        lastOrbitY = e.getY();
                    }
                    break;
            }
            return true;
        });
    }

    // ── GLSurfaceView.Renderer callbacks ─────────────────────────
    @Override
    public void onSurfaceCreated(GL10 gl, EGLConfig cfg) {
        onCreated();
        setZoom(camZoom);   // push initial zoom into engine state
    }

    @Override
    public void onSurfaceChanged(GL10 gl, int w, int h) {
        onChanged(w, h);
    }

    @Override
    public void onDrawFrame(GL10 gl) {
        // joyX = right(+1)/left(-1) on screen
        // joyY = down(+1)/up(-1) on screen — negate so up = forward
        // C++ engine applies camYaw rotation internally to get world-space direction
        onDraw(joyX, -joyY, camYaw, camPitch);
    }
}
EOF

echo "[setup_project.sh] Complete."
