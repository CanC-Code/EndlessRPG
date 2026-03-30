#include "Renderer.h"
#include <GLES3/gl31.h>
#include <cmath>
#include <android/log.h>
#include <vector>

#define LOG_TAG "ProceduralEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static float gTime = 0.0f;
static GLuint emptyVAO = 0;

float getTerrainHeight(float x, float z) {
    float h = sin(x * 0.04f) * 4.0f;
    h += cos(z * 0.03f) * 3.0f;
    h += sin((x + z) * 0.1f) * 1.5f;
    return h;
}

// ============================================================================
// MATRIX MATH HELPERS
// ============================================================================
void loadIdentity(float* m) { for(int i=0; i<16; i++) m[i] = (i%5 == 0) ? 1.0f : 0.0f; }
void perspective(float* m, float fovY, float aspect, float zNear, float zFar) {
    float f = 1.0f / tan(fovY / 2.0f);
    loadIdentity(m);
    m[0] = f / aspect; m[5] = f;
    m[10] = (zFar + zNear) / (zNear - zFar); m[11] = -1.0f;
    m[14] = (2.0f * zFar * zNear) / (zNear - zFar); m[15] = 0.0f;
}
void lookAt(float* m, float ex, float ey, float ez, float cx, float cy, float cz, float ux, float uy, float uz) {
    float f[3] = {cx - ex, cy - ey, cz - ez};
    float magF = sqrt(f[0]*f[0] + f[1]*f[1] + f[2]*f[2]);
    f[0]/=magF; f[1]/=magF; f[2]/=magF;
    float s[3] = { f[1]*uz - f[2]*uy, f[2]*ux - f[0]*uz, f[0]*uy - f[1]*ux };
    float magS = sqrt(s[0]*s[0] + s[1]*s[1] + s[2]*s[2]);
    s[0]/=magS; s[1]/=magS; s[2]/=magS;
    float u_prime[3] = { s[1]*f[2] - s[2]*f[1], s[2]*f[0] - s[0]*f[2], s[0]*f[1] - s[1]*f[0] };
    loadIdentity(m);
    m[0] = s[0];       m[4] = s[1];       m[8] = s[2];
    m[1] = u_prime[0]; m[5] = u_prime[1]; m[9] = u_prime[2];
    m[2] = -f[0];      m[6] = -f[1];      m[10] = -f[2];
    m[12] = -(s[0]*ex + s[1]*ey + s[2]*ez);
    m[13] = -(u_prime[0]*ex + u_prime[1]*ey + u_prime[2]*ez);
    m[14] = f[0]*ex + f[1]*ey + f[2]*ez;
}
void multiplyMatrix(float* out, const float* a, const float* b) {
    for(int c=0; c<4; c++) {
        for(int r=0; r<4; r++) {
            out[c*4+r] = a[0*4+r]*b[c*4+0] + a[1*4+r]*b[c*4+1] + a[2*4+r]*b[c*4+2] + a[3*4+r]*b[c*4+3];
        }
    }
}

// ============================================================================
// GLSL SHADERS
// ============================================================================
const char* terrainVS = R"(#version 310 es
layout(location = 0) in vec3 aPos;
uniform mat4 u_MVP;
uniform vec3 u_CameraPos;
out vec3 vWorldPos;
out float vDist;
out vec3 vNormal;

float getHeight(vec2 p) { 
    return sin(p.x * 0.04) * 4.0 + cos(p.y * 0.03) * 3.0 + sin((p.x + p.y) * 0.1) * 1.5; 
}

void main() {
    vec3 pos = aPos;
    pos.x += floor(u_CameraPos.x);
    pos.z += floor(u_CameraPos.z);
    pos.y = getHeight(pos.xz);

    float delta = 0.1;
    vNormal = normalize(vec3(getHeight(pos.xz+vec2(-delta,0))-getHeight(pos.xz+vec2(delta,0)), 2.0*delta, getHeight(pos.xz+vec2(0,-delta))-getHeight(pos.xz+vec2(0,delta))));
    vWorldPos = pos;
    vDist = distance(pos, u_CameraPos);
    gl_Position = u_MVP * vec4(pos, 1.0);
}
)";

const char* terrainFS = R"(#version 310 es
precision mediump float;
in vec3 vWorldPos;
in float vDist;
in vec3 vNormal;
out vec4 FragColor;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i), hash(i+vec2(1.0,0.0)), f.x), mix(hash(i+vec2(0.0,1.0)), hash(i+vec2(1.0,1.0)), f.x), f.y);
}

