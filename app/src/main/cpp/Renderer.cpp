#include "Renderer.h"
#include <GLES3/gl31.h>
#include <cmath>
#include <android/log.h>
#include <vector>

#define LOG_TAG "ProceduralEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static float gTime = 0.0f;
static GLuint emptyVAO = 0; // Used for instanced drawing without VBOs

// ============================================================================
// MATRIX MATH HELPERS
// ============================================================================
void loadIdentity(float* m) {
    for(int i=0; i<16; i++) m[i] = (i%5 == 0) ? 1.0f : 0.0f;
}

void perspective(float* m, float fovY, float aspect, float zNear, float zFar) {
    float f = 1.0f / tan(fovY / 2.0f);
    loadIdentity(m);
    m[0] = f / aspect;
    m[5] = f;
    m[10] = (zFar + zNear) / (zNear - zFar);
    m[11] = -1.0f;
    m[14] = (2.0f * zFar * zNear) / (zNear - zFar);
    m[15] = 0.0f;
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
// GLSL SHADERS (Terrain + Compute Grass + Render Grass)
// ============================================================================
const char* terrainVS = R"(#version 310 es
layout(location = 0) in vec3 aPos;
uniform mat4 u_MVP;
out vec3 vWorldPos;
void main() {
    vWorldPos = aPos;
    gl_Position = u_MVP * vec4(aPos, 1.0);
}
)";

const char* terrainFS = R"(#version 310 es
precision mediump float;
in vec3 vWorldPos;
out vec4 FragColor;
void main() {
    float grid = mod(floor(vWorldPos.x) + floor(vWorldPos.z), 2.0);
    // Deep rich dirt colors beneath the grass
    vec3 color1 = vec3(0.18, 0.12, 0.08); 
    vec3 color2 = vec3(0.15, 0.10, 0.06); 
    FragColor = vec4(mix(color1, color2, grid), 1.0);
}
)";

// COMPUTE SHADER: Generates 65k blades of grass dynamically in a radius around the camera
const char* grassCS = R"(#version 310 es
layout(local_size_x = 256) in;
struct Blade { vec4 pos; vec4 dir; };
layout(std430, binding = 0) buffer GrassBuffer { Blade blades[]; };

uniform vec3 u_CameraPos;
uniform float u_Time;

float rand(vec2 co){ return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453); }

void main() {
    uint i = gl_GlobalInvocationID.x;
    float gridSize = 40.0; // 40x40 meter patch around camera
    int gridX = int(i % 256u);
    int gridZ = int(i / 256u);

    float localX = (float(gridX) / 256.0) * gridSize - (gridSize / 2.0);
    float localZ = (float(gridZ) / 256.0) * gridSize - (gridSize / 2.0);

    // Snap to grid spacing to prevent visual swimming
    float spacing = gridSize / 256.0;
    float snappedCamX = floor(u_CameraPos.x / spacing) * spacing;
    float snappedCamZ = floor(u_CameraPos.z / spacing) * spacing;

    float worldX = snappedCamX + localX;
    float worldZ = snappedCamZ + localZ;

    // Organic randomized placement
    worldX += (rand(vec2(gridX, gridZ)) - 0.5) * spacing * 0.9;
    worldZ += (rand(vec2(gridZ, gridX)) - 0.5) * spacing * 0.9;

    // Dynamic rolling wind waves
    float windX = sin(u_Time * 1.5 + worldX * 0.2 + worldZ * 0.1) * 0.4;
    float windZ = cos(u_Time * 1.2 + worldZ * 0.2 - worldX * 0.1) * 0.4;

    blades[i].pos = vec4(worldX, 0.0, worldZ, 1.0);
    blades[i].dir = vec4(windX, 1.0, windZ, 0.0);
}
)";

// GRASS VERTEX SHADER: Uses empty Instanced Draw to build geometry on the fly!
const char* grassVS = R"(#version 310 es
struct Blade { vec4 pos; vec4 dir; };
layout(std430, binding = 0) buffer GrassBuffer { Blade blades[]; };

