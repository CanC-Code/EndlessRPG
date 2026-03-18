#!/bin/bash
echo "Expanding Scaffolding with Action Controls..."
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/cpp
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable

# settings.gradle
cat << 'EOF' > settings.gradle
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { 
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() } 
}
rootProject.name = "EndlessRPG"
include ':app'
EOF

# app/build.gradle
cat << 'EOF' > app/build.gradle
apply plugin: 'com.android.application'
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

# CMakeLists.txt
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
find_library(log-lib log)
find_library(gles3-lib GLESv3)
target_link_libraries(procedural_engine ${log-lib} ${gles3-lib})
EOF

# MainActivity.java
cat << 'EOF' > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;
import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity implements GLSurfaceView.Renderer {
    private GLSurfaceView glView;
    private float tX, tY;
    static { System.loadLibrary("procedural_engine"); }
    private native void onCreated();
    private native void onChanged(int w, int h);
    private native void onDraw(float x, float y);
    private native void triggerAction(int id);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        glView = findViewById(R.id.game_surface);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);

        findViewById(R.id.thumbstick).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_MOVE) {
                tX = (e.getX() / v.getWidth()) * 2 - 1;
                tY = (e.getY() / v.getHeight()) * 2 - 1;
            } else { tX = 0; tY = 0; }
            return true;
        });

        findViewById(R.id.btn_sword).setOnClickListener(v -> triggerAction(1));
        findViewById(R.id.btn_shield).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) triggerAction(2);
            if (e.getAction() == MotionEvent.ACTION_UP) triggerAction(3);
            return true;
        });
    }
    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }
    @Override public void onDrawFrame(GL10 gl) { onDraw(tX, tY); }
}
EOF

# activity_main.xml
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="match_parent">
    <android.opengl.GLSurfaceView android:id="@+id/game_surface"
        android:layout_width="match_parent" android:layout_height="match_parent" />
    <View android:id="@+id/thumbstick" android:layout_width="140dp" android:layout_height="140dp"
        android:layout_alignParentBottom="true" android:layout_margin="30dp"
        android:background="@drawable/thumbstick_base" />
    <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:layout_alignParentBottom="true" android:layout_alignParentRight="true"
        android:layout_margin="30dp" android:orientation="horizontal">
        <Button android:id="@+id/btn_shield" android:layout_width="80dp" android:layout_height="80dp"
            android:layout_marginRight="15dp" android:text="B" android:background="@drawable/action_btn" />
        <Button android:id="@+id/btn_sword" android:layout_width="90dp" android:layout_height="90dp"
            android:text="A" android:background="@drawable/action_btn" />
    </LinearLayout>
</RelativeLayout>
EOF
