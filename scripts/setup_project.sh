#!/bin/bash
# File: scripts/setup_project.sh

# 1. Create directory structure
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/cpp

# 2. Generate Gradle Build Files
cat << 'EOF' > settings.gradle
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "EndlessRPG"
include ':app'
EOF

cat << 'EOF' > build.gradle
plugins {
    id 'com.android.application' version '8.3.0' apply false
}
EOF

cat << 'EOF' > gradle.properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
EOF

cat << 'EOF' > app/build.gradle
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

    externalNativeBuild {
        cmake {
            path "src/main/cpp/CMakeLists.txt"
            version "3.22.1"
        }
    }
}
EOF

# 3. Generate CMake config for the C++ Engine
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")

add_library(procedural_engine SHARED engine.cpp)

find_library(log-lib log)
find_library(GLES3-lib GLESv3)
find_library(EGL-lib EGL)

target_link_libraries(procedural_engine ${log-lib} ${GLES3-lib} ${EGL-lib})
EOF

# 4. Generate Android Manifest (Fixed namespace)
cat << 'EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-feature android:glEsVersion="0x00030000" android:required="true" />
    <application
        android:allowBackup="true"
        android:label="Endless RPG"
        android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name=".MainActivity"
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

# 5. Generate UI Layout (Fixed Joystick alignment error)
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <android.opengl.GLSurfaceView
        android:id="@+id/gl_surface"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <RelativeLayout
        android:id="@+id/game_ui"
        android:layout_width="match_parent"
        android:layout_height="match_parent">

        <ImageView
            android:id="@+id/img_compass"
            android:layout_width="60dp"
            android:layout_height="60dp"
            android:layout_alignParentTop="true"
            android:layout_alignParentRight="true"
            android:layout_marginTop="24dp"
            android:layout_marginRight="24dp"
            android:src="@android:drawable/ic_menu_compass" /> 

        <Button
            android:id="@+id/btn_compass_toggle"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_below="@id/img_compass"
            android:layout_alignParentRight="true"
            android:layout_marginRight="16dp"
            android:text="Lock"
            android:background="#88000000"
            android:textColor="#FFFFFF" />

        <Button
            android:id="@+id/btn_sword"
            android:layout_width="80dp"
            android:layout_height="80dp"
            android:layout_alignParentBottom="true"
            android:layout_alignParentRight="true"
            android:layout_marginBottom="32dp"
            android:layout_marginRight="32dp"
            android:text="Attack" />

        <Button
            android:id="@+id/btn_shield"
            android:layout_width="80dp"
            android:layout_height="80dp"
            android:layout_above="@id/btn_sword"
            android:layout_alignParentRight="true"
            android:layout_marginBottom="16dp"
            android:layout_marginRight="32dp"
            android:text="Block" />

        <Button
            android:id="@+id/btn_jump"
            android:layout_width="80dp"
            android:layout_height="80dp"
            android:layout_alignParentBottom="true"
            android:layout_toLeftOf="@id/btn_sword"
            android:layout_marginBottom="32dp"
            android:layout_marginRight="16dp"
            android:text="Jump" />
            
        <Button
            android:id="@+id/btn_action"
            android:layout_width="80dp"
            android:layout_height="80dp"
            android:layout_above="@id/btn_jump"
            android:layout_toLeftOf="@id/btn_shield"
            android:layout_marginBottom="16dp"
            android:layout_marginRight="16dp"
            android:text="Action" />

        <RelativeLayout
            android:layout_width="120dp"
            android:layout_height="120dp"
            android:layout_alignParentBottom="true"
            android:layout_alignParentLeft="true"
            android:layout_marginBottom="32dp"
            android:layout_marginLeft="32dp">

            <ImageView
                android:id="@+id/joystick_bg"
                android:layout_width="match_parent"
                android:layout_height="match_parent"
                android:background="#44FFFFFF"/>

            <ImageView
                android:id="@+id/joystick_knob"
                android:layout_width="50dp"
                android:layout_height="50dp"
                android:layout_centerInParent="true"
                android:background="#88FFFFFF" />
        </RelativeLayout>
            
    </RelativeLayout>

    <LinearLayout
        android:id="@+id/menu_overlay"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:orientation="horizontal"
        android:background="#AA000000"
        android:padding="20dp"
        android:visibility="gone">

        <LinearLayout
            android:id="@+id/left_menu"
            android:layout_width="wrap_content"
            android:layout_height="match_parent"
            android:orientation="vertical"
            android:layout_marginRight="20dp">
            
            <Button
                android:layout_width="80dp"
                android:layout_height="80dp"
                android:text="Status"
                android:textColor="#AAA"
                android:layout_marginBottom="10dp"/>
            <Button
                android:layout_width="80dp"
                android:layout_height="80dp"
                android:text="Chest"
                android:textColor="#AAA"
                android:layout_marginBottom="10dp"/>
        </LinearLayout>

        <LinearLayout
            android:layout_width="0dp"
            android:layout_weight="1"
            android:layout_height="match_parent"
            android:orientation="vertical">
            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="INVENTORY"
                android:textColor="#FFF"
                android:textSize="20sp"
                android:textStyle="bold"
                android:layout_marginBottom="10dp"/>
        </LinearLayout>
    </LinearLayout>

