#!/bin/bash
# File: scripts/setup_project.sh
set -e
echo "[setup_project.sh] Scaffolding Full Feature Engine..."

mkdir -p app/src/main/cpp/include app/src/main/java/com/game/procedural app/src/main/res/values

# 1. Fetch GLM Math Library
if [ ! -d "app/src/main/cpp/include/glm" ]; then
    git clone --depth 1 https://github.com/g-truc/glm.git /tmp/glm_repo
    mv /tmp/glm_repo/glm app/src/main/cpp/include/glm
    rm -rf /tmp/glm_repo
fi

# 2. Android Manifest
cat <<EOF > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="EndlessRPG" android:hasCode="true" android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name=".MainActivity" android:exported="true" android:screenOrientation="landscape">
            <intent-filter><action android:name="android.intent.action.MAIN" /><category android:name="android.intent.category.LAUNCHER" /></intent-filter>
        </activity>
    </application>
</manifest>
EOF

# 3. Java Input Layer (Thumbstick + Buttons)
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
    private float joyX=0, joyY=0, camYaw=0, camPitch=0.6f;
    private boolean jumpReq=false, atkReq=false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        gv = new GLSurfaceView(this);
        gv.setEGLContextClientVersion(3);
        gv.setRenderer(new GLSurfaceView.Renderer() {
            public void onSurfaceCreated(GL10 gl, EGLConfig c) { GameLib.onCreated(); }
            public void onSurfaceChanged(GL10 gl, int w, int h) { GameLib.onChanged(w, h); }
            public void onDrawFrame(GL10 gl) { 
                GameLib.onDraw(joyX, joyY, camYaw, camPitch, jumpReq, atkReq); 
                jumpReq = false; // Reset triggers
            }
        });
        gv.setOnTouchListener((v, e) -> {
            float x = e.getX(), y = e.getY(), w = v.getWidth();
            if (x < w/3) { // Movement Zone
                joyX = (x / (w/6)) - 1.0f;
                joyY = (y / (v.getHeight()/2)) - 1.0f;
            } else if (x > 2*w/3) { // Action Zone
                if (e.getAction() == MotionEvent.ACTION_DOWN) jumpReq = true;
            } else { // Camera Zone
                camYaw += 0.01f;
            }
            if (e.getAction() == MotionEvent.ACTION_UP) { joyX=0; joyY=0; }
            return true;
        });
        setContentView(gv);
    }
}
EOF

# 4. Java JNI Bridge
cat <<EOF > app/src/main/java/com/game/procedural/GameLib.java
package com.game.procedural;
public class GameLib {
    static { System.loadLibrary("game_engine"); }
    public static native void onCreated();
    public static native void onChanged(int w, int h);
    public static native void onDraw(float jX, float jY, float yaw, float pitch, boolean jump, boolean atk);
}
EOF

# 5. CMake Configuration
cat <<EOF > app/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("game_engine")
include_directories(src/main/cpp/include)
add_library(game_engine SHARED src/main/cpp/native-lib.cpp)
target_link_libraries(game_engine GLESv3 log)
EOF
