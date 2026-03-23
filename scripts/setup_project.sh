#!/bin/bash
# File: scripts/setup_project.sh
# Updated for Realism and Camera-Relative Controls

echo "[setup_project.sh] Generating Android/Game logic..."

# 1. Generate Activity with Camera-Relative Movement
cat <<EOF > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;

import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;
import android.widget.FrameLayout;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity implements GLSurfaceView.Renderer {
    private GLSurfaceView glView;
    private View joystickThumb, joystickBase, menuOverlay, compassView, healthBarView, staminaBarView;
    private float joystickX, joystickY;
    private float camYaw = 0, camPitch = 0, camZoom = 5.0f;
    private float lastTouchX, lastTouchY;
    private boolean isCompassLocked = false;
    private int frameCount = 0;

    // Native methods
    public native void onCreated();
    public native void onChanged(int w, int h);
    public native void onDraw(float mvX, float mvZ, float yaw, float pitch, float zoom, float time);
    public native float getCameraYaw();
    public native float getStamina();
    public native float getHealth();

    static { System.loadLibrary("game_engine"); }

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        setContentView(R.layout.activity_main);

        glView = findViewById(R.id.gl_surface_view);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);

        setupControls();
    }

    private void setupControls() {
        // UI references and touch listeners for the joystick and orbit camera
        findViewById(R.id.touch_zone_move).setOnTouchListener((v, event) -> {
            switch (event.getAction()) {
                case MotionEvent.ACTION_MOVE:
                    // Normalize joystick input to -1.0 to 1.0 range
                    joystickX = (event.getX() - (v.getWidth()/2f)) / (v.getWidth()/2f);
                    joystickY = (event.getY() - (v.getHeight()/2f)) / (v.getHeight()/2f);
                    break;
                case MotionEvent.ACTION_UP:
                    joystickX = 0; joystickY = 0;
                    break;
            }
            return true;
        });

        findViewById(R.id.touch_zone_orbit).setOnTouchListener((v, event) -> {
            if (event.getAction() == MotionEvent.ACTION_MOVE) {
                float dx = event.getX() - lastTouchX;
                float dy = event.getY() - lastTouchY;
                camYaw += dx * 0.01f;
                camPitch = Math.max(-0.8f, Math.min(0.8f, camPitch + dy * 0.01f));
            }
            lastTouchX = event.getX();
            lastTouchY = event.getY();
            return true;
        });
    }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }

    @Override public void onDrawFrame(GL10 gl) {
        // --- CORRECTED CONTROLLER INPUT ---
        // We transform the 2D joystick input into World Space based on the Camera Yaw.
        // This ensures 'Up' on the joystick is always 'Forward' relative to the camera.
        
        float cosY = (float) Math.cos(camYaw);
        float sinY = (float) Math.sin(camYaw);

        // Map Joystick Y to Z-axis and Joystick X to X-axis
        // Note: In OpenGL, -Z is forward.
        float worldMoveX = (joystickX * cosY) - (joystickY * sinY);
        float worldMoveZ = (joystickX * sinY) + (joystickY * cosY);

        float currentTime = System.currentTimeMillis() / 1000.0f;

        onDraw(worldMoveX, worldMoveZ, camYaw, camPitch, camZoom, currentTime);

        // Update UI (Compass/HUD)
        updateUI();
    }

    private void updateUI() {
        frameCount++;
        if (frameCount % 6 == 0) {
            final float yaw = getCameraYaw();
            final float sta = getStamina();
            final float hp  = getHealth();
            runOnUiThread(() -> {
                findViewById(R.id.compass).setRotation(-(float) Math.toDegrees(yaw));
                findViewById(R.id.health_bar).setScaleX(hp);
                findViewById(R.id.stamina_bar).setScaleX(sta);
            });
        }
    }
}
EOF

# 2. Update Shader for Realistic Foliage Sway
# This creates a 'wind' effect by shifting vertices based on their height (Y).
cat <<EOF > app/src/main/assets/shaders/foliage.vert
#version 300 es
layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec2 aTexCoord;

uniform mat4 uMVP;
uniform float uTime;
uniform bool uIsFoliage;

out vec2 vTexCoord;

void main() {
    vec3 pos = aPosition;
    
    if(uIsFoliage && pos.y > 0.1) {
        // Procedural wind sway: Sine wave based on time and vertical height
        float sway = sin(uTime * 2.0 + pos.x + pos.z) * (pos.y * 0.15);
        pos.x += sway;
        pos.z += sway * 0.5;
    }
    
    vTexCoord = aTexCoord;
    gl_Position = uMVP * vec4(pos, 1.0);
}
EOF

echo "[setup_project.sh] Logic and Shaders updated for realism."
