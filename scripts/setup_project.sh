#!/bin/bash
# File: scripts/setup_project.sh

mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/cpp

# --- Gradle Configurations ---
cat << 'EOF' > settings.gradle
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
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
        externalNativeBuild { cmake { cppFlags "-std=c++17" } }
    }
    externalNativeBuild { cmake { path "src/main/cpp/CMakeLists.txt" } }
}
EOF

cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED engine.cpp)
find_library(log-lib log)
find_library(GLES3-lib GLESv3)
target_link_libraries(procedural_engine ${log-lib} ${GLES3-lib})
EOF

cat << 'EOF' > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-feature android:glEsVersion="0x00030000" android:required="true" />
    <application android:label="EndlessRPG" android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name=".MainActivity" android:exported="true" android:screenOrientation="landscape">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# --- Restored Layout (Includes Inventory Overlay & Action Buttons) ---
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="match_parent">
    
    <android.opengl.GLSurfaceView android:id="@+id/gl_surface"
        android:layout_width="match_parent" android:layout_height="match_parent" />
    
    <RelativeLayout android:id="@+id/game_ui" android:layout_width="match_parent" android:layout_height="match_parent">
        <Button android:id="@+id/btn_action" android:layout_width="80dp" android:layout_height="80dp"
            android:layout_alignParentTop="true" android:layout_alignParentRight="true" android:layout_margin="20dp" android:text="Menu" />

        <Button android:id="@+id/btn_sword" android:layout_width="80dp" android:layout_height="80dp"
            android:layout_alignParentBottom="true" android:layout_alignParentRight="true" android:layout_margin="30dp" android:text="Attack" />
        <Button android:id="@+id/btn_shield" android:layout_width="80dp" android:layout_height="80dp"
            android:layout_above="@id/btn_sword" android:layout_alignParentRight="true" android:layout_marginRight="30dp" android:layout_marginBottom="10dp" android:text="Block" />
        <Button android:id="@+id/btn_jump" android:layout_width="80dp" android:layout_height="80dp"
            android:layout_alignParentBottom="true" android:layout_toLeftOf="@id/btn_sword" android:layout_marginBottom="30dp" android:layout_marginRight="10dp" android:text="Jump" />

        <RelativeLayout android:layout_width="140dp" android:layout_height="140dp" android:layout_alignParentBottom="true" android:layout_margin="30dp">
            <ImageView android:id="@+id/joystick_bg" android:layout_width="match_parent" android:layout_height="match_parent" android:background="#44FFFFFF"/>
            <ImageView android:id="@+id/joystick_knob" android:layout_width="50dp" android:layout_height="50dp" android:layout_centerInParent="true" android:background="#88FFFFFF" />
        </RelativeLayout>
    </RelativeLayout>

    <LinearLayout android:id="@+id/menu_overlay" android:layout_width="match_parent" android:layout_height="match_parent"
        android:orientation="horizontal" android:background="#DD000000" android:padding="20dp" android:visibility="gone">
        <LinearLayout android:layout_width="wrap_content" android:layout_height="match_parent" android:orientation="vertical" android:layout_marginRight="20dp">
            <Button android:layout_width="80dp" android:layout_height="80dp" android:text="Status" android:layout_marginBottom="10dp"/>
            <Button android:layout_width="80dp" android:layout_height="80dp" android:text="Chest" android:layout_marginBottom="10dp"/>
        </LinearLayout>
        <LinearLayout android:layout_width="0dp" android:layout_weight="1" android:layout_height="match_parent" android:orientation="vertical">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="INVENTORY" android:textColor="#FFF" android:textSize="24sp" android:textStyle="bold" />
        </LinearLayout>
    </LinearLayout>
</RelativeLayout>
EOF

# --- Restored MainActivity (Camera Gestures, Menu Toggle, Joystick) ---
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
    
    private native void onCreated();
    private native void onChanged(int width, int height);
    private native void onDraw();
    private native void updateInput(float dx, float dy);
    private native void updateCamera(float yaw, float zoom);
    private native void triggerAction(int actionId);

    private View menuOverlay, gameUi;
    private ImageView knob;
    
    // Restored Camera State
    private ScaleGestureDetector scaleDetector;
    private float camZoom = 15.0f;
    private float camYaw = 0.0f;
    private float lastTouchX;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        GLSurfaceView glView = findViewById(R.id.gl_surface);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);

        menuOverlay = findViewById(R.id.menu_overlay);
        gameUi = findViewById(R.id.game_ui);
        
        // Menu Toggle
        findViewById(R.id.btn_action).setOnClickListener(v -> {
            boolean isMenuOpen = menuOverlay.getVisibility() == View.VISIBLE;
            menuOverlay.setVisibility(isMenuOpen ? View.GONE : View.VISIBLE);
            gameUi.setVisibility(isMenuOpen ? View.VISIBLE : View.GONE);
        });

        // Actions
        findViewById(R.id.btn_sword).setOnClickListener(v -> triggerAction(1));
        findViewById(R.id.btn_jump).setOnClickListener(v -> triggerAction(4));

        // Restored Camera Gestures
        scaleDetector = new ScaleGestureDetector(this, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
            @Override public boolean onScale(ScaleGestureDetector d) {
                camZoom /= d.getScaleFactor();
                camZoom = Math.max(5.0f, Math.min(35.0f, camZoom));
                updateCamera(camYaw, camZoom);
                return true;
            }
        });

        glView.setOnTouchListener((v, e) -> {
            scaleDetector.onTouchEvent(e);
            if (!scaleDetector.isInProgress() && e.getPointerCount() == 1 && e.getX() > v.getWidth() / 2f) {
                if (e.getAction() == MotionEvent.ACTION_DOWN) lastTouchX = e.getX();
                else if (e.getAction() == MotionEvent.ACTION_MOVE) {
                    camYaw += (e.getX() - lastTouchX) * 0.01f;
                    lastTouchX = e.getX();
                    updateCamera(camYaw, camZoom);
                }
            }
            return true;
        });

        // Joystick
        knob = findViewById(R.id.joystick_knob);
        findViewById(R.id.joystick_bg).setOnTouchListener((v, e) -> {
            float radius = 70f;
            if (e.getAction() == MotionEvent.ACTION_MOVE || e.getAction() == MotionEvent.ACTION_DOWN) {
                float dx = e.getX() - radius; float dy = e.getY() - radius;
                float dist = (float) Math.hypot(dx, dy);
                if (dist > radius) { dx *= (radius / dist); dy *= (radius / dist); }
                knob.setTranslationX(dx); knob.setTranslationY(dy);
                updateInput(dx / radius, dy / radius);
            } else if (e.getAction() == MotionEvent.ACTION_UP) {
                knob.setTranslationX(0); knob.setTranslationY(0);
                updateInput(0f, 0f);
            }
            return true;
        });
    }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); updateCamera(camYaw, camZoom); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }
    @Override public void onDrawFrame(GL10 gl) { 
        if (menuOverlay.getVisibility() == View.GONE) onDraw(); 
    }
}
EOF
