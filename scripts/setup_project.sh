#!/bin/bash
# File: scripts/setup_project.sh
# Purpose: UI, Activity, and Camera Initialization. Corrects initial boot camera angle and pitch limits.

cat << 'EOF' > settings.gradle
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
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
    defaultConfig { applicationId "com.game.procedural"; minSdk 24; targetSdk 34; externalNativeBuild { cmake { cppFlags "-std=c++17" } } }
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

cat << 'EOF' > app/src/main/res/drawable/stick_base.xml
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#44000000"/><stroke android:width="2dp" android:color="#88FFFFFF"/></shape>
EOF
cat << 'EOF' > app/src/main/res/drawable/stick_knob.xml
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#CCFFFFFF"/></shape>
EOF
cat << 'EOF' > app/src/main/res/drawable/btn_bg.xml
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#66000000"/><stroke android:width="3dp" android:color="#AAFFFFFF"/></shape>
EOF
cat << 'EOF' > app/src/main/res/drawable/health_bar_bg.xml
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:id="@android:id/background"><shape><solid android:color="#55000000"/><corners android:radius="8dp"/></shape></item>
    <item android:id="@android:id/progress"><clip><shape><solid android:color="#E53935"/><corners android:radius="8dp"/></shape></clip></item>
</layer-list>
EOF

cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android" android:layout_width="match_parent" android:layout_height="match_parent">
    <android.opengl.GLSurfaceView android:id="@+id/game_surface" android:layout_width="match_parent" android:layout_height="match_parent" />
    
    <ProgressBar android:id="@+id/health_bar" style="?android:attr/progressBarStyleHorizontal" android:layout_width="300dp" android:layout_height="24dp" android:layout_alignParentTop="true" android:layout_alignParentLeft="true" android:layout_margin="20dp" android:progressDrawable="@drawable/health_bar_bg" android:max="100" android:progress="100" />
    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_alignTop="@id/health_bar" android:layout_alignLeft="@id/health_bar" android:layout_alignBottom="@id/health_bar" android:layout_alignRight="@id/health_bar" android:gravity="center" android:text="100 / 100" android:textColor="#FFF" android:textSize="14sp" android:textStyle="bold" />

    <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_alignParentTop="true" android:layout_alignParentRight="true" android:layout_margin="20dp" android:orientation="horizontal">
        <Button android:id="@+id/btn_inv" android:layout_width="50dp" android:layout_height="50dp" android:layout_marginRight="10dp" android:text="🎒" android:textSize="20sp" android:background="@drawable/btn_bg" android:textColor="#FFF"/>
        <Button android:id="@+id/btn_menu" android:layout_width="50dp" android:layout_height="50dp" android:text="&#9776;" android:textSize="20sp" android:background="@drawable/btn_bg" android:textColor="#FFF"/>
    </LinearLayout>

    <RelativeLayout android:id="@+id/thumbstick_container" android:layout_width="160dp" android:layout_height="160dp" android:layout_alignParentBottom="true" android:layout_margin="30dp">
        <View android:id="@+id/thumbstick_base" android:layout_width="160dp" android:layout_height="160dp" android:background="@drawable/stick_base" />
        <View android:id="@+id/thumbstick_knob" android:layout_width="60dp" android:layout_height="60dp" android:layout_centerInParent="true" android:background="@drawable/stick_knob" />
    </RelativeLayout>

    <GridLayout android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_alignParentBottom="true" android:layout_alignParentRight="true" android:layout_margin="30dp" android:columnCount="2" android:rowCount="2">
        <Button android:id="@+id/btn_action" android:layout_width="65dp" android:layout_height="65dp" android:layout_margin="5dp" android:text="🖐" android:textSize="20sp" android:background="@drawable/btn_bg" />
        <Button android:id="@+id/btn_shield" android:layout_width="65dp" android:layout_height="65dp" android:layout_margin="5dp" android:text="🛡️" android:textSize="20sp" android:background="@drawable/btn_bg" />
        <Button android:id="@+id/btn_jump" android:layout_width="65dp" android:layout_height="65dp" android:layout_margin="5dp" android:text="⬆️" android:textSize="20sp" android:background="@drawable/btn_bg" />
        <Button android:id="@+id/btn_sword" android:layout_width="85dp" android:layout_height="85dp" android:layout_margin="5dp" android:text="⚔️" android:textSize="28sp" android:background="@drawable/btn_bg" />
    </GridLayout>

    <LinearLayout android:id="@+id/menu_overlay" android:layout_width="match_parent" android:layout_height="match_parent" android:background="#E6000000" android:gravity="center" android:orientation="vertical" android:visibility="gone">
        <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="PAUSED" android:textColor="#FFF" android:textSize="40sp" android:layout_marginBottom="30dp" android:textStyle="bold"/>
        <Button android:id="@+id/btn_resume" android:layout_width="200dp" android:layout_height="60dp" android:text="Resume Game" android:background="#4CAF50" android:textColor="#FFF" android:layout_marginBottom="20dp"/>
        <Button android:id="@+id/btn_exit" android:layout_width="200dp" android:layout_height="60dp" android:text="Exit to Desktop" android:background="#F44336" android:textColor="#FFF"/>
    </LinearLayout>

    <LinearLayout android:id="@+id/inv_overlay" android:layout_width="match_parent" android:layout_height="match_parent" android:background="#F21E1E1E" android:gravity="center" android:orientation="horizontal" android:visibility="gone" android:padding="40dp">
        <LinearLayout android:layout_width="wrap_content" android:layout_height="match_parent" android:orientation="vertical" android:gravity="center" android:layout_marginRight="40dp">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="EQUIPMENT" android:textColor="#FFF" android:textSize="20sp" android:textStyle="bold" android:layout_marginBottom="20dp"/>
            <Button android:layout_width="80dp" android:layout_height="80dp" android:text="Helm" android:background="@drawable/btn_bg" android:textColor="#AAA" android:layout_marginBottom="10dp"/>
            <Button android:layout_width="80dp" android:layout_height="80dp" android:text="Chest" android:background="@drawable/btn_bg" android:textColor="#AAA" android:layout_marginBottom="10dp"/>
        </LinearLayout>
        <LinearLayout android:layout_width="0dp" android:layout_weight="1" android:layout_height="match_parent" android:orientation="vertical">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="INVENTORY" android:textColor="#FFF" android:textSize="20sp" android:textStyle="bold" android:layout_marginBottom="20dp"/>
            <GridLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:columnCount="4" android:rowCount="3">
                <Button android:layout_width="70dp" android:layout_height="70dp" android:layout_margin="5dp" android:text="Potion" android:background="#44FFFFFF" android:textColor="#FFF"/>
                <Button android:layout_width="70dp" android:layout_height="70dp" android:layout_margin="5dp" android:text="Apple" android:background="#44FFFFFF" android:textColor="#FFF"/>
            </GridLayout>
        </LinearLayout>
        <Button android:id="@+id/btn_close_inv" android:layout_width="50dp" android:layout_height="50dp" android:layout_gravity="top|right" android:text="X" android:background="#F44336" android:textColor="#FFF" android:textStyle="bold"/>
    </LinearLayout>

