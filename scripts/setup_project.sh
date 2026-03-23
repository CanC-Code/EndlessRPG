#!/bin/bash
# File: scripts/setup_project.sh
# Scaffolds all Android Gradle, Manifest, Layout, and Java files.

set -e

# --- Gradle Build Configurations ---
cat << 'EOF' > settings.gradle
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "EndlessRPG"
include ':app'
EOF

cat << 'EOF' > build.gradle
plugins { id 'com.android.application' version '8.3.0' apply false }
EOF

cat << 'EOF' > gradle.properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
EOF

cat << 'EOF' > app/build.gradle
plugins { id 'com.android.application' }
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
            cmake { cppFlags "-std=c++17 -O2" }
        }
    }
    externalNativeBuild { cmake { path "src/main/cpp/CMakeLists.txt" } }
    buildTypes {
        release { minifyEnabled false }
    }
}
EOF

# --- CMake Configuration ---
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
find_library(log-lib log)
find_library(GLES3-lib GLESv3)
target_link_libraries(procedural_engine ${log-lib} ${GLES3-lib})
EOF

# --- Android Manifest ---
cat << 'EOF' > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-feature android:glEsVersion="0x00030000" android:required="true" />
    <application
        android:label="EndlessRPG"
        android:theme="@android:style/Theme.NoTitleBar.Fullscreen"
        android:hardwareAccelerated="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:screenOrientation="landscape"
            android:configChanges="orientation|screenSize|keyboardHidden">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# --- Polished HUD Layout ---
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#FF000000">

    <!-- OpenGL Surface -->
    <android.opengl.GLSurfaceView
        android:id="@+id/game_surface"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <!-- HUD Overlay -->
    <RelativeLayout
        android:id="@+id/hud_overlay"
        android:layout_width="match_parent"
        android:layout_height="match_parent">

        <!-- Health Bar (top-left) -->
        <LinearLayout
            android:layout_width="180dp"
            android:layout_height="wrap_content"
            android:orientation="vertical"
            android:layout_margin="14dp"
            android:layout_alignParentTop="true"
            android:layout_alignParentLeft="true">
            <TextView
                android:id="@+id/tv_health_label"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="HP"
                android:textColor="#FFFFFFFF"
                android:textSize="11sp"
                android:textStyle="bold"
                android:shadowColor="#AA000000"
                android:shadowDx="1" android:shadowDy="1" android:shadowRadius="2"/>
            <FrameLayout
                android:layout_width="match_parent"
                android:layout_height="10dp"
                android:background="#55000000">
                <View
                    android:id="@+id/health_bar"
                    android:layout_width="match_parent"
                    android:layout_height="match_parent"
                    android:background="#FF3333" />
            </FrameLayout>
            <TextView
                android:id="@+id/tv_stamina_label"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="STA"
                android:textColor="#FFFFFFFF"
                android:textSize="11sp"
                android:textStyle="bold"
                android:layout_marginTop="4dp"
                android:shadowColor="#AA000000"
                android:shadowDx="1" android:shadowDy="1" android:shadowRadius="2"/>
            <FrameLayout
                android:layout_width="match_parent"
                android:layout_height="10dp"
                android:background="#55000000">
                <View
                    android:id="@+id/stamina_bar"
                    android:layout_width="match_parent"
                    android:layout_height="match_parent"
                    android:background="#33CC33" />
            </FrameLayout>
        </LinearLayout>

        <!-- Top-right controls: MENU + Compass -->
        <LinearLayout
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:orientation="vertical"
            android:layout_alignParentTop="true"
            android:layout_alignParentRight="true"
            android:layout_margin="14dp"
            android:gravity="center">
            <Button
                android:id="@+id/btn_menu"
                android:layout_width="72dp"
                android:layout_height="44dp"
                android:text="MENU"
                android:textSize="12sp"
                android:textColor="#FFFFFFFF"
                android:background="#AA111111" />
            <ImageView
                android:id="@+id/img_compass"
                android:layout_width="48dp"
                android:layout_height="48dp"
                android:layout_marginTop="8dp"
                android:src="@android:drawable/ic_menu_compass" />
            <Button
                android:id="@+id/btn_compass_toggle"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="Lock"
                android:textSize="11sp"
                android:textColor="#FFFFFFFF"
                android:background="#AA111111" />
        </LinearLayout>

        <!-- Action buttons: bottom-right (Attack, Block, Jump) -->
        <Button
            android:id="@+id/btn_sword"
            android:layout_width="80dp"
            android:layout_height="80dp"
            android:layout_alignParentBottom="true"
            android:layout_alignParentRight="true"
            android:layout_margin="24dp"
            android:text="Attack"
            android:textColor="#FFFFFFFF"
            android:background="#AA3355AA" />

        <Button
            android:id="@+id/btn_shield"
            android:layout_width="80dp"
            android:layout_height="80dp"
            android:layout_above="@id/btn_sword"
            android:layout_alignParentRight="true"
            android:layout_marginRight="24dp"
            android:layout_marginBottom="8dp"
            android:text="Block"
            android:textColor="#FFFFFFFF"
            android:background="#AA7755AA" />

        <Button
            android:id="@+id/btn_jump"
            android:layout_width="80dp"
            android:layout_height="80dp"
            android:layout_alignParentBottom="true"
            android:layout_toLeftOf="@id/btn_sword"
            android:layout_marginBottom="24dp"
            android:layout_marginRight="8dp"
            android:text="Jump"
            android:textColor="#FFFFFFFF"
            android:background="#AA556633" />

        <!-- Virtual Joystick (bottom-left) -->
        <RelativeLayout
            android:id="@+id/joystick_bg"
            android:layout_width="130dp"
            android:layout_height="130dp"
            android:layout_alignParentBottom="true"
            android:layout_alignParentLeft="true"
            android:layout_margin="24dp"
            android:background="#44FFFFFF">
            <ImageView
                android:id="@+id/joystick_knob"
                android:layout_width="48dp"
                android:layout_height="48dp"
                android:layout_centerInParent="true"
                android:background="#99FFFFFF" />
        </RelativeLayout>

    </RelativeLayout>

    <!-- Menu Overlay (hidden by default) -->
    <LinearLayout
        android:id="@+id/menu_overlay"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:orientation="horizontal"
        android:background="#DD060606"
        android:padding="24dp"
        android:visibility="gone">

        <!-- Sidebar buttons -->
        <LinearLayout
            android:layout_width="110dp"
            android:layout_height="match_parent"
            android:orientation="vertical"
            android:layout_marginRight="20dp">
            <Button
                android:layout_width="match_parent"
                android:layout_height="64dp"
                android:text="Status"
                android:layout_marginBottom="10dp"
                android:background="#AA3355AA"
                android:textColor="#FFF"/>
            <Button
                android:layout_width="match_parent"
                android:layout_height="64dp"
                android:text="Chest"
                android:layout_marginBottom="10dp"
                android:background="#AA3355AA"
                android:textColor="#FFF"/>
            <Button
                android:layout_width="match_parent"
                android:layout_height="64dp"
                android:text="Settings"
                android:layout_marginBottom="10dp"
                android:background="#AA3355AA"
                android:textColor="#FFF"/>
            <Button
                android:id="@+id/btn_close_menu"
                android:layout_width="match_parent"
                android:layout_height="64dp"
                android:text="Resume"
                android:textColor="#FF6666"
                android:background="#AA220000"/>
        </LinearLayout>

        <!-- Content panel -->
        <LinearLayout
            android:layout_width="0dp"
            android:layout_weight="1"
            android:layout_height="match_parent"
            android:orientation="vertical">
            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="INVENTORY &amp; LOADOUT"
                android:textColor="#FFFFFFFF"
                android:textSize="22sp"
                android:textStyle="bold" />
            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="Equip weapons and manage your gear."
                android:textColor="#BBBBBB"
                android:textSize="15sp"
                android:layout_marginTop="10dp"/>
        </LinearLayout>
    </LinearLayout>

