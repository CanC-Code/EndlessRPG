#include "Renderer.h"
#include <GLES3/gl31.h>
#include <cmath>
#include <android/log.h>
#include <vector>

#define LOG_TAG "ProceduralEngine"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static float gTime = 0.0f;
static GLuint emptyVAO = 0;

// Shared Height Math: CPU and GPU must agree on where the ground is!
float getTerrainHeight(float x, float z) {
    return sin(x * 0.1f) * 2.0f + cos(z * 0.1f) * 2.0f;
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
// GLSL SHADERS (With Fog and Hills)
// ============================================================================
const char* terrainVS = R"(#version 310 es
layout(location = 0) in vec3 aPos;
uniform mat4 u_MVP;
uniform vec3 u_CameraPos;
out vec3 vWorldPos;
out float vDist;

float getHeight(vec2 p) { return sin(p.x * 0.1) * 2.0 + cos(p.y * 0.1) * 2.0; }

void main() {
    vec3 pos = aPos;
    // Infinite Treadmill: Snaps the grid to follow the camera!
    pos.x += floor(u_CameraPos.x);
    pos.z += floor(u_CameraPos.z);
    pos.y = getHeight(pos.xz); // Apply rolling hills

    vWorldPos = pos;
    vDist = distance(pos, u_CameraPos);
    gl_Position = u_MVP * vec4(pos, 1.0);
}
)";

const char* terrainFS = R"(#version 310 es
precision mediump float;
in vec3 vWorldPos;
in float vDist;
out vec4 FragColor;

void main() {
    float grid = mod(floor(vWorldPos.x) + floor(vWorldPos.z), 2.0);
    vec3 color1 = vec3(0.18, 0.12, 0.08); 
    vec3 color2 = vec3(0.15, 0.10, 0.06); 
    vec3 terrainColor = mix(color1, color2, grid);
    
    // Distance Fog to blend into horizon
    float fogFactor = exp(-pow(vDist * 0.025, 2.0));
    vec3 skyColor = vec3(0.5, 0.7, 0.9);
    
    FragColor = vec4(mix(skyColor, terrainColor, fogFactor), 1.0);
}
)";

const char* grassCS = R"(#version 310 es
layout(local_size_x = 256) in;
struct Blade { vec4 pos; vec4 dir; };
layout(std430, binding = 0) buffer GrassBuffer { Blade blades[]; };

uniform vec3 u_CameraPos;
uniform float u_Time;

float rand(vec2 co){ return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453); }
float getHeight(vec2 p) { return sin(p.x * 0.1) * 2.0 + cos(p.y * 0.1) * 2.0; }

void main() {
    uint i = gl_GlobalInvocationID.x;
    float gridSize = 60.0; // 60m radius of grass
    int gridX = int(i % 256u);
    int gridZ = int(i / 256u);

    float localX = (float(gridX) / 256.0) * gridSize - (gridSize / 2.0);
    float localZ = (float(gridZ) / 256.0) * gridSize - (gridSize / 2.0);
    float spacing = gridSize / 256.0;
    
    float snappedCamX = floor(u_CameraPos.x / spacing) * spacing;
    float snappedCamZ = floor(u_CameraPos.z / spacing) * spacing;

    float worldX = snappedCamX + localX + (rand(vec2(gridX, gridZ)) - 0.5) * spacing * 0.9;
    float worldZ = snappedCamZ + localZ + (rand(vec2(gridZ, gridX)) - 0.5) * spacing * 0.9;

    float windX = sin(u_Time * 1.5 + worldX * 0.2 + worldZ * 0.1) * 0.4;
    float windZ = cos(u_Time * 1.2 + worldZ * 0.2 - worldX * 0.1) * 0.4;

    // Apply exact same height math to grass roots!
    blades[i].pos = vec4(worldX, getHeight(vec2(worldX, worldZ)), worldZ, 1.0);
    blades[i].dir = vec4(windX, 1.0, windZ, 0.0);
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
    vec3 basePos = b.pos.xyz;
    vDist = distance(basePos, u_CameraPos);

    if (vDist > 30.0) { // Cull grass far away to save GPU
        gl_Position = vec4(0.0);
        return;
    }

    vec3 toCam = normalize(u_CameraPos - basePos);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), toCam));

    float width = 0.04;
    float height = 0.65;
    vec3 pos = basePos;
    
    if (gl_VertexID == 0) { pos -= right * width; v_Height = 0.0; } 
    else if (gl_VertexID == 1) { pos += right * width; v_Height = 0.0; } 
    else if (gl_VertexID == 2) { pos += b.dir.xyz * height; v_Height = 1.0; }

    gl_Position = u_MVP * vec4(pos, 1.0);
}
)";

