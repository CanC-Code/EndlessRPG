#include "Renderer.h"
#include "AssetManager.h"
#include <android/log.h>
#include <cmath>
#include <cstring>

#define LOG_TAG "GrassRenderer"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

GrassRenderer::GrassRenderer()
    : computeProgram(0), renderProgram(0), ssbo(0), vao(0), vbo(0) {}

// ---------------------------------------------------------------------------
// Shader compilation — logs the info log on failure so you can see GLSL errors.
// ---------------------------------------------------------------------------
GLuint GrassRenderer::compileShader(GLenum type, const std::string& source) {
    if (source.empty()) {
        LOGE("compileShader: source is empty (asset load failed?)");
        return 0;
    }
    GLuint shader = glCreateShader(type);
    const char* src = source.c_str();
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);

    GLint success = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        GLint logLen = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLen);
        if (logLen > 1) {
            std::string log(logLen, '\0');
            glGetShaderInfoLog(shader, logLen, nullptr, &log[0]);
            LOGE("Shader compile error (type=0x%x):\n%s", type, log.c_str());
        }
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

GLuint GrassRenderer::createProgram(GLuint vShader, GLuint fShader) {
    if (!vShader || !fShader) { LOGE("createProgram: invalid shader(s)"); return 0; }
    GLuint program = glCreateProgram();
    glAttachShader(program, vShader);
    glAttachShader(program, fShader);
    glLinkProgram(program);

    GLint success = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) {
        GLint logLen = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLen);
        if (logLen > 1) {
            std::string log(logLen, '\0');
            glGetProgramInfoLog(program, logLen, nullptr, &log[0]);
            LOGE("Program link error:\n%s", log.c_str());
        }
        glDeleteProgram(program);
        return 0;
    }
    glDeleteShader(vShader);
    glDeleteShader(fShader);
    return program;
}

GLuint GrassRenderer::createComputeProgram(GLuint cShader) {
    if (!cShader) { LOGE("createComputeProgram: invalid shader"); return 0; }
    GLuint program = glCreateProgram();
    glAttachShader(program, cShader);
    glLinkProgram(program);

    GLint success = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) {
        GLint logLen = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLen);
        if (logLen > 1) {
            std::string log(logLen, '\0');
            glGetProgramInfoLog(program, logLen, nullptr, &log[0]);
            LOGE("Compute program link error:\n%s", log.c_str());
        }
        glDeleteProgram(program);
        return 0;
    }
    glDeleteShader(cShader);
    return program;
}