uniform mat4 u_MVP;
uniform vec3 u_CameraPos;
out float v_Height;

void main() {
    Blade b = blades[gl_InstanceID];
    vec3 basePos = b.pos.xyz;

    // Fast Frustum / Distance Culling
    if (distance(basePos, u_CameraPos) > 20.0) {
        gl_Position = vec4(0.0);
        return;
    }

    // Billboard towards camera
    vec3 toCam = normalize(u_CameraPos - basePos);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), toCam));

    float width = 0.04;
    float height = 0.65;

    vec3 pos = basePos;
    if (gl_VertexID == 0) {
        pos -= right * width;
        v_Height = 0.0;
    } else if (gl_VertexID == 1) {
        pos += right * width;
        v_Height = 0.0;
    } else if (gl_VertexID == 2) {
        pos += b.dir.xyz * height; // Sway with wind
        v_Height = 1.0;
    }

    gl_Position = u_MVP * vec4(pos, 1.0);
}
)";

const char* grassFS = R"(#version 310 es
precision mediump float;
in float v_Height;
out vec4 FragColor;
void main() {
    vec3 rootColor = vec3(0.05, 0.25, 0.05);
    vec3 tipColor = vec3(0.4, 0.8, 0.2);
    FragColor = vec4(mix(rootColor, tipColor, v_Height), 1.0);
}
)";

// ============================================================================
// ENGINE IMPLEMENTATION
// ============================================================================
GrassRenderer::GrassRenderer() : terrainVAO(0), terrainVBO(0), terrainEBO(0), terrainProgram(0), grassProgram(0), grassComputeProgram(0), grassSSBO(0), indexCount(0) {
    cameraX = 0.0f;
    cameraY = 1.8f; // Eye level!
    cameraZ = 0.0f;
    camYaw = 0.0f;
    camPitch = 0.0f; 
}

GrassRenderer::~GrassRenderer() {}
void GrassRenderer::init() {}

GLuint compileShader(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);
    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char log[512];
        glGetShaderInfoLog(shader, 512, nullptr, log);
        LOGE("Shader Compilation Failed: %s", log);
    }
    return shader;
}

void GrassRenderer::setupShaders() {
    // 1. Terrain Shaders
    GLuint tvs = compileShader(GL_VERTEX_SHADER, terrainVS);
    GLuint tfs = compileShader(GL_FRAGMENT_SHADER, terrainFS);
    terrainProgram = glCreateProgram();
    glAttachShader(terrainProgram, tvs);
    glAttachShader(terrainProgram, tfs);
    glLinkProgram(terrainProgram);

    // 2. Compute Shader
    GLuint cs = compileShader(GL_COMPUTE_SHADER, grassCS);
    grassComputeProgram = glCreateProgram();
    glAttachShader(grassComputeProgram, cs);
    glLinkProgram(grassComputeProgram);

    // 3. Grass Display Shaders
    GLuint gvs = compileShader(GL_VERTEX_SHADER, grassVS);
    GLuint gfs = compileShader(GL_FRAGMENT_SHADER, grassFS);
    grassProgram = glCreateProgram();
    glAttachShader(grassProgram, gvs);
    glAttachShader(grassProgram, gfs);
    glLinkProgram(grassProgram);

    // 4. Create SSBO for Grass Blades (65536 blades * 32 bytes = ~2MB)
    glGenBuffers(1, &grassSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, grassSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, 65536 * 32, nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, grassSSBO);

    // 5. Create Empty VAO for Instanced Rendering
    glGenVertexArrays(1, &emptyVAO);
}