void main() {
    float n = noise(vWorldPos.xz * 0.4) * 0.5 + noise(vWorldPos.xz * 2.0) * 0.2;
    vec3 dirt = vec3(0.12, 0.08, 0.05);
    vec3 moss = vec3(0.1, 0.15, 0.08);
    vec3 baseColor = mix(moss, dirt, n);
    float fog = clamp((120.0 - vDist) / 60.0, 0.0, 1.0);
    FragColor = vec4(mix(vec3(0.55, 0.7, 0.85), baseColor * (0.7 + n), fog), 1.0);
}
)";

const char* grassCS = R"(#version 310 es
layout(local_size_x = 256) in;
struct Blade { vec4 pos; vec4 dir; }; // pos.w = random rotation angle
layout(std430, binding = 0) buffer GrassBuffer { Blade blades[]; };

uniform vec3 u_CameraPos;
uniform float u_Time;

float rand(vec2 co){ return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453); }
float getHeight(vec2 p) { return sin(p.x * 0.04) * 4.0 + cos(p.y * 0.03) * 3.0 + sin((p.x + p.y) * 0.1) * 1.5; }

void main() {
    uint i = gl_GlobalInvocationID.x;
    float gridSize = 50.0;
    float xIdx = float(i % 256u);
    float zIdx = float(i / 256u);

    float worldX = u_CameraPos.x + (xIdx/256.0 * gridSize - gridSize*0.5);
    float worldZ = u_CameraPos.z + (zIdx/256.0 * gridSize - gridSize*0.5);
    
    float seed = rand(vec2(xIdx, zIdx));
    worldX += (seed - 0.5) * 0.6;
    worldZ += (rand(vec2(zIdx, xIdx)) - 0.5) * 0.6;

    float angle = seed * 6.28318; // Fixed random rotation per blade
    float wind = sin(u_Time * 1.3 + worldX * 0.2) * 0.3;

    blades[i].pos = vec4(worldX, getHeight(vec2(worldX, worldZ)), worldZ, angle);
    blades[i].dir = vec4(wind, 1.0 + seed*0.4, wind*0.5, 0.0);
}
)";

const char* grassVS = R"(#version 310 es
struct Blade { vec4 pos; vec4 dir; };
layout(std430, binding = 0) buffer GrassBuffer { Blade blades[]; };
uniform mat4 u_MVP;
uniform vec3 u_CameraPos;
out float v_Height;
out float vDist;

void main() {
    Blade b = blades[gl_InstanceID];
    vDist = distance(b.pos.xyz, u_CameraPos);
    if (vDist > 45.0) { gl_Position = vec4(0.0); return; }

    float angle = b.pos.w;
    // For Cross-Quad: Vertices 0-2 = first plane, 3-5 = second plane (rotated 90 deg)
    if (gl_VertexID >= 3) angle += 1.5708; 

    vec3 dir = vec3(sin(angle), 0.0, cos(angle));
    float w = 0.04;
    float h = 0.5 * b.dir.y;
    
    vec3 pos = b.pos.xyz;
    int vertId = gl_VertexID % 3;
    
    if (vertId == 0) { pos -= dir * w; v_Height = 0.0; }
    else if (vertId == 1) { pos += dir * w; v_Height = 0.0; }
    else { pos += b.dir.xzy * h; v_Height = 1.0; }

    gl_Position = u_MVP * vec4(pos, 1.0);
}
)";

const char* grassFS = R"(#version 310 es
precision mediump float;
in float v_Height;
in float vDist;
out vec4 FragColor;
void main() {
    vec3 col = mix(vec3(0.04, 0.12, 0.04), vec3(0.35, 0.65, 0.1), v_Height);
    float fog = clamp((45.0 - vDist) / 15.0, 0.0, 1.0);
    FragColor = vec4(mix(vec3(0.55, 0.7, 0.85), col, fog), 1.0);
}
)";

// ============================================================================
// ENGINE IMPLEMENTATION
// ============================================================================
GrassRenderer::GrassRenderer() : terrainVAO(0), terrainVBO(0), terrainEBO(0), terrainProgram(0), grassProgram(0), grassComputeProgram(0), grassSSBO(0), indexCount(0) {
    cameraX = 0.0f; cameraZ = 0.0f;
    cameraY = 1.8f; camYaw = 0.0f; camPitch = 0.0f; 
}

GrassRenderer::~GrassRenderer() {}
void GrassRenderer::init() {}

GLuint compileShader(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);
    return shader;
}

