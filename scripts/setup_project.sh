#!/bin/bash
# File: scripts/setup_project.sh
set -e

echo "[setup_project.sh] Scaffolding High-Fidelity Android Project..."

# Create all necessary directories
mkdir -p app/src/main/cpp/include
mkdir -p app/src/main/cpp/models
mkdir -p app/src/main/cpp/shaders
mkdir -p app/src/main/java/com/game/procedural

# 1. Android Manifest (Fixes the build error)
cat <<EOF > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="EndlessRPG" android:hasCode="true" 
        android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name=".MainActivity" android:exported="true" 
            android:screenOrientation="landscape" android:configChanges="orientation|screenSize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# 2. GLM Dependency
if [ ! -d "app/src/main/cpp/include/glm" ]; then
    echo "[setup_project.sh] Fetching GLM Math Library..."
    git clone --depth 1 https://github.com/g-truc/glm.git /tmp/glm_repo
    mv /tmp/glm_repo/glm app/src/main/cpp/include/glm
    rm -rf /tmp/glm_repo
fi

# 3. Java: MainActivity.java (Handles Touch & Camera)
cat <<EOF > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;
import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity {
    private GLSurfaceView gv;
    private float camYaw = 0, camPitch = 0.6f;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        gv = new GLSurfaceView(this);
        gv.setEGLContextClientVersion(3);
        gv.setRenderer(new GLSurfaceView.Renderer() {
            public void onSurfaceCreated(GL10 gl, EGLConfig c) { GameLib.onCreated(); }
            public void onSurfaceChanged(GL10 gl, int w, int h) { GameLib.onChanged(w, h); }
            public void onDrawFrame(GL10 gl) { GameLib.onDraw(0, 0, camYaw, camPitch); }
        });
        gv.setOnTouchListener((v, e) -> {
            camYaw += 0.01f; // Simple orbit for demo
            return true;
        });
        setContentView(gv);
    }
}
EOF

# 4. Java: GameLib.java
cat <<EOF > app/src/main/java/com/game/procedural/GameLib.java
package com.game.procedural;
public class GameLib {
    static { System.loadLibrary("game_engine"); }
    public static native void onCreated();
    public static native void onChanged(int w, int h);
    public static native void onDraw(float jX, float jY, float yaw, float pitch);
}
EOF

# 5. Build Configurations
cat <<EOF > app/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("game_engine")
include_directories(src/main/cpp/include)
add_library(game_engine SHARED src/main/cpp/native-lib.cpp)
target_link_libraries(game_engine GLESv3 log)
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
        externalNativeBuild { cmake { cppFlags "-std=c++17" } }
    }
    externalNativeBuild { cmake { path "CMakeLists.txt" } }
}
EOF

echo "include ':app'" > settings.gradle
cat <<EOF > build.gradle
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.2.2' }
}
allprojects { repositories { google(); mavenCentral() } }
EOF
