#!/bin/bash
# File: scripts/setup_project.sh
# Scaffolding Full Feature Engine & Gradle

set -e
echo "[setup_project.sh] Scaffolding Full Feature Engine & Gradle..."

cat << 'EOF' > settings.gradle
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
include ':app'
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

cat << 'EOF' > app/src/main/res/drawable/btn_bg.xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="#88000000"/>
    <stroke android:width="2dp" android:color="#AAFFFFFF"/>
</shape>
EOF

cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <android.opengl.GLSurfaceView
        android:id="@+id/gl_surface_view"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <RelativeLayout
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:padding="32dp">

        <View
            android:id="@+id/joystick_area"
            android:layout_width="160dp"
            android:layout_height="160dp"
            android:layout_alignParentBottom="true"
            android:layout_alignParentLeft="true"
            android:background="@drawable/btn_bg" />

        <GridLayout
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_alignParentBottom="true"
            android:layout_alignParentRight="true"
            android:layout_margin="30dp"
            android:columnCount="2"
            android:rowCount="2">

            <Button android:id="@+id/btn_action" android:layout_width="65dp" android:layout_height="65dp" android:layout_margin="5dp" android:text="🖐" android:textSize="20sp" android:background="@drawable/btn_bg" />
            <Button android:id="@+id/btn_shield" android:layout_width="65dp" android:layout_height="65dp" android:layout_margin="5dp" android:text="🛡️" android:textSize="20sp" android:background="@drawable/btn_bg" />
            <Button android:id="@+id/btn_jump" android:layout_width="65dp" android:layout_height="65dp" android:layout_margin="5dp" android:text="⬆️" android:textSize="20sp" android:background="@drawable/btn_bg" />
            <Button android:id="@+id/btn_attack" android:layout_width="65dp" android:layout_height="65dp" android:layout_margin="5dp" android:text="⚔️" android:textSize="20sp" android:background="@drawable/btn_bg" />
        </GridLayout>
    </RelativeLayout>
</FrameLayout>
EOF

cat << 'EOF' > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;

import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity {
    private GLSurfaceView glView;
    private float joyX = 0f, joyY = 0f;
    private boolean isJumping = false;
    private boolean isAttacking = false;
    
    // Camera Control variables
    private float camYaw = 0f, camPitch = 0.5f, camZoom = 12f;
    private float lastTouchX = -1f, lastTouchY = -1f;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        glView = findViewById(R.id.gl_surface_view);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(new GameRenderer());

        setupOverlayControls();
    }

    private void setupOverlayControls() {
        View joystick = findViewById(R.id.joystick_area);
        joystick.setOnTouchListener((v, event) -> {
            if (event.getAction() == MotionEvent.ACTION_UP) {
                joyX = 0; joyY = 0;
            } else {
                float cx = v.getWidth() / 2f;
                float cy = v.getHeight() / 2f;
                joyX = (event.getX() - cx) / cx;
                joyY = -(event.getY() - cy) / cy;
                float mag = (float)Math.sqrt(joyX*joyX + joyY*joyY);
                if (mag > 1.0f) { joyX /= mag; joyY /= mag; }
            }
            return true;
        });

        findViewById(R.id.btn_jump).setOnTouchListener((v, event) -> {
            isJumping = (event.getAction() == MotionEvent.ACTION_DOWN || event.getAction() == MotionEvent.ACTION_MOVE);
            return true;
        });

        findViewById(R.id.btn_attack).setOnTouchListener((v, event) -> {
            isAttacking = (event.getAction() == MotionEvent.ACTION_DOWN || event.getAction() == MotionEvent.ACTION_MOVE);
            return true;
        });
        
        // Camera swipe controls on the screen
        glView.setOnTouchListener((v, e) -> {
            if(e.getAction() == MotionEvent.ACTION_DOWN) {
                lastTouchX = e.getX(); lastTouchY = e.getY();
            } else if(e.getAction() == MotionEvent.ACTION_MOVE) {
                camYaw -= (e.getX() - lastTouchX) * 0.01f;
                camPitch = Math.max(0.1f, Math.min(1.5f, camPitch + (e.getY() - lastTouchY) * 0.01f));
                lastTouchX = e.getX(); lastTouchY = e.getY();
            }
            return true;
        });
    }

    private class GameRenderer implements GLSurfaceView.Renderer {
        @Override
        public void onSurfaceCreated(GL10 gl, EGLConfig config) { GameLib.onCreated(); }
        @Override
        public void onSurfaceChanged(GL10 gl, int width, int height) { GameLib.onChanged(width, height); }
        @Override
        public void onSurfaceDrawFrame(GL10 gl) { GameLib.onDraw(joyX, joyY, camYaw, camPitch, isJumping, isAttacking); }
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/game/procedural/GameLib.java
package com.game.procedural;
public class GameLib {
    static { System.loadLibrary("game_engine"); }
    public static native void onCreated();
    public static native void onChanged(int w, int h);
    public static native void onDraw(float jX, float jY, float yaw, float pitch, boolean jump, boolean atk);
}
EOF
