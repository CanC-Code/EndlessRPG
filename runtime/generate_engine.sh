#!/bin/bash
# File: runtime/generate_engine.sh

cat << 'EOF' > app/src/main/cpp/engine.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <cmath>
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
    // Realistic directional lighting
    vec3 norm = normalize(v_Normal);
    vec3 lightDir = normalize(u_SunDirection);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * u_SunColor;
    vec3 ambient = mix(u_NightAmbient, vec3(0.4), diff); 
    vec3 resultColor = ambient + diffuse;
    
    // Pencil Art Post-Processing (High Resolution, No Surrealism)
    float gray = dot(resultColor, vec3(0.299, 0.587, 0.114));
    
    float shade = 1.0;
    if (gray < 0.25) shade = 0.2;       
    else if (gray < 0.55) shade = 0.55; 
    else shade = 0.95;                  
    
    vec3 graphiteColor = vec3(0.18, 0.18, 0.20);
    vec3 paperColor = vec3(0.95, 0.95, 0.92);
    vec3 finalPencil = mix(graphiteColor, paperColor, shade);
    
    FragColor = vec4(finalPencil, 1.0);
}
)";

// --- C++ MATH HELPERS FOR fBm ---
// Simulates GLSL math syntax so our CPU generator logic compiles
struct vec2 { 
    float x, y; 
    vec2() : x(0.0f), y(0.0f) {}
    vec2(float _x, float _y) : x(_x), y(_y) {}
    vec2(float v) : x(v), y(v) {}
};

inline float dot(vec2 a, vec2 b) { return a.x * b.x + a.y * b.y; }
inline float fract(float x) { return x - std::floor(x); }
inline vec2 fract(vec2 v) { return vec2(fract(v.x), fract(v.y)); }
inline vec2 floor(vec2 v) { return vec2(std::floor(v.x), std::floor(v.y)); }

inline vec2 operator+(vec2 a, vec2 b) { return vec2(a.x + b.x, a.y + b.y); }
inline vec2 operator-(vec2 a, vec2 b) { return vec2(a.x - b.x, a.y - b.y); }
inline vec2 operator*(vec2 a, vec2 b) { return vec2(a.x * b.x, a.y * b.y); }
inline vec2 operator*(vec2 a, float b) { return vec2(a.x * b, a.y * b); }
inline float mix(float a, float b, float t) { return a + t * (b - a); }

// --- SEAMLESS TERRAIN GENERATION (fBm) ---
float random(vec2 st) {
    return fract(std::sin(dot(st, vec2(12.9898f, 78.233f))) * 43758.5453123f);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i + vec2(1.0f, 0.0f));
    float c = random(i + vec2(0.0f, 1.0f));
    float d = random(i + vec2(1.0f, 1.0f));
    
    vec2 u = f * f * (vec2(3.0f, 3.0f) - f * 2.0f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0f - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 st) {
    float value = 0.0f;
    float amplitude = 0.5f;
    for (int i = 0; i < 6; i++) {
        value += amplitude * noise(st);
        st = st * 2.0f;
        amplitude *= 0.5f;
    }
    return value;
}

// Engine Loop Stub
float internalCameraYaw = 0.0f;

void update_day_night_cycle(float timePassed, float& sunX, float& sunY) {
    sunX = std::sin(timePassed * 0.1f);
    sunY = std::cos(timePassed * 0.1f);
}

// --- JNI BRIDGE TO ANDROID JAVA ACTIVITY ---
extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv* env, jobject obj) {
        glClearColor(0.95f, 0.95f, 0.92f, 1.0f); // Paper color background
        glEnable(GL_DEPTH_TEST);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv* env, jobject obj, jint width, jint height) {
        glViewport(0, 0, width, height);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv* env, jobject obj) {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        // OpenGL draw calls for your procedural generation go here
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv* env, jobject obj, jint actionId) {
        // Handle jump, attack, and shield bashes mapped from Java buttons
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_updateInput(JNIEnv* env, jobject obj, jfloat dx, jfloat dy) {
        // Player movement values passed directly from the Java UI Joystick
    }

    JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getCameraYaw(JNIEnv* env, jobject obj) {
        // Sends the C++ camera orientation back up to the UI so the Compass updates
        return internalCameraYaw; 
    }
}
EOF
