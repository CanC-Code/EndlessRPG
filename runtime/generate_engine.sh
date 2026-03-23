#!/bin/bash
# File: runtime/generate_engine.sh

cat << 'EOF' > app/src/main/cpp/engine.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <cmath>
#include <vector>
#include <chrono>

// ==========================================
// MATHEMATICS & PROCEDURAL GENERATION CORE
// ==========================================
struct vec2 { float x, y; };
struct vec3 { float x, y, z; };
inline float dot(vec2 a, vec2 b) { return a.x*b.x + a.y*b.y; }
inline float fract(float x) { return x - std::floor(x); }
inline float mix(float a, float b, float t) { return a + t * (b - a); }
inline vec3 normalize(vec3 v) { float l = std::sqrt(v.x*v.x + v.y*v.y + v.z*v.z); return {v.x/l, v.y/l, v.z/l}; }
inline vec3 cross(vec3 a, vec3 b) { return {a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x}; }

struct mat4 { float m[16] = {0}; mat4() { m[0]=m[5]=m[10]=m[15]=1.0f; } };

mat4 perspective(float fov, float aspect, float near, float far) {
    mat4 res; float f = 1.0f / std::tan(fov / 2.0f);
    res.m[0] = f / aspect; res.m[5] = f; res.m[10] = (far + near) / (near - far);
    res.m[11] = -1.0f; res.m[14] = (2.0f * far * near) / (near - far); res.m[15] = 0.0f;
    return res;
}

mat4 lookAt(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize({center.x - eye.x, center.y - eye.y, center.z - eye.z});
    vec3 s = normalize(cross(f, up)); vec3 u = cross(s, f);
    mat4 res;
    res.m[0] = s.x; res.m[4] = s.y; res.m[8] = s.z;
    res.m[1] = u.x; res.m[5] = u.y; res.m[9] = u.z;
    res.m[2] = -f.x; res.m[6] = -f.y; res.m[10] = -f.z;
    res.m[12] = -(s.x*eye.x + s.y*eye.y + s.z*eye.z);
    res.m[13] = -(u.x*eye.x + u.y*eye.y + u.z*eye.z);
    res.m[14] = (f.x*eye.x + f.y*eye.y + f.z*eye.z);
    return res;
}

mat4 multiply(const mat4& a, const mat4& b) {
    mat4 r;
    for(int i=0; i<4; i++) for(int j=0; j<4; j++)
        r.m[i*4+j] = a.m[i*4+0]*b.m[0*4+j] + a.m[i*4+1]*b.m[1*4+j] + a.m[i*4+2]*b.m[2*4+j] + a.m[i*4+3]*b.m[3*4+j];
    return r;
}

// Fractional Brownian Motion Terrain Generator
float random(vec2 st) { return fract(std::sin(dot(st, {12.9898f, 78.233f})) * 43758.5453f); }
float noise(vec2 st) {
    vec2 i = {std::floor(st.x), std::floor(st.y)}; vec2 f = {st.x - i.x, st.y - i.y};
    float a = random(i), b = random({i.x + 1.0f, i.y}), c = random({i.x, i.y + 1.0f}), d = random({i.x + 1.0f, i.y + 1.0f});
    vec2 u = {f.x*f.x*(3.0f-2.0f*f.x), f.y*f.y*(3.0f-2.0f*f.y)};
    return mix(a, b, u.x) + (c - a)*u.y*(1.0f - u.x) + (d - b)*u.x*u.y;
}
float fbm(vec2 st) {
    float v = 0.0f, a = 0.5f;
    for (int i=0; i<5; i++) { v += a * noise(st); st.x *= 2.0f; st.y *= 2.0f; a *= 0.5f; }
    return v;
}

// ==========================================
// GLSL SHADERS (Pencil Art Aesthetics)
// ==========================================
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
uniform float u_TimeOfDay;
out vec4 FragColor;
void main() {
    float shade = 0.95; // Base paper brightness
    
    // Pencil hatching logic based on terrain elevation
    if (v_Height < 0.5) shade = 0.25;      // Heavy graphite deep in valleys
    else if (v_Height < 1.8) shade = 0.55; // Mid-tone hatching on slopes
    else if (v_Height > 3.5) shade = 1.0;  // Clean paper at mountain peaks
    
    vec3 graphiteColor = vec3(0.18, 0.18, 0.22);
    vec3 paperColor = vec3(0.95, 0.95, 0.90);
    
    // Dim the paper color if it is nighttime
    if (u_TimeOfDay < 0.0) {
        paperColor *= 0.3; // Nighttime effect
    }

    FragColor = vec4(mix(graphiteColor, paperColor, shade), 1.0);
}
)";

