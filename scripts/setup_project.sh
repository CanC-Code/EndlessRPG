#!/bin/bash
echo "Scaffolding Voxel RPG Project Structure..."

# 1. Create Directory Tree
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/cpp
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p runtime

# 2. Root settings.gradle (Crucial for Plugin Resolution)
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

# 3. Root build.gradle (Defines Plugin Version)
cat << 'EOF' > build.gradle
plugins {
    id 'com.android.application' version '8.2.2' apply false
}
EOF

# 4. App build.gradle
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
        externalNativeBuild { cmake { cppFlags "-std=c++17" } }
    }
    externalNativeBuild { cmake { path "src/main/cpp/CMakeLists.txt" } }
}
EOF

# 5. Android Manifest
cat << 'EOF' > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="EndlessRPG" android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name="com.game.procedural.MainActivity" android:exported="true" android:screenOrientation="landscape">
            <intent-filter><action android:name="android.intent.action.MAIN" /><category android:name="android.intent.category.LAUNCHER" /></intent-filter>
        </activity>
    </application>
</manifest>
EOF

# 6. UI Resources
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android" android:layout_width="match_parent" android:layout_height="match_parent">
    <android.opengl.GLSurfaceView android:id="@+id/game_surface" android:layout_width="match_parent" android:layout_height="match_parent" />
    <View android:id="@+id/thumbstick" android:layout_width="140dp" android:layout_height="140dp" android:layout_alignParentBottom="true" android:layout_margin="30dp" />
    <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_alignParentBottom="true" android:layout_alignParentRight="true" android:layout_margin="30dp">
        <Button android:id="@+id/btn_shield" android:layout_width="80dp" android:layout_height="80dp" android:text="🛡️" />
        <Button android:id="@+id/btn_sword" android:layout_width="80dp" android:layout_height="80dp" android:text="⚔️" />
    </LinearLayout>
</RelativeLayout>
EOF

# 7. Java Logic (Orbital Camera)
cat << 'EOF' > app/src/main/java/com/game/procedural/MainActivity.java
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
    private float tX = 0f, tY = 0f;
    private float camYaw = 0.7f, camPitch = 0.5f, camZoom = 12.0f;
    private float lastX, lastY;
    private ScaleGestureDetector zoomDetector;

    static { System.loadLibrary("procedural_engine"); }
    private native void onCreated();
    private native void onChanged(int w, int h);
    private native void onDraw(float x, float y, float yaw, float pitch, float zoom);
    private native void triggerAction(int id);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        glView = findViewById(R.id.game_surface);
        glView.setEGLContextClientVersion(3);
        glView.setEGLConfigChooser(8,8,8,8,16,0);
        glView.setRenderer(this);

        zoomDetector = new ScaleGestureDetector(this, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
            @Override public boolean onScale(ScaleGestureDetector d) {
                camZoom = Math.max(5f, Math.min(25f, camZoom / d.getScaleFactor()));
                return true;
            }
        });

        glView.setOnTouchListener((v, e) -> {
            zoomDetector.onTouchEvent(e);
            if (!zoomDetector.isInProgress() && e.getPointerCount() == 1 && e.getX() > v.getWidth()/2f) {
                if (e.getAction() == MotionEvent.ACTION_DOWN) { lastX = e.getX(); lastY = e.getY(); }
                else if (e.getAction() == MotionEvent.ACTION_MOVE) {
                    camYaw += (e.getX() - lastX) * 0.01f;
                    camPitch = Math.max(0.1f, Math.min(1.4f, camPitch + (e.getY() - lastY) * 0.01f));
                    lastX = e.getX(); lastY = e.getY();
                }
            }
            return true;
        });

        findViewById(R.id.thumbstick).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_MOVE) {
                tX = (e.getX() / v.getWidth()) * 2 - 1; tY = (e.getY() / v.getHeight()) * 2 - 1;
            } else { tX = 0f; tY = 0f; }
            return true;
        });
        
        findViewById(R.id.btn_sword).setOnClickListener(v -> triggerAction(1));
        findViewById(R.id.btn_shield).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) triggerAction(2);
            else if (e.getAction() == MotionEvent.ACTION_UP) triggerAction(3);
            return true;
        });
    }
    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }
    @Override public void onDrawFrame(GL10 gl) { onDraw(tX, tY, camYaw, camPitch, camZoom); }
}
EOF