</RelativeLayout>
EOF

# --- MainActivity (Java) ---
cat << 'EOF' > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;

import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity implements GLSurfaceView.Renderer {

    static { System.loadLibrary("procedural_engine"); }

    // JNI native methods
    private native void onCreated();
    private native void onChanged(int width, int height);
    private native void onDraw(float ix, float iy, float yaw, float pitch, float zoom);
    private native void triggerAction(int actionId);
    private native float getCameraYaw();

    private GLSurfaceView glView;
    private View menuOverlay, hudOverlay;
    private ImageView joystickKnob, compassView;
    private boolean isCompassLocked = false;

    // Camera state
    private ScaleGestureDetector scaleDetector;
    private float camYaw   = 0.7f;
    private float camPitch = 0.45f;
    private float camZoom  = 13.0f;
    private float lastTouchX, lastTouchY;

    // Joystick input
    private float joystickX = 0f, joystickY = 0f;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        glView = findViewById(R.id.game_surface);
        glView.setEGLContextClientVersion(3);
        glView.setEGLConfigChooser(8, 8, 8, 8, 24, 8); // 24-bit depth, 8-bit stencil
        glView.setRenderer(this);
        glView.setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);

        hudOverlay  = findViewById(R.id.hud_overlay);
        menuOverlay = findViewById(R.id.menu_overlay);

        // --- Menu toggle ---
        View.OnClickListener toggleMenu = v -> {
            boolean open = menuOverlay.getVisibility() == View.VISIBLE;
            menuOverlay.setVisibility(open ? View.GONE  : View.VISIBLE);
            hudOverlay .setVisibility(open ? View.VISIBLE : View.GONE);
        };
        findViewById(R.id.btn_menu).setOnClickListener(toggleMenu);
        findViewById(R.id.btn_close_menu).setOnClickListener(toggleMenu);

        // --- Compass ---
        compassView = findViewById(R.id.img_compass);
        Button compassToggle = findViewById(R.id.btn_compass_toggle);
        compassToggle.setOnClickListener(v -> {
            isCompassLocked = !isCompassLocked;
            compassToggle.setText(isCompassLocked ? "Free" : "Lock");
            if (isCompassLocked) compassView.setRotation(0f);
        });

        // --- Combat buttons ---
        findViewById(R.id.btn_sword).setOnClickListener(v -> triggerAction(1));
        findViewById(R.id.btn_jump) .setOnClickListener(v -> triggerAction(4));
        findViewById(R.id.btn_shield).setOnTouchListener((v, e) -> {
            if      (e.getAction() == MotionEvent.ACTION_DOWN) triggerAction(2);
            else if (e.getAction() == MotionEvent.ACTION_UP)   triggerAction(3);
            return true;
        });

        // --- Pinch-to-zoom + swipe-to-orbit camera ---
        scaleDetector = new ScaleGestureDetector(this,
            new ScaleGestureDetector.SimpleOnScaleGestureListener() {
                @Override public boolean onScale(ScaleGestureDetector d) {
                    camZoom /= d.getScaleFactor();
                    camZoom = Math.max(4.0f, Math.min(30.0f, camZoom));
                    return true;
                }
            });

        glView.setOnTouchListener((v, e) -> {
            scaleDetector.onTouchEvent(e);
            if (!scaleDetector.isInProgress()
                    && e.getPointerCount() == 1
                    && e.getX() > v.getWidth() / 2f) {
                if (e.getAction() == MotionEvent.ACTION_DOWN) {
                    lastTouchX = e.getX(); lastTouchY = e.getY();
                } else if (e.getAction() == MotionEvent.ACTION_MOVE) {
                    camYaw   += (e.getX() - lastTouchX) * 0.008f;
                    camPitch  = Math.max(0.1f, Math.min(1.4f,
                                camPitch + (e.getY() - lastTouchY) * 0.008f));
                    lastTouchX = e.getX(); lastTouchY = e.getY();
                }
            }
            return true;
        });

        // --- Joystick ---
        joystickKnob = findViewById(R.id.joystick_knob);
        View joystickBg = findViewById(R.id.joystick_bg);
        joystickBg.setOnTouchListener((v, e) -> {
            final float radius = v.getWidth() / 2f;
            switch (e.getAction()) {
                case MotionEvent.ACTION_DOWN:
                case MotionEvent.ACTION_MOVE: {
                    float dx = e.getX() - radius;
                    float dy = e.getY() - radius;
                    float dist = (float) Math.hypot(dx, dy);
                    if (dist > radius) { dx *= radius / dist; dy *= radius / dist; }
                    joystickKnob.setTranslationX(dx);
                    joystickKnob.setTranslationY(dy);
                    joystickX = dx / radius;
                    joystickY = dy / radius;
                    break;
                }
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    joystickKnob.setTranslationX(0); joystickKnob.setTranslationY(0);
                    joystickX = 0f; joystickY = 0f;
                    break;
            }
            return true;
        });
    }

    // GLSurfaceView.Renderer callbacks — called on GL thread
    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }
    @Override public void onDrawFrame(GL10 gl) {
        if (menuOverlay.getVisibility() == View.GONE) {
            onDraw(joystickX, joystickY, camYaw, camPitch, camZoom);
            if (!isCompassLocked) {
                final float yaw = getCameraYaw();
                runOnUiThread(() -> compassView.setRotation(-(float) Math.toDegrees(yaw)));
            }
        }
    }

    @Override protected void onResume() { super.onResume(); glView.onResume(); }
    @Override protected void onPause()  { super.onPause();  glView.onPause();  }
}
EOF

echo "[setup_project.sh] Done."