</RelativeLayout>
EOF

# 6. Generate Main Java Activity
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
    private native void triggerAction(int actionId);
    private native void updateInput(float dx, float dy);
    private native float getCameraYaw(); 

    private GLSurfaceView glView;
    private View menuOverlay;
    private View gameUi;
    
    private ImageView knob;
    private float tX = 0f, tY = 0f;
    private long shieldDownTime = 0;
    
    private ScaleGestureDetector scaleDetector;
    private float camZoom = 15.0f;
    private float camYaw = 0.0f;
    private float lastTouchX, lastTouchY;
    
    private ImageView compassView;
    private Button compassToggleBtn;
    private boolean isCompassLocked = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        glView = findViewById(R.id.gl_surface);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);

        menuOverlay = findViewById(R.id.menu_overlay);
        gameUi = findViewById(R.id.game_ui);
        knob = findViewById(R.id.joystick_knob);
        
        compassView = findViewById(R.id.img_compass);
        compassToggleBtn = findViewById(R.id.btn_compass_toggle);
        
        compassToggleBtn.setOnClickListener(v -> {
            isCompassLocked = !isCompassLocked;
            if (isCompassLocked) {
                compassToggleBtn.setText("Free");
                compassView.setRotation(0f);
            } else {
                compassToggleBtn.setText("Lock");
            }
        });

        scaleDetector = new ScaleGestureDetector(this, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
            @Override
            public boolean onScale(ScaleGestureDetector d) {
                camZoom /= d.getScaleFactor();
                camZoom = Math.max(4.0f, Math.min(30.0f, camZoom));
                return true;
            }
        });

        glView.setOnTouchListener((v, e) -> {
            scaleDetector.onTouchEvent(e);
            if (!scaleDetector.isInProgress() && e.getPointerCount() == 1 && e.getX() > v.getWidth()/2f) {
                if (e.getAction() == MotionEvent.ACTION_DOWN) {
                    lastTouchX = e.getX();
                    lastTouchY = e.getY();
                } else if (e.getAction() == MotionEvent.ACTION_MOVE) {
                    camYaw += (e.getX() - lastTouchX) * 0.01f;
                    lastTouchX = e.getX();
                    lastTouchY = e.getY();
                }
            }
            return true;
        });

        findViewById(R.id.joystick_bg).setOnTouchListener((v, e) -> {
            float radius = 60f; 
            if (e.getAction() == MotionEvent.ACTION_MOVE || e.getAction() == MotionEvent.ACTION_DOWN) {
                float dx = e.getX() - radius; 
                float dy = e.getY() - radius;
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
        
        findViewById(R.id.btn_sword).setOnClickListener(v -> triggerAction(1));
        findViewById(R.id.btn_jump).setOnClickListener(v -> triggerAction(4));
        
        findViewById(R.id.btn_action).setOnClickListener(v -> {
            if (menuOverlay.getVisibility() == View.GONE) {
                menuOverlay.setVisibility(View.VISIBLE);
                gameUi.setVisibility(View.GONE);
            } else {
                menuOverlay.setVisibility(View.GONE);
                gameUi.setVisibility(View.VISIBLE);
            }
        });

        findViewById(R.id.btn_shield).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) {
                shieldDownTime = System.currentTimeMillis();
                triggerAction(2);
            } else if (e.getAction() == MotionEvent.ACTION_UP) {
                triggerAction(3);
                if (System.currentTimeMillis() - shieldDownTime < 300) triggerAction(6);
            }
            return true;
        });
    }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }
    
    @Override 
    public void onDrawFrame(GL10 gl) { 
        if (menuOverlay.getVisibility() == View.VISIBLE) return;
        
        onDraw(); 
        if (!isCompassLocked) {
            float currentYaw = getCameraYaw();
            runOnUiThread(() -> {
                compassView.setRotation(-(float)Math.toDegrees(currentYaw)); 
            });
        }
    }
}
EOF
