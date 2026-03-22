#!/bin/bash
# File: scripts/setup_project.sh

mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout

# --- Generate Gradle Files ---
cat << 'EOF' > settings.gradle
rootProject.name = "EndlessRPG"
include ':app'
EOF

cat << 'EOF' > build.gradle
plugins {
    id 'com.android.application' version '8.3.0' apply false
}
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

# --- Generate HUD (activity_main.xml) ---
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="match_parent">
    <android.opengl.GLSurfaceView android:id="@+id/gl_surface"
        android:layout_width="match_parent" android:layout_height="match_parent" />
    
    <RelativeLayout android:id="@+id/game_ui" android:layout_width="match_parent" android:layout_height="match_parent">
        <ImageView android:id="@+id/img_compass" android:layout_width="64dp" android:layout_height="64dp"
            android:layout_alignParentRight="true" android:layout_margin="24dp" android:src="@android:drawable/ic_menu_compass" />
        <Button android:id="@+id/btn_compass_toggle" android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:layout_below="@id/img_compass" android:layout_alignParentRight="true" android:text="Lock" android:background="#88000000" android:textColor="#FFF"/>
        
        <RelativeLayout android:layout_width="140dp" android:layout_height="140dp" android:layout_alignParentBottom="true" android:layout_margin="30dp">
            <ImageView android:id="@+id/joystick_bg" android:layout_width="match_parent" android:layout_height="match_parent" android:background="#44FFFFFF"/>
            <ImageView android:id="@+id/joystick_knob" android:layout_width="50dp" android:layout_height="50dp" android:layout_centerInParent="true" android:background="#88FFFFFF" />
        </RelativeLayout>
    </RelativeLayout>
</RelativeLayout>
EOF

# --- Generate MainActivity.java ---
cat << 'EOF' > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;
import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import android.widget.Button;
import android.widget.ImageView;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity implements GLSurfaceView.Renderer {
    static { System.loadLibrary("procedural_engine"); }
    private native void onCreated();
    private native void onDraw();
    private native void updateInput(float dx, float dy);
    private native float getCameraYaw();

    private boolean isCompassLocked = false;
    private ImageView compassView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        GLSurfaceView glView = findViewById(R.id.gl_surface);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);

        compassView = findViewById(R.id.img_compass);
        Button toggle = findViewById(R.id.btn_compass_toggle);
        toggle.setOnClickListener(v -> {
            isCompassLocked = !isCompassLocked;
            toggle.setText(isCompassLocked ? "Free" : "Lock");
            if (isCompassLocked) compassView.setRotation(0);
        });
    }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) {}
    @Override public void onDrawFrame(GL10 gl) { 
        onDraw(); 
        if (!isCompassLocked) {
            final float yaw = getCameraYaw();
            runOnUiThread(() -> compassView.setRotation(-(float)Math.toDegrees(yaw)));
        }
    }
}
EOF
