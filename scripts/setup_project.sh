#!/bin/bash
# File: scripts/setup_project.sh
# EndlessRPG Unified Build Pipeline v5 - Android Scaffold with GLM Dependency

set -e
echo "[setup_project.sh] Scaffolding Android project structure..."

# 1. Project-level build.gradle
cat <<EOF > build.gradle
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.2.2' }
}
allprojects {
    repositories { google(); mavenCentral() }
}
EOF

# 2. App-level build.gradle
cat <<EOF > app/build.gradle
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
            cmake { 
                cppFlags "-std=c++17" 
                arguments "-DANDROID_STL=c++_shared"
            } 
        }
        ndk { abiFilters 'arm64-v8a' }
    }
    externalNativeBuild { cmake { path "CMakeLists.txt" } }
}
EOF

# 3. AndroidManifest.xml
cat <<EOF > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="EndlessRPG" android:hasCode="true" android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name=".MainActivity" android:exported="true" android:screenOrientation="landscape" android:configChanges="orientation|screenSize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# 4. Dependency Management: GLM (OpenGL Mathematics)
# We fetch GLM directly into the project include directory to satisfy the native-lib.cpp requirement.
echo "[setup_project.sh] Fetching GLM dependency..."
mkdir -p app/src/main/cpp/include
if [ ! -d "app/src/main/cpp/include/glm" ]; then
    # Shallow clone for efficiency in CI environments
    git clone --depth 1 https://github.com/g-truc/glm.git /tmp/glm_repo
    mv /tmp/glm_repo/glm app/src/main/cpp/include/glm
    rm -rf /tmp/glm_repo
fi

# 5. CMakeLists.txt (Crucial Fix)
cat <<EOF > app/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("game_engine")

# Include the directory containing glm/glm.hpp
include_directories(src/main/cpp/include)

add_library(game_engine SHARED src/main/cpp/native-lib.cpp)

# Link GLESv3 and the Android logging library
target_link_libraries(game_engine GLESv3 log)
EOF

# 6. MainActivity.java
cat <<EOF > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;
import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity {
    private GLSurfaceView gv;
    private float joyX = 0, joyY = 0;
    private float camYaw = 0, camPitch = 0.5f;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        gv = new GLSurfaceView(this);
        gv.setEGLContextClientVersion(3);
        gv.setRenderer(new GLSurfaceView.Renderer() {
            public void onSurfaceCreated(GL10 gl, EGLConfig c) { GameLib.onCreated(); }
            public void onSurfaceChanged(GL10 gl, int w, int h) { GameLib.onChanged(w, h); }
            public void onDrawFrame(GL10 gl) { GameLib.onDraw(joyX, joyY, camYaw, camPitch); }
        });
        
        gv.setOnTouchListener((v, e) -> {
            if(e.getX() < v.getWidth()/2) {
                joyX = (e.getX() / (v.getWidth()/4)) - 1.0f;
                joyY = (e.getY() / (v.getHeight()/2)) - 1.0f;
            } else {
                camYaw += 0.01f;
            }
            if(e.getAction() == MotionEvent.ACTION_UP) { joyX = 0; joyY = 0; }
            return true;
        });
        setContentView(gv);
    }
}
EOF

# 7. GameLib.java
cat <<EOF > app/src/main/java/com/game/procedural/GameLib.java
package com.game.procedural;
public class GameLib {
    static { System.loadLibrary("game_engine"); }
    public static native void onCreated();
    public static native void onChanged(int w, int h);
    public static native void onDraw(float jX, float jY, float yaw, float pitch);
}
EOF

# 8. Settings.gradle
echo "include ':app'" > settings.gradle

echo "[setup_project.sh] Success: Android scaffold and GLM configured."
