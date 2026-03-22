#!/bin/bash
# File: runtime/generate_engine.sh

cat << 'EOF' > app/src/main/cpp/engine.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <cmath>
#include <vector>

// --- Procedural Math ---
struct vec2 { float x, y; };
inline float dot(vec2 a, vec2 b) { return a.x*b.x + a.y*b.y; }
inline float fract(float x) { return x - std::floor(x); }
inline float mix(float a, float b, float t) { return a + t * (b - a); }

float random(vec2 st) { return fract(std::sin(dot(st, {12.9898f, 78.233f})) * 43758.5453123f); }

float noise(vec2 st) {
    vec2 i = {std::floor(st.x), std::floor(st.y)};
    vec2 f = {st.x - i.x, st.y - i.y};
    float a = random(i);
    float b = random({i.x + 1.0f, i.y});
    float c = random({i.x, i.y + 1.0f});
    float d = random({i.x + 1.0f, i.y + 1.0f});
    vec2 u = {f.x*f.x*(3.0f-2.0f*f.x), f.y*f.y*(3.0f-2.0f*f.y)};
    return mix(a, b, u.x) + (c - a)*u.y*(1.0f - u.x) + (d - b)*u.x*u.y;
}

// Fractional Brownian Motion for lifelike terrain
float fbm(vec2 st) {
    float value = 0.0f, amplitude = 0.5f;
    for (int i = 0; i < 6; i++) {
        value += amplitude * noise(st);
        st.x *= 2.0f; st.y *= 2.0f; amplitude *= 0.5f;
    }
    return value;
}

// --- JNI Bridge ---
float currentYaw = 0.0f;
extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv* env, jobject obj) {
        glClearColor(0.95f, 0.95f, 0.92f, 1.0f); // Paper white
        glEnable(GL_DEPTH_TEST);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv* env, jobject obj) {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        // Terrain rendering with Pencil Shader goes here
    }
    JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getCameraYaw(JNIEnv* env, jobject obj) {
        return currentYaw;
    }
}
EOF

# Generate CMakeLists.txt
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED engine.cpp)
find_library(log-lib log)
find_library(GLES3-lib GLESv3)
target_link_libraries(procedural_engine ${log-lib} ${GLES3-lib})
EOF
