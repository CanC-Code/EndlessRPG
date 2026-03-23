#!/bin/bash
# File: scripts/setup_project.sh
# Purpose: Full environment and control logic overhaul

echo "[setup_project.sh] Enhancing environment realism and control logic..."

# 1. Create the Java Activity with Camera-Relative Movement Logic
cat <<EOF > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;

import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity implements GLSurfaceView.Renderer {
    private GLSurfaceView glView;
    private float joyX = 0, joyY = 0;
    private float camYaw = 0, camPitch = 0;
    private float lastX, lastY;

    // JNI Methods
    public native void onCreated();
    public native void onChanged(int w, int h);
    public native void onDraw(float moveX, float moveZ, float yaw, float pitch, float time);

    static { System.loadLibrary("game_engine"); }

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        setContentView(R.layout.activity_main);
        glView = findViewById(R.id.gl_surface_view);
        glView.setEGLContextClientVersion(3);
        glView.setRenderer(this);

        // Movement Control (Left Side)
        findViewById(R.id.touch_zone_move).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_UP) {
                joyX = 0; joyY = 0;
            } else {
                joyX = (e.getX() - (v.getWidth()/2f)) / (v.getWidth()/2f);
                joyY = (e.getY() - (v.getHeight()/2f)) / (v.getHeight()/2f);
            }
            return true;
        });

        // Camera Orbit (Right Side)
        findViewById(R.id.touch_zone_orbit).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_MOVE) {
                camYaw += (e.getX() - lastX) * 0.005f;
                camPitch = Math.max(-1.0f, Math.min(1.0f, camPitch + (e.getY() - lastY) * 0.005f));
            }
            lastX = e.getX(); lastY = e.getY();
            return true;
        });
    }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }

    @Override public void onDrawFrame(GL10 gl) {
        // --- CORRECTED MOVEMENT LOGIC ---
        // We rotate the joystick vector by the camera's Yaw so 'Forward' is relative to view.
        float cosY = (float) Math.cos(camYaw);
        float sinY = (float) Math.sin(camYaw);

        // In OpenGL (Right-Handed): Forward is -Z, Right is +X
        // Transform: moveX = joyX*cos - joyY*sin | moveZ = joyX*sin + joyY*cos
        float worldMoveX = (joyX * cosY) - (joyY * sinY);
        float worldMoveZ = (joyX * sinY) + (joyY * cosY);

        float currentTime = System.currentTimeMillis() / 1000.0f;
        onDraw(worldMoveX, worldMoveZ, camYaw, camPitch, currentTime);
    }
}
EOF

# 2. Create Realistic Environment Vertex Shader (Wind Sway)
cat <<EOF > app/src/main/assets/shaders/environment.vert
#version 300 es
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 aTex;
layout(location = 2) in vec3 aNormal;

uniform mat4 uMVP;
uniform float uTime;
uniform bool uIsFoliage;

out vec2 vTex;
out float vFogDepth;

void main() {
    vec3 pos = aPos;

    if (uIsFoliage) {
        // Apply wind sway based on height (Y) and time
        // The higher the vertex, the more it moves.
        float sway = sin(uTime * 1.5 + pos.x * 0.5) * (pos.y * 0.12);
        pos.x += sway;
        pos.z += sway * 0.5;
    }

    gl_Position = uMVP * vec4(pos, 1.0);
    vTex = aTex;
    
    // Pass depth for atmospheric fog
    vFogDepth = -(uMVP * vec4(pos, 1.0)).z;
}
EOF

# 3. Create Atmospheric Fragment Shader (Fog & Light)
cat <<EOF > app/src/main/assets/shaders/environment.frag
#version 300 es
precision highp float;

in vec2 vTex;
in float vFogDepth;
uniform sampler2D uTexture;
uniform vec3 uFogColor;

out vec4 fragColor;

void main() {
    vec4 texColor = texture(uTexture, vTex);
    
    // Atmospheric Fog Calculation (Exponential)
    float fogDensity = 0.015;
    float fogFactor = exp(-pow(vFogDepth * fogDensity, 2.0));
    fogFactor = clamp(fogFactor, 0.0, 1.0);

    // Blend the texture color with the forest haze
    vec3 finalRGB = mix(uFogColor, texColor.rgb, fogFactor);
    fragColor = vec4(finalRGB, texColor.a);
    
    if(fragColor.a < 0.1) discard; // Transparency for leaves/grass
}
EOF

echo "[setup_project.sh] Complete. Environment files ready for deployment."