void GrassRenderer::setupShaders() {
    GLuint tvs = compileShader(GL_VERTEX_SHADER, terrainVS);
    GLuint tfs = compileShader(GL_FRAGMENT_SHADER, terrainFS);
    terrainProgram = glCreateProgram();
    glAttachShader(terrainProgram, tvs); glAttachShader(terrainProgram, tfs); glLinkProgram(terrainProgram);

    GLuint cs = compileShader(GL_COMPUTE_SHADER, grassCS);
    grassComputeProgram = glCreateProgram();
    glAttachShader(grassComputeProgram, cs); glLinkProgram(grassComputeProgram);

    GLuint gvs = compileShader(GL_VERTEX_SHADER, grassVS);
    GLuint gfs = compileShader(GL_FRAGMENT_SHADER, grassFS);
    grassProgram = glCreateProgram();
    glAttachShader(grassProgram, gvs); glAttachShader(grassProgram, gfs); glLinkProgram(grassProgram);

    glGenBuffers(1, &grassSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, grassSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, 65536 * 32, nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, grassSSBO);
    glGenVertexArrays(1, &emptyVAO);
}

void GrassRenderer::generateTerrainGrid() {
    std::vector<float> vertices;
    std::vector<unsigned int> indices;
    int res = 160; float size = 320.0f;
    for(int z = 0; z < res; z++) {
        for(int x = 0; x < res; x++) {
            vertices.push_back((x / (float)res) * size - size*0.5f);
            vertices.push_back(0.0f); vertices.push_back((z / (float)res) * size - size*0.5f);
        }
    }
    for(int z = 0; z < res - 1; z++) {
        for(int x = 0; x < res - 1; x++) {
            int tl = (z * res) + x; int bl = ((z + 1) * res) + x;
            indices.insert(indices.end(), { (unsigned int)tl, (unsigned int)bl, (unsigned int)tl+1, (unsigned int)tl+1, (unsigned int)bl, (unsigned int)bl+1 });
        }
    }
    indexCount = indices.size();
    glGenVertexArrays(1, &terrainVAO); glGenBuffers(1, &terrainVBO); glGenBuffers(1, &terrainEBO);
    glBindVertexArray(terrainVAO);
    glBindBuffer(GL_ARRAY_BUFFER, terrainVBO); glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, terrainEBO); glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned int), indices.data(), GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx; moveY = my; 
    camYaw += lx * 0.004f; camPitch += ly * 0.004f;
    if (camPitch > 1.2f) camPitch = 1.2f; if (camPitch < -1.2f) camPitch = -1.2f;
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    if (width <= 0 || height <= 0) return;
    gTime = time;
    if (terrainVAO == 0) { generateTerrainGrid(); setupShaders(); }
    cameraX += (moveX * cos(camYaw) + moveY * sin(camYaw)) * dt * 9.0f;
    cameraZ += (-moveY * cos(camYaw) + moveX * sin(camYaw)) * dt * 9.0f; 
    cameraY = getTerrainHeight(cameraX, cameraZ) + 1.75f;
    render(width, height);
}

void GrassRenderer::render(int width, int height) {
    glViewport(0, 0, width, height);
    glClearColor(0.55f, 0.7f, 0.85f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE); // Important for two-sided grass!

    float proj[16], view[16], mvp[16];
    perspective(proj, 60.0f * (M_PI / 180.0f), (float)width / (float)height, 0.1f, 1000.0f);
    lookAt(view, cameraX, cameraY, cameraZ, cameraX + sin(camYaw)*cos(camPitch), cameraY - sin(camPitch), cameraZ - cos(camYaw)*cos(camPitch), 0.0f, 1.0f, 0.0f);
    multiplyMatrix(mvp, proj, view);

    glUseProgram(grassComputeProgram);
    glUniform3f(glGetUniformLocation(grassComputeProgram, "u_CameraPos"), cameraX, cameraY, cameraZ);
    glUniform1f(glGetUniformLocation(grassComputeProgram, "u_Time"), gTime);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, grassSSBO);
    glDispatchCompute(256, 1, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    glUseProgram(terrainProgram);
    glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "u_MVP"), 1, GL_FALSE, mvp);
    glUniform3f(glGetUniformLocation(terrainProgram, "u_CameraPos"), cameraX, cameraY, cameraZ);
    glBindVertexArray(terrainVAO);
    glDrawElements(GL_TRIANGLES, indexCount, GL_UNSIGNED_INT, 0);

    glUseProgram(grassProgram);
    glUniformMatrix4fv(glGetUniformLocation(grassProgram, "u_MVP"), 1, GL_FALSE, mvp);
    glUniform3f(glGetUniformLocation(grassProgram, "u_CameraPos"), cameraX, cameraY, cameraZ);
    glBindVertexArray(emptyVAO);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, grassSSBO);
    
    // Updated: Drawing 6 vertices per blade (2 triangles forming a cross)
    glDrawArraysInstanced(GL_TRIANGLES, 0, 6, 65536);
}
