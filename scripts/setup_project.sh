#!/bin/bash
# File: scripts/setup_project.sh

# --- Gradle Build Configurations ---
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
        externalNativeBuild { cmake { cppFlags "-std=c++17 -Ofast" } }
    }
    externalNativeBuild { cmake { path "src/main/cpp/CMakeLists.txt" } }
}
EOF

# --- CMake Configuration ---
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED engine.cpp)
find_library(log-lib log)
find_library(GLES3-lib GLESv3)
target_link_libraries(procedural_engine ${log-lib} ${GLES3-lib})
EOF

# --- Android Manifest ---
cat << 'EOF' > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-feature android:glEsVersion="0x00030000" android:required="true" />
    <application android:label="EndlessRPG" android:theme="@android:style/Theme.NoTitleBar.Fullscreen" android:hardwareAccelerated="true">
        <activity android:name=".MainActivity" android:exported="true" android:screenOrientation="landscape">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# --- Comprehensive UI Layout (XML FIXED) ---
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="match_parent">
    
    <android.opengl.GLSurfaceView android:id="@+id/gl_surface"
        android:layout_width="match_parent" android:layout_height="match_parent" />
    
    <RelativeLayout android:id="@+id/game_ui" android:layout_width="match_parent" android:layout_height="match_parent">
        
        <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content" 
            android:orientation="vertical" android:layout_alignParentRight="true" android:layout_margin="20dp" android:gravity="center">
            <Button android:id="@+id/btn_action" android:layout_width="80dp" android:layout_height="60dp" android:text="MENU" android:background="#88000000" android:textColor="#FFF"/>
            <ImageView android:id="@+id/img_compass" android:layout_width="60dp" android:layout_height="60dp" android:layout_marginTop="10dp" android:src="@android:drawable/ic_menu_compass" />
            <Button android:id="@+id/btn_compass_toggle" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Lock" android:background="#88000000" android:textColor="#FFF"/>
        </LinearLayout>

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
            <Button android:layout_width="100dp" android:layout_height="80dp" android:text="Status" android:layout_marginBottom="10dp"/>
            <Button android:layout_width="100dp" android:layout_height="80dp" android:text="Chest" android:layout_marginBottom="10dp"/>
            <Button android:id="@+id/btn_close_menu" android:layout_width="100dp" android:layout_height="80dp" android:text="Resume" android:textColor="#FF4444"/>
        </LinearLayout>
        <LinearLayout android:layout_width="0dp" android:layout_weight="1" android:layout_height="match_parent" android:orientation="vertical">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="INVENTORY &amp; LOADOUT" android:textColor="#FFF" android:textSize="24sp" android:textStyle="bold" />
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Manage your high-resolution assets here." android:textColor="#CCC" android:textSize="16sp" android:layout_marginTop="10dp"/>
        </LinearLayout>
    </LinearLayout>
</RelativeLayout>
EOF

# --- MainActivity (Java-to-C++ JNI Bridge) ---
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
    
    // Native Endpoints
    private native void onCreated();
    private native void onChanged(int width, int height);
    private native void onDraw();
    private native void updateInput(float dx, float dy);
    private native void updateCamera(float yaw, float zoom);
    private native void triggerAction(int actionId);
    private native float getCameraYaw();

    private View menuOverlay, gameUi;
    private ImageView knob, compassView;
    private boolean isCompassLocked = false;
    
    // Camera Tracking
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
        
        // Menu Interactions
        View.OnClickListener toggleMenu = v -> {
            boolean isMenuOpen = menuOverlay.getVisibility() == View.VISIBLE;
            menuOverlay.setVisibility(isMenuOpen ? View.GONE : View.VISIBLE);
            gameUi.setVisibility(isMenuOpen ? View.VISIBLE : View.GONE);
        };
        findViewById(R.id.btn_action).setOnClickListener(toggleMenu);
        findViewById(R.id.btn_close_menu).setOnClickListener(toggleMenu);

        // Compass Toggle Logic
        compassView = findViewById(R.id.img_compass);
        Button compassToggle = findViewById(R.id.btn_compass_toggle);
        compassToggle.setOnClickListener(v -> {
            isCompassLocked = !isCompassLocked;
            compassToggle.setText(isCompassLocked ? "Free" : "Lock");
            if (isCompassLocked) compassView.setRotation(0);
        });

        // Action Buttons
        findViewById(R.id.btn_sword).setOnClickListener(v -> triggerAction(1));
        findViewById(R.id.btn_jump).setOnClickListener(v -> triggerAction(4));
        findViewById(R.id.btn_shield).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) triggerAction(2);
            else if (e.getAction() == MotionEvent.ACTION_UP) triggerAction(3);
            return true;
        });

        // Advanced Camera Gestures
        scaleDetector = new ScaleGestureDetector(this, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
            @Override public boolean onScale(ScaleGestureDetector d) {
                camZoom /= d.getScaleFactor();
                camZoom = Math.max(5.0f, Math.min(40.0f, camZoom));
                updateCamera(camYaw, camZoom);
                return true;
            }
        });

        glView.setOnTouchListener((v, e) -> {
            scaleDetector.onTouchEvent(e);
            if (!scaleDetector.isInProgress() && e.getPointerCount() == 1 && e.getX() > v.getWidth() / 2f) {
                if (e.getAction() == MotionEvent.ACTION_DOWN) lastTouchX = e.getX();
                else if (e.getAction() == MotionEvent.ACTION_MOVE) {
                    camYaw += (e.getX() - lastTouchX) * 0.005f;
                    lastTouchX = e.getX();
                    updateCamera(camYaw, camZoom);
                }
            }
            return true;
        });

        // Precision Joystick
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
        if (menuOverlay.getVisibility() == View.GONE) {
            onDraw(); 
            if (!isCompassLocked) {
                final float yaw = getCameraYaw();
                runOnUiThread(() -> compassView.setRotation(-(float)Math.toDegrees(yaw)));
            }
        }
    }
}
EOF
