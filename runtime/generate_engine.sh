#!/bin/bash
# File: runtime/generate_engine.sh

cat << 'EOF' > app/src/main/cpp/engine.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <cmath>
#include <vector>

// --- MATH & TERRAIN UTILS ---
struct vec2 { float x, y; };
struct vec3 { float x, y, z; };
inline float dot(vec2 a, vec2 b) { return a.x*b.x + a.y*b.y; }
inline float fract(float x) { return x - std::floor(x); }
inline float mix(float a, float b, float t) { return a + t * (b - a); }

float random(vec2 st) { return fract(std::sin(dot(st, {12.9898f, 78.233f})) * 43758.5453123f); }
float noise(vec2 st) {
    vec2 i = {std::floor(st.x), std::floor(st.y)};
    vec2 f = {st.x - i.x, st.y - i.y};
    float a = random(i), b = random({i.x + 1.0f, i.y});
    float c = random({i.x, i.y + 1.0f}), d = random({i.x + 1.0f, i.y + 1.0f});
    vec2 u = {f.x*f.x*(3.0f-2.0f*f.x), f.y*f.y*(3.0f-2.0f*f.y)};
    return mix(a, b, u.x) + (c - a)*u.y*(1.0f - u.x) + (d - b)*u.x*u.y;
}
float fbm(vec2 st) {
    float v = 0.0f, a = 0.5f;
    for (int i = 0; i < 5; i++) { v += a * noise(st); st.x *= 2.0f; st.y *= 2.0f; a *= 0.5f; }
    return v;
}

// --- SHADERS ---
const char* vShaderStr = R"(#version 300 es
layout(location = 0) in vec3 aPos;
uniform mat4 u_MVP;
out float v_Height;
void main() {
    v_Height = aPos.y;
    gl_Position = u_MVP * vec4(aPos, 1.0);
}
)";

const char* fShaderStr = R"(#version 300 es
precision highp float;
in float v_Height;
out vec4 FragColor;
void main() {
    // Pencil Art Depth / Height shading
    float shade = 0.95; // Paper background
    if (v_Height < 0.5) shade = 0.3; // Heavy pencil deep in valleys
    else if (v_Height < 1.5) shade = 0.6; // Mid-tone hatching on slopes
    
    vec3 graphiteColor = vec3(0.2, 0.2, 0.22);
    vec3 paperColor = vec3(0.95, 0.95, 0.92);
    vec3 finalPencil = mix(graphiteColor, paperColor, shade);
    
    FragColor = vec4(finalPencil, 1.0);
}
)";

// --- GLOBALS ---
GLuint program, vao, vbo, ebo;
int indexCount = 0;
float aspect = 1.0f;
float playerX = 0.0f, playerZ = 0.0f; // Player position

GLuint compileShader(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    return s;
}

// --- JNI BRIDGE IMPLEMENTATIONS ---
extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv* env, jobject obj) {
        program = glCreateProgram();
        glAttachShader(program, compileShader(GL_VERTEX_SHADER, vShaderStr));
        glAttachShader(program, compileShader(GL_FRAGMENT_SHADER, fShaderStr));
        glLinkProgram(program);

        // Build seamless terrain mesh
        std::vector<float> verts;
        std::vector<uint16_t> idx;
        const int size = 60;
        const float scale = 0.3f;
        
        for (int z = 0; z < size; z++) {
            for (int x = 0; x < size; x++) {
                float wx = (x - size/2) * scale;
                float wz = (z - size/2) * scale;
                float wy = fbm({wx * 0.5f, wz * 0.5f}) * 4.0f; // Terrain height
                verts.push_back(wx); verts.push_back(wy); verts.push_back(wz);
            }
        }
        for (int z = 0; z < size - 1; z++) {
            for (int x = 0; x < size - 1; x++) {
                int start = z * size + x;
                idx.push_back(start); idx.push_back(start + size); idx.push_back(start + 1);
                idx.push_back(start + 1); idx.push_back(start + size); idx.push_back(start + size + 1);
            }
        }
        indexCount = idx.size();

        glGenVertexArrays(1, &vao);
        glGenBuffers(1, &vbo);
        glGenBuffers(1, &ebo);

        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, verts.size() * sizeof(float), verts.data(), GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, idx.size() * sizeof(uint16_t), idx.data(), GL_STATIC_DRAW);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(0);

        glClearColor(0.95f, 0.95f, 0.92f, 1.0f); // Paper white background
        glEnable(GL_DEPTH_TEST);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv* env, jobject obj, jint width, jint height) {
        glViewport(0, 0, width, height);
        aspect = (float)width / (float)height;
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv* env, jobject obj) {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glUseProgram(program);

        // Calculate simple Perspective Matrix
        float fov = 1.0f / std::tan(1.047f / 2.0f); // 60 degrees
        float m[16] = {0};
        m[0] = fov / aspect; m[5] = fov; m[10] = -1.02f; m[11] = -1.0f; m[14] = -0.2f;

        // Apply camera offset based on player movement
        m[12] = -playerX; // Move left/right
        m[13] = -2.0f;    // Camera height
        m[14] -= 8.0f;    // Pull camera back
        
        glUniformMatrix4fv(glGetUniformLocation(program, "u_MVP"), 1, GL_FALSE, m);

        glBindVertexArray(vao);
        glDrawElements(GL_TRIANGLES, indexCount, GL_UNSIGNED_SHORT, 0);
    }

    // THE FIX FOR THE CRASHES: Proper input receivers
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_updateInput(JNIEnv* env, jobject obj, jfloat dx, jfloat dy) {
        playerX += dx * 0.1f; // Moves the world horizontally based on joystick
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv* env, jobject obj, jint actionId) {
        // Safe endpoint for button presses (prevents UnsatisfiedLinkError crashes)
    }
}
EOF
