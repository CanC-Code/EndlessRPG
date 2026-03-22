#!/bin/bash
# File: runtime/generate_engine.sh

cat << 'EOF' > app/src/main/cpp/engine.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <android/log.h>
#include <cmath>
#include <vector>
#include <chrono>

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "ProceduralEngine", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "ProceduralEngine", __VA_ARGS__)

// --- 1. SHADERS (Realistic Pencil Art & Lighting) ---
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
    // Calculate Lighting
    vec3 norm = normalize(v_Normal);
    vec3 lightDir = normalize(u_SunDirection);
    float diff = max(dot(norm, lightDir), 0.0);
    
    vec3 diffuse = diff * u_SunColor;
    vec3 ambient = mix(u_NightAmbient, vec3(0.5), diff); 
    
    // Base realistic grass/dirt tone
    vec3 terrainBase = vec3(0.3, 0.5, 0.2); 
    vec3 resultColor = (ambient + diffuse) * terrainBase;
    
    // Pencil Art Post-Processing
    float gray = dot(resultColor, vec3(0.299, 0.587, 0.114));
    float shade = 1.0;
    if (gray < 0.25) shade = 0.3;       // Heavy hatch
    else if (gray < 0.55) shade = 0.6;  // Mid hatch
    else shade = 0.95;                  // Paper
    
    vec3 graphiteColor = vec3(0.18, 0.18, 0.20);
    vec3 paperColor = vec3(0.95, 0.95, 0.92);
    vec3 finalPencil = mix(graphiteColor, paperColor, shade);
    
    FragColor = vec4(finalPencil, 1.0);
}
)";

// --- 2. C++ MATH UTILITIES ---
struct vec2 { 
    float x, y; 
    vec2(float _x=0, float _y=0) : x(_x), y(_y) {} 
};
struct vec3 { 
    float x, y, z; 
    vec3(float _x=0, float _y=0, float _z=0) : x(_x), y(_y), z(_z) {} 
};

inline float dot(vec2 a, vec2 b) { return a.x*b.x + a.y*b.y; }
inline float fract(float x) { return x - std::floor(x); }
inline vec2 floor(vec2 v) { return vec2(std::floor(v.x), std::floor(v.y)); }
inline float mix(float a, float b, float t) { return a + t * (b - a); }
inline vec3 cross(vec3 a, vec3 b) {
    return vec3(a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x);
}
inline vec3 normalize(vec3 v) {
    float len = std::sqrt(v.x*v.x + v.y*v.y + v.z*v.z);
    if(len == 0.0f) return vec3(0,1,0);
    return vec3(v.x/len, v.y/len, v.z/len);
}

// Minimal 4x4 Matrix for Camera & Projection
struct mat4 {
    float m[16] = {0};
    mat4() { m[0]=m[5]=m[10]=m[15]=1.0f; } // Identity
};

mat4 perspective(float fov, float aspect, float near, float far) {
    mat4 res;
    float f = 1.0f / std::tan(fov / 2.0f);
    res.m[0] = f / aspect;
    res.m[5] = f;
    res.m[10] = (far + near) / (near - far);
    res.m[11] = -1.0f;
    res.m[14] = (2.0f * far * near) / (near - far);
    res.m[15] = 0.0f;
    return res;
}

mat4 lookAt(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize(vec3(center.x - eye.x, center.y - eye.y, center.z - eye.z));
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    mat4 res;
    res.m[0] = s.x;  res.m[4] = s.y;  res.m[8] = s.z;
    res.m[1] = u.x;  res.m[5] = u.y;  res.m[9] = u.z;
    res.m[2] = -f.x; res.m[6] = -f.y; res.m[10] = -f.z;
    res.m[12] = -(s.x*eye.x + s.y*eye.y + s.z*eye.z);
    res.m[13] = -(u.x*eye.x + u.y*eye.y + u.z*eye.z);
    res.m[14] =  (f.x*eye.x + f.y*eye.y + f.z*eye.z);
    return res;
}

mat4 multiply(const mat4& a, const mat4& b) {
    mat4 res;
    for(int i=0; i<4; i++) {
        for(int j=0; j<4; j++) {
            res.m[i*4 + j] = a.m[i*4 + 0]*b.m[0*4 + j] + a.m[i*4 + 1]*b.m[1*4 + j] + 
                             a.m[i*4 + 2]*b.m[2*4 + j] + a.m[i*4 + 3]*b.m[3*4 + j];
        }
    }
    return res;
}

// --- 3. SEAMLESS FBM TERRAIN GENERATION ---
float random(vec2 st) {
    return fract(std::sin(dot(st, vec2(12.9898f, 78.233f))) * 43758.5453123f);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = vec2(fract(st.x), fract(st.y));
    float a = random(i);
    float b = random(vec2(i.x + 1.0f, i.y));
    float c = random(vec2(i.x, i.y + 1.0f));
    float d = random(vec2(i.x + 1.0f, i.y + 1.0f));
    vec2 u = vec2(f.x * f.x * (3.0f - 2.0f * f.x), f.y * f.y * (3.0f - 2.0f * f.y));
    return mix(a, b, u.x) + (c - a) * u.y * (1.0f - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 st) {
    float value = 0.0f;
    float amplitude = 0.5f;
    for (int i = 0; i < 6; i++) {
        value += amplitude * noise(st);
        st = vec2(st.x * 2.0f, st.y * 2.0f);
        amplitude *= 0.5f;
    }
    return value;
}

// --- 4. ENGINE STATE ---
GLuint shaderProgram, terrainVAO, terrainVBO, terrainEBO;
int indexCount = 0;
float screenAspect = 1.0f;
float internalCameraYaw = 0.0f;

GLuint compileShader(GLenum type, const char* src) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &src, NULL);
    glCompileShader(shader);
    return shader;
}

