#!/bin/bash
# File: runtime/generate_engine.sh

cat << 'EOF' > app/src/main/cpp/engine.cpp
#include <GLES3/gl3.h>
#include <math.h>
#include <vector>

// --- SHADERS ---
const char* vertexShaderSrc = R"(#version 300 es
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;
uniform mat4 u_MVP;
uniform mat4 u_Model;
out vec3 v_Normal;
out vec3 v_FragPos;
void main() {
    gl_Position = u_MVP * vec4(aPos, 1.0);
    v_FragPos = vec3(u_Model * vec4(aPos, 1.0));
    v_Normal = mat3(transpose(inverse(u_Model))) * aNormal;
}
)";

const char* fragmentShaderSrc = R"(#version 300 es
precision highp float;
in vec3 v_Normal;
in vec3 v_FragPos;
out vec4 FragColor;

uniform vec3 u_SunDirection;
uniform vec3 u_SunColor;
uniform vec3 u_NightAmbient;

void main() {
    // 1. Lighting Calculation
    vec3 norm = normalize(v_Normal);
    vec3 lightDir = normalize(u_SunDirection);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * u_SunColor;
    vec3 ambient = mix(u_NightAmbient, vec3(0.4), diff); 
    vec3 resultColor = ambient + diffuse;
    
    // 2. Pencil Art Post-Processing
    float gray = dot(resultColor, vec3(0.299, 0.587, 0.114));
    
    float shade = 1.0;
    if (gray < 0.25) shade = 0.2;      // Heavy pencil
    else if (gray < 0.55) shade = 0.55; // Mid-tone hatching
    else shade = 0.95;                 // Paper
    
    vec3 graphiteColor = vec3(0.18, 0.18, 0.20);
    vec3 paperColor = vec3(0.95, 0.95, 0.92);
    vec3 finalPencil = mix(graphiteColor, paperColor, shade);
    
    FragColor = vec4(finalPencil, 1.0);
}
)";

// --- SEAMLESS TERRAIN GENERATION (fBm) ---
// Simple hash-based pseudo-random noise
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// 2D Noise
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Fractional Brownian Motion for lifelike cliffs and seamless chunks
float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    for (int i = 0; i < 6; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= .5;
    }
    return value;
}

// Engine Loop stub
void update_day_night_cycle(float timePassed, float& sunX, float& sunY) {
    // Moves the sun in a seamless arc
    sunX = sin(timePassed * 0.1f);
    sunY = cos(timePassed * 0.1f);
}
EOF