</RelativeLayout>
EOF

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
    private View knob, menuOverlay, invOverlay;
    private float tX = 0f, tY = 0f;
    
    // CAMERA FIX: Initial Pitch 0.8f looks down at the character natively, Zoom reduced for tighter view.
    private float camYaw = 0.7f, camPitch = 0.8f, camZoom = 12.0f; 
    private float lastX, lastY;
    private long shieldDownTime = 0;
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
        glView.setEGLConfigChooser(8,8,8,8,16,0);
        glView.setRenderer(this);

        knob = findViewById(R.id.thumbstick_knob);
        menuOverlay = findViewById(R.id.menu_overlay);
        invOverlay = findViewById(R.id.inv_overlay);

        findViewById(R.id.btn_menu).setOnClickListener(v -> menuOverlay.setVisibility(View.VISIBLE));
        findViewById(R.id.btn_resume).setOnClickListener(v -> menuOverlay.setVisibility(View.GONE));
        findViewById(R.id.btn_exit).setOnClickListener(v -> { finishAffinity(); System.exit(0); });
        
        findViewById(R.id.btn_inv).setOnClickListener(v -> invOverlay.setVisibility(View.VISIBLE));
        findViewById(R.id.btn_close_inv).setOnClickListener(v -> invOverlay.setVisibility(View.GONE));

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
                    // CAMERA FIX: Pitch bounded from -0.1f (looking up at sky) to 1.5f (looking straight down at feet)
                    camPitch = Math.max(-0.1f, Math.min(1.5f, camPitch + (e.getY() - lastY) * 0.01f));
                    lastX = e.getX(); lastY = e.getY();
                }
            }
            return true;
        });

        findViewById(R.id.thumbstick_container).setOnTouchListener((v, e) -> {
            float radius = v.getWidth() / 2f;
            float centerX = radius, centerY = radius;
            if (e.getAction() == MotionEvent.ACTION_MOVE || e.getAction() == MotionEvent.ACTION_DOWN) {
                float dx = e.getX() - centerX, dy = e.getY() - centerY;
                float dist = (float) Math.hypot(dx, dy);
                if (dist > radius) { dx *= (radius / dist); dy *= (radius / dist); }
                knob.setTranslationX(dx); knob.setTranslationY(dy);
                tX = dx / radius; tY = dy / radius;
            } else if (e.getAction() == MotionEvent.ACTION_UP) {
                knob.setTranslationX(0); knob.setTranslationY(0); tX = 0f; tY = 0f;
            }
            return true;
        });
        
        findViewById(R.id.btn_sword).setOnClickListener(v -> triggerAction(1));
        findViewById(R.id.btn_jump).setOnClickListener(v -> triggerAction(4));
        findViewById(R.id.btn_action).setOnClickListener(v -> triggerAction(5));

        findViewById(R.id.btn_shield).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) {
                shieldDownTime = System.currentTimeMillis();
                triggerAction(2); // Block ON
            } else if (e.getAction() == MotionEvent.ACTION_UP) {
                triggerAction(3); // Block OFF
                if (System.currentTimeMillis() - shieldDownTime < 300) {
                    triggerAction(6); // Shield Bash
                }
            }
            return true;
        });
    }
    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }
    @Override public void onDrawFrame(GL10 gl) { 
        if(menuOverlay.getVisibility() == View.GONE && invOverlay.getVisibility() == View.GONE) {
            onDraw(tX, tY, camYaw, camPitch, camZoom); 
        }
    }
}
EOF
