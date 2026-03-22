#!/bin/bash
# File: scripts/setup_project.sh

mkdir -p app/src/main/res/layout
mkdir -p app/src/main/java/com/game/procedural

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

        <ImageView
            android:id="@+id/joystick_bg"
            android:layout_width="120dp"
            android:layout_height="120dp"
            android:layout_alignParentBottom="true"
            android:layout_alignParentLeft="true"
            android:layout_marginBottom="32dp"
            android:layout_marginLeft="32dp"
            android:background="#44FFFFFF"/>

        <ImageView
            android:id="@+id/joystick_knob"
            android:layout_width="50dp"
            android:layout_height="50dp"
            android:layout_alignCenter="@id/joystick_bg"
            android:background="#88FFFFFF" />
            
    </RelativeLayout>
</RelativeLayout>
EOF

cat << 'EOF' > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;

import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
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
    private ImageView knob;
    private float tX = 0f, tY = 0f;
    private long shieldDownTime = 0;
    
    // Compass variables
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
