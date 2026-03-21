#!/bin/bash
echo "Scaffolding Android Framework and Advanced GUI..."

# 1. Root settings.gradle (Fixes Plugin Resolution)
cat << 'EOF' > settings.gradle
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "EndlessRPG"
include ':app'
EOF

cat << 'EOF' > build.gradle
plugins { id 'com.android.application' version '8.2.2' apply false }
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

cat << 'EOF' > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="EndlessRPG" android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name="com.game.procedural.MainActivity" android:exported="true" android:screenOrientation="landscape">
            <intent-filter><action android:name="android.intent.action.MAIN" /><category android:name="android.intent.category.LAUNCHER" /></intent-filter>
        </activity>
    </application>
</manifest>
EOF

# 2. UI Drawables (Thumbstick & Buttons)
cat << 'EOF' > app/src/main/res/drawable/stick_base.xml
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#44000000"/><stroke android:width="2dp" android:color="#88FFFFFF"/></shape>
EOF
cat << 'EOF' > app/src/main/res/drawable/stick_knob.xml
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#AAFFFFFF"/></shape>
EOF
cat << 'EOF' > app/src/main/res/drawable/btn_bg.xml
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#66000000"/><stroke android:width="3dp" android:color="#AAFFFFFF"/></shape>
EOF

# 3. Enhanced UI Layout
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android" android:layout_width="match_parent" android:layout_height="match_parent">
    
    <android.opengl.GLSurfaceView android:id="@+id/game_surface" android:layout_width="match_parent" android:layout_height="match_parent" />
    
    <Button android:id="@+id/btn_menu" android:layout_width="50dp" android:layout_height="50dp" android:layout_margin="20dp" android:layout_alignParentTop="true" android:layout_alignParentRight="true" android:text="â˜°" android:background="@drawable/btn_bg" android:textColor="#FFF"/>

    <RelativeLayout android:id="@+id/thumbstick_container" android:layout_width="160dp" android:layout_height="160dp" android:layout_alignParentBottom="true" android:layout_margin="30dp">
        <View android:id="@+id/thumbstick_base" android:layout_width="160dp" android:layout_height="160dp" android:background="@drawable/stick_base" />
        <View android:id="@+id/thumbstick_knob" android:layout_width="60dp" android:layout_height="60dp" android:layout_centerInParent="true" android:background="@drawable/stick_knob" />
    </RelativeLayout>

    <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_alignParentBottom="true" android:layout_alignParentRight="true" android:layout_margin="30dp">
        <Button android:id="@+id/btn_shield" android:layout_width="70dp" android:layout_height="70dp" android:layout_marginRight="20dp" android:layout_gravity="bottom" android:text="🛡️" android:textSize="24sp" android:background="@drawable/btn_bg" />
        <Button android:id="@+id/btn_sword" android:layout_width="90dp" android:layout_height="90dp" android:text="⚔️" android:textSize="32sp" android:background="@drawable/btn_bg" />
    </LinearLayout>

    <LinearLayout android:id="@+id/menu_overlay" android:layout_width="match_parent" android:layout_height="match_parent" android:background="#CC000000" android:gravity="center" android:orientation="vertical" android:visibility="gone">
        <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="PAUSED" android:textColor="#FFF" android:textSize="40sp" android:layout_marginBottom="30dp" android:textStyle="bold"/>
        <Button android:id="@+id/btn_resume" android:layout_width="200dp" android:layout_height="60dp" android:text="Resume" android:background="#4CAF50" android:textColor="#FFF" android:layout_marginBottom="20dp"/>
        <Button android:id="@+id/btn_exit" android:layout_width="200dp" android:layout_height="60dp" android:text="Exit Game" android:background="#F44336" android:textColor="#FFF"/>
    </LinearLayout>

</RelativeLayout>
EOF

# 4. Advanced Java Activity (GUI Logic & Rendering Setup)
cat << 'EOF' > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;
import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;
import android.view.ScaleGestureDetector;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity implements GLSurfaceView.Renderer {
    private GLSurfaceView glView;
    private View knob, menuOverlay;
    private float tX = 0f, tY = 0f;
    private float camYaw = 0.7f, camPitch = 0.5f, camZoom = 15.0f;
    private float lastX, lastY;
    private ScaleGestureDetector zoomer;

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
        glView.setEGLConfigChooser(8,8,8,8,16,0); // CRITICAL: 16-bit Depth
        glView.setRenderer(this);

        knob = findViewById(R.id.thumbstick_knob);
        menuOverlay = findViewById(R.id.menu_overlay);

        // Menu Logic
        findViewById(R.id.btn_menu).setOnClickListener(v -> menuOverlay.setVisibility(View.VISIBLE));
        findViewById(R.id.btn_resume).setOnClickListener(v -> menuOverlay.setVisibility(View.GONE));
        findViewById(R.id.btn_exit).setOnClickListener(v -> { finishAffinity(); System.exit(0); });

        // Orbital Camera Logic
        zoomer = new ScaleGestureDetector(this, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
            @Override public boolean onScale(ScaleGestureDetector d) {
                camZoom = Math.max(5f, Math.min(40f, camZoom / d.getScaleFactor()));
                return true;
            }
        });

        glView.setOnTouchListener((v, e) -> {
            zoomer.onTouchEvent(e);
            if (!zoomer.isInProgress() && e.getPointerCount() == 1 && e.getX() > v.getWidth()/2f) {
                if (e.getAction() == MotionEvent.ACTION_DOWN) { lastX = e.getX(); lastY = e.getY(); }
                else if (e.getAction() == MotionEvent.ACTION_MOVE) {
                    camYaw += (e.getX() - lastX) * 0.01f;
                    camPitch = Math.max(0.1f, Math.min(1.4f, camPitch + (e.getY() - lastY) * 0.01f));
                    lastX = e.getX(); lastY = e.getY();
                }
            }
            return true;
        });

        // Dynamic Thumbstick Logic
        findViewById(R.id.thumbstick_container).setOnTouchListener((v, e) -> {
            float radius = v.getWidth() / 2f;
            float centerX = radius, centerY = radius;
            if (e.getAction() == MotionEvent.ACTION_MOVE || e.getAction() == MotionEvent.ACTION_DOWN) {
                float dx = e.getX() - centerX, dy = e.getY() - centerY;
                float distance = (float) Math.hypot(dx, dy);
                if (distance > radius) { dx = dx * (radius / distance); dy = dy * (radius / distance); }
                knob.setTranslationX(dx); knob.setTranslationY(dy);
                tX = dx / radius; tY = dy / radius;
            } else if (e.getAction() == MotionEvent.ACTION_UP) {
                knob.setTranslationX(0); knob.setTranslationY(0);
                tX = 0f; tY = 0f;
            }
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
    @Override public void onDrawFrame(GL10 gl) { 
        if(menuOverlay.getVisibility() == View.GONE) onDraw(tX, tY, camYaw, camPitch, camZoom); 
    }
}
EOF
