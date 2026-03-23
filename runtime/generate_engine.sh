#!/bin/bash
# File: runtime/generate_engine.sh

cat << 'EOF' > app/src/main/cpp/engine.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <cmath>
#include <vector>

// Directly embed our Blender 3D models into memory!
#include "player_model.h"
#include "tree_model.h"

// --- Math & Physics Utilities ---
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
    res.m[0] = f / aspect; res.m[5] = f; res.m[10] = (far+near)/(near-far);
    res.m[11] = -1.0f; res.m[14] = (2.0f*far*near)/(near-far); res.m[15] = 0.0f;
    return res;
}
mat4 lookAt(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize({center.x-eye.x, center.y-eye.y, center.z-eye.z});
    vec3 s = normalize(cross(f, up)); vec3 u = cross(s, f);
    mat4 res;
    res.m[0] = s.x; res.m[4] = s.y; res.m[8] = s.z; res.m[1] = u.x; res.m[5] = u.y; res.m[9] = u.z;
    res.m[2] = -f.x; res.m[6] = -f.y; res.m[10] = -f.z;
    res.m[12] = -(s.x*eye.x + s.y*eye.y + s.z*eye.z); res.m[13] = -(u.x*eye.x + u.y*eye.y + u.z*eye.z); res.m[14] = (f.x*eye.x + f.y*eye.y + f.z*eye.z);
    return res;
}
mat4 multiply(const mat4& a, const mat4& b) {
    mat4 r; for(int i=0;i<4;i++) for(int j=0;j<4;j++) r.m[i*4+j] = a.m[i*4+0]*b.m[0*4+j] + a.m[i*4+1]*b.m[1*4+j] + a.m[i*4+2]*b.m[2*4+j] + a.m[i*4+3]*b.m[3*4+j];
    return r;
}
mat4 translate(float x, float y, float z) {
    mat4 r; r.m[12] = x; r.m[13] = y; r.m[14] = z; return r;
}
mat4 rotateY(float angle) {
    mat4 r; float c = std::cos(angle), s = std::sin(angle);
    r.m[0] = c; r.m[2] = -s; r.m[8] = s; r.m[10] = c; return r;
}
mat4 rotateX(float angle) {
    mat4 r; float c = std::cos(angle), s = std::sin(angle);
    r.m[5] = c; r.m[6] = s; r.m[9] = -s; r.m[10] = c; return r;
}

// Procedural Terrain
float random(vec2 st) { return fract(std::sin(dot(st, {12.9898f, 78.233f})) * 43758.5f); }
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

// --- SHADERS ---
const char* vShaderStr = R"(#version 300 es
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;
uniform mat4 u_MVP;
uniform mat4 u_Model;
out vec3 v_Normal;
out float v_Height;
void main() {
    v_Height = (u_Model * vec4(aPos, 1.0)).y;
    v_Normal = mat3(transpose(inverse(u_Model))) * aNormal;
    gl_Position = u_MVP * vec4(aPos, 1.0);
}
)";

const char* fShaderStr = R"(#version 300 es
precision highp float;
in vec3 v_Normal;
in float v_Height;
out vec4 FragColor;
void main() {
    vec3 lightDir = normalize(vec3(0.5, 1.0, 0.3));
    float diff = max(dot(normalize(v_Normal), lightDir), 0.0);
    
    // Pencil Hatching Logic
    float shade = 0.95; // Paper
    float intensity = diff * 0.7 + (v_Height * 0.05);
    
    if (intensity < 0.3) shade = 0.25;      // Heavy graphite
    else if (intensity < 0.6) shade = 0.55; // Mid hatching
    else if (intensity < 0.8) shade = 0.8;  // Light hatch
    
    vec3 graphiteColor = vec3(0.15, 0.15, 0.2);
    vec3 paperColor = vec3(0.95, 0.95, 0.92);
    FragColor = vec4(mix(graphiteColor, paperColor, shade), 1.0);
}
)";

