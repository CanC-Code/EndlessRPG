#!/bin/bash
# File: runtime/generate_shaders.sh

mkdir -p app/src/main/cpp/shaders

cat << 'EOF' > app/src/main/cpp/shaders/shaders.h
#ifndef SHADERS_H
#define SHADERS_H

const char* VERTEX_SHADER = R"(#version 300 es
layout(location=0) in vec3 p;
layout(location=1) in vec3 n;
uniform mat4 uMVP;
uniform mat4 uModel;
out vec3 vN;
out vec3 wP;
void main() {
    gl_Position = uMVP * vec4(p, 1.0);
    vN = mat3(uModel) * n; // Rotate normals based on model orientation
    wP = (uModel * vec4(p, 1.0)).xyz; // World position
})";

const char* FRAGMENT_SHADER = R"(#version 300 es
precision mediump float;
in vec3 vN;
in vec3 wP;
uniform vec3 uColor;
out vec4 f;

// Simple 2D noise for clouds
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(hash(i+vec2(0.0,0.0)), hash(i+vec2(1.0,0.0)), u.x),
               mix(hash(i+vec2(0.0,1.0)), hash(i+vec2(1.0,1.0)), u.x), u.y);
}

void main() {
    vec3 norm = normalize(vN);
    vec3 lightDir = normalize(vec3(0.6, 0.8, 0.4));
    
    // Crisp Cel-style diffuse lighting
    float diff = max(0.4, dot(norm, lightDir));
    if (diff > 0.4 && diff < 0.7) diff = 0.7; 
    if (diff >= 0.7) diff = 1.0;

    vec3 col = uColor;

    // Procedural Ground Grid (Only applied if color matches the ground green)
    if (uColor.g > 0.5 && uColor.r < 0.3) {
        float grid = max(step(0.95, fract(wP.x)), step(0.95, fract(wP.z)));
        col = mix(col, col * 0.7, grid); // Darken the grid lines
    }

    // Atmospheric Fog
    float dist = length(wP.xz - vec2(0.0)); // Radial distance from origin
    float fog = clamp((dist - 15.0) / 25.0, 0.0, 1.0);

    // Procedural Sky with Noise Clouds
    vec3 skyColor = mix(vec3(0.4, 0.65, 0.9), vec3(1.0), noise(wP.xz * 0.05 + wP.y * 0.1) * 0.6);

    f = vec4(mix(col * diff, skyColor, fog), 1.0);
})";

#endif
EOF
echo "[Shaders] Generated shaders.h"