void initEngine() {
    GLuint vShader = compileShader(GL_VERTEX_SHADER, vertexShaderSrc);
    GLuint fShader = compileShader(GL_FRAGMENT_SHADER, fragmentShaderSrc);
    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vShader);
    glAttachShader(shaderProgram, fShader);
    glLinkProgram(shaderProgram);

    // Generate Seamless Terrain Mesh
    std::vector<float> vertices;
    std::vector<uint16_t> indices;
    const int gridSize = 100;
    const float scale = 0.5f;

    for (int z = 0; z < gridSize; z++) {
        for (int x = 0; x < gridSize; x++) {
            float worldX = (x - gridSize/2) * scale;
            float worldZ = (z - gridSize/2) * scale;
            float y = fbm(vec2(worldX * 0.1f, worldZ * 0.1f)) * 5.0f; // Height

            // Simple normal approximation
            float yL = fbm(vec2((worldX - 0.1f) * 0.1f, worldZ * 0.1f)) * 5.0f;
            float yR = fbm(vec2((worldX + 0.1f) * 0.1f, worldZ * 0.1f)) * 5.0f;
            float yD = fbm(vec2(worldX * 0.1f, (worldZ - 0.1f) * 0.1f)) * 5.0f;
            float yU = fbm(vec2(worldX * 0.1f, (worldZ + 0.1f) * 0.1f)) * 5.0f;
            vec3 normal = normalize(vec3(yL - yR, 2.0f, yD - yU));

            // Position
            vertices.push_back(worldX); vertices.push_back(y); vertices.push_back(worldZ);
            // Normal
            vertices.push_back(normal.x); vertices.push_back(normal.y); vertices.push_back(normal.z);
        }
    }

    for (int z = 0; z < gridSize - 1; z++) {
        for (int x = 0; x < gridSize - 1; x++) {
            int start = z * gridSize + x;
            indices.push_back(start);
            indices.push_back(start + gridSize);
            indices.push_back(start + 1);
            indices.push_back(start + 1);
            indices.push_back(start + gridSize);
            indices.push_back(start + gridSize + 1);
        }
    }
    indexCount = indices.size();

    glGenVertexArrays(1, &terrainVAO);
    glGenBuffers(1, &terrainVBO);
    glGenBuffers(1, &terrainEBO);

    glBindVertexArray(terrainVAO);
    glBindBuffer(GL_ARRAY_BUFFER, terrainVBO);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, terrainEBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(uint16_t), indices.data(), GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);

    glClearColor(0.95f, 0.95f, 0.92f, 1.0f); // Paper color
    glEnable(GL_DEPTH_TEST);
}

// --- 5. JNI BRIDGE ---
extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv* env, jobject obj) {
        initEngine();
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv* env, jobject obj, jint width, jint height) {
        glViewport(0, 0, width, height);
        screenAspect = (float)width / (float)height;
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv* env, jobject obj) {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glUseProgram(shaderProgram);

        // Update Camera based on UI Yaw
        float camX = std::sin(internalCameraYaw) * 15.0f;
        float camZ = std::cos(internalCameraYaw) * 15.0f;
        mat4 proj = perspective(1.047f, screenAspect, 0.1f, 100.0f); // 60 degree FOV
        mat4 view = lookAt(vec3(camX, 10.0f, camZ), vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 1.0f, 0.0f));
        mat4 mvp = multiply(proj, view);
        mat4 model; // Identity matrix for terrain

        glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "u_MVP"), 1, GL_FALSE, mvp.m);
        glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "u_Model"), 1, GL_FALSE, model.m);

        // Day/Night Sun
        auto now = std::chrono::system_clock::now().time_since_epoch();
        float time = std::chrono::duration_cast<std::chrono::milliseconds>(now).count() / 1000.0f;
        vec3 sunDir(std::sin(time * 0.5f), std::cos(time * 0.5f), 0.5f);
        glUniform3f(glGetUniformLocation(shaderProgram, "u_SunDirection"), sunDir.x, sunDir.y, sunDir.z);
        glUniform3f(glGetUniformLocation(shaderProgram, "u_SunColor"), 1.0f, 0.95f, 0.8f);
        glUniform3f(glGetUniformLocation(shaderProgram, "u_NightAmbient"), 0.1f, 0.1f, 0.2f);

        glBindVertexArray(terrainVAO);
        glDrawElements(GL_TRIANGLES, indexCount, GL_UNSIGNED_SHORT, 0);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_updateInput(JNIEnv* env, jobject obj, jfloat dx, jfloat dy) {
        // Rotate camera based on joystick for now
        internalCameraYaw += dx * 0.05f; 
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv* env, jobject obj, jint actionId) {
        // Handle jump/attack
    }

    JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getCameraYaw(JNIEnv* env, jobject obj) {
        return internalCameraYaw; 
    }
}
EOF