// --- GAME STATE ---
GLuint program, vaoTerrain, vaoPlayer, vaoTree;
GLuint vboTerrain, vboPlayer, vboTree;
int terrainIndexCount = 0;
float aspect = 1.0f;

// Physics & Input
float pX = 0.0f, pZ = 0.0f;
float pYVelocity = 0.0f;
float pYOffset = 0.0f;
float playerRotation = 0.0f;
float attackTimer = 0.0f;

float inputDx = 0.0f, inputDy = 0.0f;
float camYaw = 0.0f, camZoom = 15.0f;

GLuint compile(GLenum type, const char* src) {
    GLuint s = glCreateShader(type); glShaderSource(s, 1, &src, nullptr); glCompileShader(s); return s;
}

GLuint createVAO(const float* data, int count, GLuint& vbo) {
    GLuint vao; glGenVertexArrays(1, &vao); glGenBuffers(1, &vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, count * 6 * sizeof(float), data, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), (void*)0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), (void*)(3*sizeof(float))); glEnableVertexAttribArray(1);
    return vao;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv* env, jobject obj) {
        program = glCreateProgram();
        glAttachShader(program, compile(GL_VERTEX_SHADER, vShaderStr));
        glAttachShader(program, compile(GL_FRAGMENT_SHADER, fShaderStr));
        glLinkProgram(program);

        // Build Terrain with Normals
        std::vector<float> verts; std::vector<uint16_t> idx;
        const int size = 80; const float scale = 0.5f;
        for (int z = 0; z < size; z++) {
            for (int x = 0; x < size; x++) {
                float wx = (x - size/2) * scale; float wz = (z - size/2) * scale;
                float wy = fbm({wx * 0.25f, wz * 0.25f}) * 8.0f;
                
                // Normal approximation
                float hL = fbm({(wx - 0.1f) * 0.25f, wz * 0.25f}) * 8.0f;
                float hR = fbm({(wx + 0.1f) * 0.25f, wz * 0.25f}) * 8.0f;
                float hD = fbm({wx * 0.25f, (wz - 0.1f) * 0.25f}) * 8.0f;
                float hU = fbm({wx * 0.25f, (wz + 0.1f) * 0.25f}) * 8.0f;
                vec3 n = normalize({hL - hR, 2.0f, hD - hU});

                verts.push_back(wx); verts.push_back(wy); verts.push_back(wz);
                verts.push_back(n.x); verts.push_back(n.y); verts.push_back(n.z);
            }
        }
        for (int z = 0; z < size - 1; z++) {
            for (int x = 0; x < size - 1; x++) {
                int start = z * size + x;
                idx.push_back(start); idx.push_back(start + size); idx.push_back(start + 1);
                idx.push_back(start + 1); idx.push_back(start + size); idx.push_back(start + size + 1);
            }
        }
        terrainIndexCount = idx.size();

        GLuint ebo;
        glGenVertexArrays(1, &vaoTerrain); glGenBuffers(1, &vboTerrain); glGenBuffers(1, &ebo);
        glBindVertexArray(vaoTerrain);
        glBindBuffer(GL_ARRAY_BUFFER, vboTerrain); glBufferData(GL_ARRAY_BUFFER, verts.size()*sizeof(float), verts.data(), GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo); glBufferData(GL_ELEMENT_ARRAY_BUFFER, idx.size()*sizeof(uint16_t), idx.data(), GL_STATIC_DRAW);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), (void*)0); glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), (void*)(3*sizeof(float))); glEnableVertexAttribArray(1);

        // Load Player and Tree into OpenGL
        vaoPlayer = createVAO(player_verts, player_count, vboPlayer);
        vaoTree = createVAO(tree_verts, tree_count, vboTree);

        glEnable(GL_DEPTH_TEST);
        glClearColor(0.95f, 0.95f, 0.92f, 1.0f);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv* env, jobject obj, jint width, jint height) {
        glViewport(0, 0, width, height); aspect = (float)width / (float)height;
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv* env, jobject obj) {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); glUseProgram(program);

        // Physics Update
        if (inputDx != 0.0f || inputDy != 0.0f) {
            float s = std::sin(camYaw), c = std::cos(camYaw);
            pX += (inputDx * c - inputDy * s) * 0.15f;
            pZ += (inputDx * s + inputDy * c) * 0.15f;
            playerRotation = std::atan2(inputDx * c - inputDy * s, inputDx * s + inputDy * c);
        }
        
        // Jump Physics
        pYOffset += pYVelocity;
        pYVelocity -= 0.02f; // Gravity
        if (pYOffset < 0.0f) { pYOffset = 0.0f; pYVelocity = 0.0f; }

        float groundHeight = fbm({pX * 0.25f, pZ * 0.25f}) * 8.0f;
        float actualPlayerY = groundHeight + pYOffset;

        // Camera Logic
        mat4 proj = perspective(1.047f, aspect, 0.1f, 150.0f);
        float eyeX = pX - std::sin(camYaw) * camZoom;
        float eyeZ = pZ - std::cos(camYaw) * camZoom;
        float eyeY = fbm({eyeX * 0.25f, eyeZ * 0.25f}) * 8.0f + (camZoom * 0.6f); 
        mat4 view = lookAt({eyeX, eyeY, eyeZ}, {pX, actualPlayerY, pZ}, {0.0f, 1.0f, 0.0f});

        GLint mvpLoc = glGetUniformLocation(program, "u_MVP");
        GLint modelLoc = glGetUniformLocation(program, "u_Model");

        // 1. Draw Terrain
        mat4 terrainModel;
        glUniformMatrix4fv(modelLoc, 1, GL_FALSE, terrainModel.m);
        glUniformMatrix4fv(mvpLoc, 1, GL_FALSE, multiply(proj, multiply(view, terrainModel)).m);
        glBindVertexArray(vaoTerrain); glDrawElements(GL_TRIANGLES, terrainIndexCount, GL_UNSIGNED_SHORT, 0);

        // 2. Draw Trees
        glBindVertexArray(vaoTree);
        for (int i = -2; i <= 2; i++) {
            for (int j = -2; j <= 2; j++) {
                float tx = i * 10.0f; float tz = j * 10.0f;
                float ty = fbm({tx * 0.25f, tz * 0.25f}) * 8.0f;
                mat4 treeModel = translate(tx, ty, tz);
                glUniformMatrix4fv(modelLoc, 1, GL_FALSE, treeModel.m);
                glUniformMatrix4fv(mvpLoc, 1, GL_FALSE, multiply(proj, multiply(view, treeModel)).m);
                glDrawArrays(GL_TRIANGLES, 0, tree_count);
            }
        }

        // 3. Draw Player
        mat4 playerModel = translate(pX, actualPlayerY, pZ);
        playerModel = multiply(playerModel, rotateY(playerRotation));
        
        // Attack Animation logic
        if (attackTimer > 0.0f) {
            playerModel = multiply(playerModel, rotateX(std::sin(attackTimer * 10.0f) * 1.5f)); // Swing motion
            attackTimer -= 0.05f;
        }

        glUniformMatrix4fv(modelLoc, 1, GL_FALSE, playerModel.m);
        glUniformMatrix4fv(mvpLoc, 1, GL_FALSE, multiply(proj, multiply(view, playerModel)).m);
        glBindVertexArray(vaoPlayer); glDrawArrays(GL_TRIANGLES, 0, player_count);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_updateInput(JNIEnv* env, jobject obj, jfloat dx, jfloat dy) {
        inputDx = dx; inputDy = dy;
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_updateCamera(JNIEnv* env, jobject obj, jfloat yaw, jfloat zoom) {
        camYaw = yaw; camZoom = zoom;
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv* env, jobject obj, jint actionId) {
        if (actionId == 4 && pYOffset <= 0.0f) pYVelocity = 0.4f; // Jump Button
        if (actionId == 1) attackTimer = 1.0f; // Attack Button triggers animation
    }
    JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getCameraYaw(JNIEnv* env, jobject obj) {
        return camYaw;
    }
}
EOF