// ==========================================
// GLOBAL ENGINE STATE
// ==========================================
GLuint program, vao, vbo, ebo;
int indexCount = 0;
float aspect = 1.0f;

// Player & Camera Physics
float pX = 0.0f, pZ = 0.0f; // World coordinates
float inputDx = 0.0f, inputDy = 0.0f; // Joystick Deltas
float camYaw = 0.0f, camZoom = 15.0f;

GLuint compile(GLenum type, const char* src) {
    GLuint s = glCreateShader(type); glShaderSource(s, 1, &src, nullptr); glCompileShader(s); return s;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv* env, jobject obj) {
        program = glCreateProgram();
        glAttachShader(program, compile(GL_VERTEX_SHADER, vShaderStr));
        glAttachShader(program, compile(GL_FRAGMENT_SHADER, fShaderStr));
        glLinkProgram(program);

        // Generate the massive seamless chunk mesh
        std::vector<float> verts; std::vector<uint16_t> idx;
        const int size = 100; // Increased map grid density
        const float scale = 0.4f;
        
        for (int z = 0; z < size; z++) {
            for (int x = 0; x < size; x++) {
                float wx = (x - size/2) * scale;
                float wz = (z - size/2) * scale;
                float wy = fbm({wx * 0.25f, wz * 0.25f}) * 8.0f; // Procedural Elevation
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

        glGenVertexArrays(1, &vao); glGenBuffers(1, &vbo); glGenBuffers(1, &ebo);
        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, vbo); glBufferData(GL_ARRAY_BUFFER, verts.size()*sizeof(float), verts.data(), GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo); glBufferData(GL_ELEMENT_ARRAY_BUFFER, idx.size()*sizeof(uint16_t), idx.data(), GL_STATIC_DRAW);
        
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), (void*)0); 
        glEnableVertexAttribArray(0);

        glEnable(GL_DEPTH_TEST);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv* env, jobject obj, jint width, jint height) {
        glViewport(0, 0, width, height); aspect = (float)width / (float)height;
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv* env, jobject obj) {
        // --- Day/Night Cycle Logic ---
        auto now = std::chrono::system_clock::now().time_since_epoch();
        float timeSeconds = std::chrono::duration_cast<std::chrono::milliseconds>(now).count() / 1000.0f;
        float sunHeight = std::sin(timeSeconds * 0.2f); // Slow oscillating sun
        
        // Dynamically alter sky clear color based on sun height
        if (sunHeight > 0.0f) {
            glClearColor(0.95f, 0.95f, 0.92f, 1.0f); // Daytime paper color
        } else {
            glClearColor(0.05f, 0.05f, 0.1f, 1.0f);  // Nighttime dark indigo
        }

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); 
        glUseProgram(program);
        glUniform1f(glGetUniformLocation(program, "u_TimeOfDay"), sunHeight);

        // --- Player Physics & Matrix Math ---
        float s = std::sin(camYaw), c = std::cos(camYaw);
        pX += (inputDx * c - inputDy * s) * 0.15f;
        pZ += (inputDx * s + inputDy * c) * 0.15f;

        mat4 proj = perspective(1.047f, aspect, 0.1f, 150.0f);
        float eyeX = pX - std::sin(camYaw) * camZoom;
        float eyeZ = pZ - std::cos(camYaw) * camZoom;
        
        // Ensure camera never clips through the generated terrain
        float groundHeight = fbm({eyeX * 0.25f, eyeZ * 0.25f}) * 8.0f;
        float eyeY = groundHeight + (camZoom * 0.6f); 
        
        float targetY = fbm({pX * 0.25f, pZ * 0.25f}) * 8.0f;
        
        mat4 view = lookAt({eyeX, eyeY, eyeZ}, {pX, targetY, pZ}, {0.0f, 1.0f, 0.0f});
        mat4 mvp = multiply(proj, view);
        
        glUniformMatrix4fv(glGetUniformLocation(program, "u_MVP"), 1, GL_FALSE, mvp.m);
        
        // Execute draw
        glBindVertexArray(vao); 
        glDrawElements(GL_TRIANGLES, indexCount, GL_UNSIGNED_SHORT, 0);
    }

    // Input Receiver Endpoints
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_updateInput(JNIEnv* env, jobject obj, jfloat dx, jfloat dy) {
        inputDx = dx; inputDy = dy;
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_updateCamera(JNIEnv* env, jobject obj, jfloat yaw, jfloat zoom) {
        camYaw = yaw; camZoom = zoom;
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv* env, jobject obj, jint actionId) {
        // Safe endpoint for attack/jump triggers
    }
    JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getCameraYaw(JNIEnv* env, jobject obj) {
        return camYaw;
    }
}
EOF
