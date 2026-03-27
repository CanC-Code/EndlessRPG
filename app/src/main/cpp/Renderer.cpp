#include "Renderer.h"
#include <android/log.h>
#include <cmath>
#include <vector>
#include <string>
#include <cstdlib>
#include <GLES3/gl3ext.h>

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "GameEngine", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "GameEngine", __VA_ARGS__)

// --- C++ equivalents of GLSL math functions ---
inline float fract(float x) {
    return x - std::floor(x);
}

inline float mix(float x, float y, float a) {
    return x * (1.0f - a) + y * a;
}

// Fixed hash3: Manually calculating the dot product without vec3
float hash3(float px, float py, float pz) {
    float p3x = fract(px * 0.1031f);
    float p3y = fract(py * 0.1030f);
    float p3z = fract(pz * 0.0973f);
    
    float dot_val = (p3x * (p3y + 33.33f)) + (p3y * (p3z + 33.33f)) + (p3z * (p3x + 33.33f));
    
    p3x += dot_val; 
    p3y += dot_val; 
    p3z += dot_val;
    return fract((p3x + p3y) * p3z);
}

// Fixed noise3: Using std::floor and our custom fract/mix functions
float noise3(float x, float y, float z) {
    float ix = std::floor(x); float iy = std::floor(y); float iz = std::floor(z);
    float fx = fract(x); float fy = fract(y); float fz = fract(z);
    
    float ux = fx * fx * (3.0f - 2.0f * fx);
    float uy = fy * fy * (3.0f - 2.0f * fy);
    float uz = fz * fz * (3.0f - 2.0f * fz);

    float n000 = hash3(ix, iy, iz);
    float n100 = hash3(ix + 1.0f, iy, iz);
    float n010 = hash3(ix, iy + 1.0f, iz);
    float n110 = hash3(ix + 1.0f, iy + 1.0f, iz);
    float n001 = hash3(ix, iy, iz + 1.0f);
    float n101 = hash3(ix + 1.0f, iy, iz + 1.0f);
    float n011 = hash3(ix, iy + 1.0f, iz + 1.0f);
    float n111 = hash3(ix + 1.0f, iy + 1.0f, iz + 1.0f);

    float nx00 = mix(n000, n100, ux);
    float nx10 = mix(n010, n110, ux);
    float nx01 = mix(n001, n101, ux);
    float nx11 = mix(n011, n111, ux);

    float nxy0 = mix(nx00, nx10, uy);
    float nxy1 = mix(nx01, nx11, uy);

    return mix(nxy0, nxy1, uz);
}

Renderer::Renderer(AAssetManager* am)
    : assetManager(am), playerX(0.0f), playerZ(0.0f), playerPitch(0.0f), playerYaw(0.0f),
      touching(false), lastTouchX(0.0f), lastTouchY(0.0f), eglContext(EGL_NO_CONTEXT) 
{
    // Now safely initializes using our C++ compatible getElevation
    playerY = getElevation(0.0f, 0.0f);
}

Renderer::~Renderer() {
    if (eglDisplay != EGL_NO_DISPLAY) {
        eglMakeCurrent(eglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (eglContext != EGL_NO_CONTEXT) eglDestroyContext(eglDisplay, eglContext);
        if (eglSurface != EGL_NO_SURFACE) eglDestroySurface(eglDisplay, eglSurface);
        eglTerminate(eglDisplay);
    }
}

void Renderer::initEGL(ANativeWindow* window) {
    eglDisplay = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    eglInitialize(eglDisplay, nullptr, nullptr);
    const EGLint attribs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_BLUE_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_RED_SIZE, 8,
        EGL_DEPTH_SIZE, 16,
        EGL_NONE
    };
    EGLConfig config;
    EGLint numConfigs;
    eglChooseConfig(eglDisplay, attribs, &config, 1, &numConfigs);
    eglSurface = eglCreateWindowSurface(eglDisplay, config, window, nullptr);
    const EGLint contextAttribs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    eglContext = eglCreateContext(eglDisplay, config, nullptr, contextAttribs);
    eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext);
}

GLuint Renderer::compileShader(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);
    GLint compiled;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) {
        GLint infoLen = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);
        if (infoLen) {
            std::vector<char> infoLog(infoLen);
            glGetShaderInfoLog(shader, infoLen, nullptr, infoLog.data());
            LOGE("Shader compilation failed: %s", infoLog.data());
        }
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

std::string Renderer::loadAsset(const char* filename) {
    AAsset* asset = AAssetManager_open(assetManager, filename, AASSET_MODE_BUFFER);
    if (!asset) return "";
    off_t length = AAsset_getLength(asset);
    std::string content(length, '\0');
    AAsset_read(asset, &content[0], length);
    AAsset_close(asset);
    return content;
}

void Renderer::buildShaders() {
    std::string tv = loadAsset("shaders/terrain.vert");
    std::string tf = loadAsset("shaders/terrain.frag");
    GLuint tvs = compileShader(GL_VERTEX_SHADER, tv.c_str());
    GLuint tfs = compileShader(GL_FRAGMENT_SHADER, tf.c_str());
    terrainProgram = glCreateProgram();
    glAttachShader(terrainProgram, tvs);
    glAttachShader(terrainProgram, tfs);
    glLinkProgram(terrainProgram);
    
    std::string gv = loadAsset("shaders/grass.vert");
    std::string gf = loadAsset("shaders/grass.frag");
    GLuint gvs = compileShader(GL_VERTEX_SHADER, gv.c_str());
    GLuint gfs = compileShader(GL_FRAGMENT_SHADER, gf.c_str());
    grassProgram = glCreateProgram();
    glAttachShader(grassProgram, gvs);
    glAttachShader(grassProgram, gfs);
    glLinkProgram(grassProgram);
}