void GrassRenderer::generateTerrainGrid() {
    std::vector<float> vertices;
    std::vector<unsigned int> indices;
    int gridWidth = 150;
    int gridDepth = 150;

    for(int z = 0; z < gridDepth; z++) {
        for(int x = 0; x < gridWidth; x++) {
            vertices.push_back(x - gridWidth / 2.0f);
            vertices.push_back(0.0f); 
            vertices.push_back(z - gridDepth / 2.0f);
        }
    }

    for(int z = 0; z < gridDepth - 1; z++) {
        for(int x = 0; x < gridWidth - 1; x++) {
            int topLeft = (z * gridWidth) + x;
            int topRight = topLeft + 1;
            int bottomLeft = ((z + 1) * gridWidth) + x;
            int bottomRight = bottomLeft + 1;
            
            indices.push_back(topLeft);
            indices.push_back(bottomLeft);
            indices.push_back(topRight);
            indices.push_back(topRight);
            indices.push_back(bottomLeft);
            indices.push_back(bottomRight);
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
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned int), indices.data(), GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glBindVertexArray(0);
}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx; 
    moveY = my; 
    camYaw += lx * 0.005f; 
    camPitch += ly * 0.005f;
    
    if (camPitch > 1.5f) camPitch = 1.5f;
    if (camPitch < -1.5f) camPitch = -1.5f;
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    if (width <= 0 || height <= 0) return;
    gTime = time;

    if (terrainVAO == 0) {
        generateTerrainGrid();
        setupShaders();
    }

    cameraX += (moveX * cos(camYaw) + moveY * sin(camYaw)) * dt * 10.0f;
    cameraZ += (-moveY * cos(camYaw) + moveX * sin(camYaw)) * dt * 10.0f; 

    render(width, height);
}

void GrassRenderer::render(int width, int height) {
    glViewport(0, 0, width, height);
    glClearColor(0.5f, 0.7f, 0.9f, 1.0f); // Bright Sky Blue
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE); // Grass blades are double-sided!

    float camForwardX = sin(camYaw) * cos(camPitch);
    float camForwardY = -sin(camPitch);
    float camForwardZ = -cos(camYaw) * cos(camPitch);

    float proj[16];
    perspective(proj, 60.0f * (M_PI / 180.0f), (float)width / (float)height, 0.1f, 1000.0f);

    float view[16];
    lookAt(view, cameraX, cameraY, cameraZ, cameraX + camForwardX, cameraY + camForwardY, cameraZ + camForwardZ, 0.0f, 1.0f, 0.0f);

    float mvp[16];
    multiplyMatrix(mvp, proj, view);

    // ==========================================
    // PASS 1: Dispatch Compute Shader (GPU Logic)
    // ==========================================
    glUseProgram(grassComputeProgram);
    glUniform3f(glGetUniformLocation(grassComputeProgram, "u_CameraPos"), cameraX, cameraY, cameraZ);
    glUniform1f(glGetUniformLocation(grassComputeProgram, "u_Time"), gTime);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, grassSSBO);
    
    // Dispatch 256 work groups of 256 local size = 65,536 blades updated!
    glDispatchCompute(256, 1, 1);
    
    // Wait for the compute shader to finish writing to memory
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // ==========================================
    // PASS 2: Render Dirt Terrain
    // ==========================================
    glUseProgram(terrainProgram);
    glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "u_MVP"), 1, GL_FALSE, mvp);
    glBindVertexArray(terrainVAO);
    glDrawElements(GL_TRIANGLES, indexCount, GL_UNSIGNED_INT, 0);

    // ==========================================
    // PASS 3: Render Procedural Grass Instances
    // ==========================================
    glUseProgram(grassProgram);
    glUniformMatrix4fv(glGetUniformLocation(grassProgram, "u_MVP"), 1, GL_FALSE, mvp);
    glUniform3f(glGetUniformLocation(grassProgram, "u_CameraPos"), cameraX, cameraY, cameraZ);
    
    glBindVertexArray(emptyVAO);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, grassSSBO);
    
    // Draw 65,536 instances. Each instance calls the Vertex Shader 3 times (1 triangle).
    glDrawArraysInstanced(GL_TRIANGLES, 0, 3, 65536);
    glBindVertexArray(0);
}