const char* grassFS = R"(#version 310 es
precision mediump float;
in float v_Height;
in float vDist;
out vec4 FragColor;

void main() {
    vec3 rootColor = vec3(0.05, 0.25, 0.05);
    vec3 tipColor = vec3(0.4, 0.8, 0.2);
    vec3 grassColor = mix(rootColor, tipColor, v_Height);
    
    // Fade grass out into the fog smoothly
    float fogFactor = exp(-pow(vDist * 0.025, 2.0));
    vec3 skyColor = vec3(0.5, 0.7, 0.9);
    
    FragColor = vec4(mix(skyColor, grassColor, fogFactor), 1.0);
}
)";

// ============================================================================
// ENGINE IMPLEMENTATION
// ============================================================================
GrassRenderer::GrassRenderer() : terrainVAO(0), terrainVBO(0), terrainEBO(0), terrainProgram(0), grassProgram(0), grassComputeProgram(0), grassSSBO(0), indexCount(0) {
    cameraX = 0.0f; cameraZ = 0.0f;
    cameraY = getTerrainHeight(cameraX, cameraZ) + 1.8f; 
    camYaw = 0.0f; camPitch = 0.0f; 
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
    int gridW = 80; int gridD = 80;

    for(int z = 0; z < gridD; z++) {
        for(int x = 0; x < gridW; x++) {
            vertices.push_back(x - gridW / 2.0f);
            vertices.push_back(0.0f); 
            vertices.push_back(z - gridD / 2.0f);
        }
    }
    for(int z = 0; z < gridD - 1; z++) {
        for(int x = 0; x < gridW - 1; x++) {
            int tl = (z * gridW) + x; int tr = tl + 1;
            int bl = ((z + 1) * gridW) + x; int br = bl + 1;
            indices.insert(indices.end(), { (unsigned int)tl, (unsigned int)bl, (unsigned int)tr, (unsigned int)tr, (unsigned int)bl, (unsigned int)br });
        }
    }
    indexCount = indices.size();

    glGenVertexArrays(1, &terrainVAO); glGenBuffers(1, &terrainVBO); glGenBuffers(1, &terrainEBO);
    glBindVertexArray(terrainVAO);
    glBindBuffer(GL_ARRAY_BUFFER, terrainVBO); glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, terrainEBO); glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned int), indices.data(), GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0); glBindVertexArray(0);
}

void GrassRenderer::updateInput(float mx, float my, float lx, float ly, bool tp, float zoom) {
    moveX = mx; moveY = my; 
    camYaw += lx * 0.005f; camPitch += ly * 0.005f;
    if (camPitch > 1.5f) camPitch = 1.5f;
    if (camPitch < -1.5f) camPitch = -1.5f;
}

void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    if (width <= 0 || height <= 0) return;
    gTime = time;
    if (terrainVAO == 0) { generateTerrainGrid(); setupShaders(); }

    // Apply movement based on camera orientation
    cameraX += (moveX * cos(camYaw) + moveY * sin(camYaw)) * dt * 8.0f;
    cameraZ += (-moveY * cos(camYaw) + moveX * sin(camYaw)) * dt * 8.0f; 
    
    // Snap camera height to terrain! (+1.8m for eye height)
    cameraY = getTerrainHeight(cameraX, cameraZ) + 1.8f;

    render(width, height);
}

void GrassRenderer::render(int width, int height) {
    glViewport(0, 0, width, height);
    glClearColor(0.5f, 0.7f, 0.9f, 1.0f); // Match the fog skyColor
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE); 

    float camFWDX = sin(camYaw) * cos(camPitch);
    float camFWDY = -sin(camPitch);
    float camFWDZ = -cos(camYaw) * cos(camPitch);

    float proj[16], view[16], mvp[16];
    perspective(proj, 60.0f * (M_PI / 180.0f), (float)width / (float)height, 0.1f, 1000.0f);
    lookAt(view, cameraX, cameraY, cameraZ, cameraX + camFWDX, cameraY + camFWDY, cameraZ + camFWDZ, 0.0f, 1.0f, 0.0f);
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
    glDrawArraysInstanced(GL_TRIANGLES, 0, 3, 65536);
}