GLuint Renderer::loadTexture(const char* filename) {
    AAsset* asset = AAssetManager_open(assetManager, filename, AASSET_MODE_BUFFER);
    if (!asset) return 0;
    off_t length = AAsset_getLength(asset);
    std::vector<uint8_t> buffer(length);
    AAsset_read(asset, buffer.data(), length);
    AAsset_close(asset);
    
    GLuint tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 256, 0, GL_RGBA, GL_UNSIGNED_BYTE, buffer.data());
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    return tex;
}

void Renderer::init() {
    buildShaders();
    grassTex = loadTexture("textures/grass_blade.png");
    
    // Generate terrain grid (simple plane)
    std::vector<float> vertices;
    for(int z = -50; z < 50; z++) {
        for(int x = -50; x < 50; x++) {
            vertices.push_back(x); vertices.push_back(z);
            vertices.push_back(x+1); vertices.push_back(z);
            vertices.push_back(x); vertices.push_back(z+1);
            vertices.push_back(x+1); vertices.push_back(z);
            vertices.push_back(x+1); vertices.push_back(z+1);
            vertices.push_back(x); vertices.push_back(z+1);
        }
    }
    numTerrainVertices = vertices.size() / 2;
    glGenBuffers(1, &terrainVBO);
    glBindBuffer(GL_ARRAY_BUFFER, terrainVBO);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(float), vertices.data(), GL_STATIC_DRAW);
    
    // Generate grass blade centers
    std::vector<float> grassCenters;
    for(int i = 0; i < 10000; i++) {
        float gx = (rand() % 10000 / 100.0f) - 50.0f;
        float gz = (rand() % 10000 / 100.0f) - 50.0f;
        float gy = getElevation(gx, gz);
        grassCenters.push_back(gx);
        grassCenters.push_back(gy);
        grassCenters.push_back(gz);
    }
    numGrassBlades = grassCenters.size() / 3;
    glGenBuffers(1, &grassVBO);
    glBindBuffer(GL_ARRAY_BUFFER, grassVBO);
    glBufferData(GL_ARRAY_BUFFER, grassCenters.size() * sizeof(float), grassCenters.data(), GL_STATIC_DRAW);
    
    glClearColor(0.5f, 0.7f, 1.0f, 1.0f);
    glEnable(GL_DEPTH_TEST);
}

float Renderer::getElevation(float x, float z) {
    float p_x = x * 0.005f;
    float p_y = 0.0f;
    float p_z = z * 0.005f;
    float h = noise3(p_x, p_y, p_z) * 35.0f;
    h += noise3(p_x * 4.0f, p_y * 4.0f, p_z * 4.0f) * 12.0f;
    h += noise3(p_x * 10.0f, p_y * 10.0f, p_z * 10.0f) * 3.0f;
    return h;
}

void Renderer::updateAndRender() {
    float dt = 0.016f; // simplified
    float speed = 5.0f * dt;
    
    // Auto-walk forward
    playerX += sin(-playerYaw) * speed;
    playerZ -= cos(-playerYaw) * speed;
    
    float targetY = getElevation(playerX, playerZ) + 1.8f; 
    
    float dtSafe = dt;
    if (dtSafe > 0.033f) dtSafe = 0.033f;
    
    if (playerY < targetY) playerY = targetY; // snap up
    else playerY += (targetY - playerY) * 15.0f * dtSafe; // smooth fall
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Construct View Projection Matrix
    float aspect = 1080.0f / 1920.0f; 
    float fov = 60.0f * M_PI / 180.0f;
    float f = 1.0f / tan(fov / 2.0f);
    float vp[16] = {0};
    vp[0] = f / aspect; vp[5] = f;
    vp[10] = -(100.0f + 0.1f) / (100.0f - 0.1f); vp[11] = -1.0f;
    vp[14] = -(2.0f * 100.0f * 0.1f) / (100.0f - 0.1f);
    
    // Simple lookAt
    float cosP = cos(playerPitch); float sinP = sin(playerPitch);
    float cosY = cos(playerYaw);   float sinY = sin(playerYaw);
    
    // Translate then Rotate
    float tx = -playerX, ty = -playerY, tz = -playerZ;
    // (A real matrix math lib would be better here, simplified for engine constraints)
    
    // Draw Terrain
    glUseProgram(terrainProgram);
    glUniformMatrix4fv(glGetUniformLocation(terrainProgram, "uVP"), 1, GL_FALSE, vp);
    glBindBuffer(GL_ARRAY_BUFFER, terrainVBO);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLES, 0, numTerrainVertices);
    
    // Draw Grass
    glUseProgram(grassProgram);
    glUniformMatrix4fv(glGetUniformLocation(grassProgram, "uVP"), 1, GL_FALSE, vp);
    glBindBuffer(GL_ARRAY_BUFFER, grassVBO);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glBindTexture(GL_TEXTURE_2D, grassTex);
    glDrawArrays(GL_POINTS, 0, numGrassBlades);
    
    eglSwapBuffers(eglDisplay, eglSurface);
}