// ---------------------------------------------------------------------------
// init() — called once from the render thread after EGL context is live.
// ---------------------------------------------------------------------------
void GrassRenderer::init() {
    LOGI("Loading shaders…");
    std::string cSrc = NativeAssetManager::loadShaderText("shaders/grass.comp");
    std::string vSrc = NativeAssetManager::loadShaderText("shaders/grass.vert");
    std::string fSrc = NativeAssetManager::loadShaderText("shaders/grass.frag");

    LOGI("comp src len=%zu  vert src len=%zu  frag src len=%zu",
         cSrc.size(), vSrc.size(), fSrc.size());

    computeProgram = createComputeProgram(compileShader(GL_COMPUTE_SHADER,  cSrc));
    renderProgram  = createProgram(
        compileShader(GL_VERTEX_SHADER,   vSrc),
        compileShader(GL_FRAGMENT_SHADER, fSrc));

    if (!computeProgram) LOGE("Compute program FAILED — grass will not animate.");
    if (!renderProgram)  LOGE("Render program FAILED  — grass will NOT be visible.");

    // SSBO — one Blade struct (2×vec4 = 8 floats) per instance.
    glGenBuffers(1, &ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    glBufferData(GL_SHADER_STORAGE_BUFFER,
                 (GLsizeiptr)GRASS_COUNT * 8 * sizeof(float),
                 nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

    // Blade geometry: 7 vertices forming a tapered triangle-strip.
    // Y values are in [0,1] — the vertex shader scales by blade height.
    float bladeVerts[] = {
        -0.03f, 0.00f, 0.0f,
         0.03f, 0.00f, 0.0f,
        -0.02f, 0.33f, 0.0f,
         0.02f, 0.33f, 0.0f,
        -0.01f, 0.66f, 0.0f,
         0.01f, 0.66f, 0.0f,
         0.00f, 1.00f, 0.0f,
    };

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(bladeVerts), bladeVerts, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glBindVertexArray(0);

    LOGI("GrassRenderer init complete. GRASS_COUNT=%d", GRASS_COUNT);
}

// ---------------------------------------------------------------------------
// updateAndRender() — called every frame.
// ---------------------------------------------------------------------------
void GrassRenderer::updateAndRender(float time, float dt, int width, int height) {
    glViewport(0, 0, width, height);

    // Horizon sky — warm blue.
    glClearColor(0.42f, 0.65f, 0.88f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if (computeProgram == 0 || renderProgram == 0) return;

    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glDisable(GL_CULL_FACE);

    // Slow forward flight to show the infinite rolling world.
    camZ -= dt * 3.0f;

    // ---- Compute pass: update every blade's world position + wind ----
    glUseProgram(computeProgram);
    glUniform1f(glGetUniformLocation(computeProgram, "u_Time"), time);
    glUniform3f(glGetUniformLocation(computeProgram, "u_CameraPos"), camX, camY, camZ);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
    glDispatchCompute(512 / 16, 512 / 16, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT | GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT);

    // ---- Render pass ----
    glUseProgram(renderProgram);

    float proj[16], view[16], vp[16];
    buildPerspective(proj, 0.85f, (float)width / (float)height, 0.05f, 800.0f);

    // Camera sits at eye-height, looks 12 units ahead and 0.8 down —
    // enough tilt to see the grass plane clearly on launch.
    buildLookAt(view,
                camX,       camY,       camZ,           // eye
                camX,       camY - 0.8f, camZ - 12.0f,  // target
                0.0f, 1.0f, 0.0f);                       // world-up  (Y-up)
    multiply(vp, proj, view);

    glUniformMatrix4fv(
        glGetUniformLocation(renderProgram, "u_ViewProjection"),
        1, GL_FALSE, vp);

    glBindVertexArray(vao);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
    glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 7, GRASS_COUNT);
    glBindVertexArray(0);
}

// ---------------------------------------------------------------------------
// Math helpers
// ---------------------------------------------------------------------------

void GrassRenderer::buildPerspective(float* m, float fov, float aspect, float zn, float zf) {
    float f = 1.0f / tanf(fov * 0.5f);
    memset(m, 0, 16 * sizeof(float));
    m[0]  =  f / aspect;
    m[5]  =  f;
    m[10] =  (zf + zn) / (zn - zf);
    m[11] = -1.0f;
    m[14] =  (2.0f * zf * zn) / (zn - zf);
}

// FIX: world-up must be (0,1,0) for a Y-up coordinate system.
// The original code used (0,0,1) as up, producing a corrupt view matrix.
void GrassRenderer::buildLookAt(float* m,
                                 float ex, float ey, float ez,
                                 float cx, float cy, float cz,
                                 float ux, float uy, float uz) {
    // Forward vector (eye → target), normalised.
    float fx = cx - ex, fy = cy - ey, fz = cz - ez;
    float rlf = 1.0f / sqrtf(fx*fx + fy*fy + fz*fz);
    fx *= rlf; fy *= rlf; fz *= rlf;

    // Right = forward × up, normalised.
    float sx = fy*uz - fz*uy;
    float sy = fz*ux - fx*uz;
    float sz = fx*uy - fy*ux;
    float rls = 1.0f / sqrtf(sx*sx + sy*sy + sz*sz);
    sx *= rls; sy *= rls; sz *= rls;

    // Recomputed up = right × forward (guaranteed orthogonal).
    float rx = sy*fz - sz*fy;
    float ry = sz*fx - sx*fz;
    float rz = sx*fy - sy*fx;

    // Column-major layout expected by glUniformMatrix4fv with GL_FALSE.
    m[0]  = sx;  m[4]  = rx;  m[8]  = -fx;  m[12] = -(sx*ex + sy*ey + sz*ez);
    m[1]  = sy;  m[5]  = ry;  m[9]  = -fy;  m[13] = -(rx*ex + ry*ey + rz*ez);
    m[2]  = sz;  m[6]  = rz;  m[10] = -fz;  m[14] = -(-fx*ex + -fy*ey + -fz*ez);
    m[3]  = 0.f; m[7]  = 0.f; m[11] = 0.f;  m[15] = 1.0f;
}

void GrassRenderer::multiply(float* out, const float* a, const float* b) {
    float tmp[16];
    for (int col = 0; col < 4; ++col)
        for (int row = 0; row < 4; ++row)
            tmp[col*4+row] =
                a[0*4+row]*b[col*4+0] + a[1*4+row]*b[col*4+1] +
                a[2*4+row]*b[col*4+2] + a[3*4+row]*b[col*4+3];
    memcpy(out, tmp, 16 * sizeof(float));
}
