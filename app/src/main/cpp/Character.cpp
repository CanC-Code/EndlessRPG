#include "Character.h"
#include <vector>
#include <cmath>
#include <algorithm>

// --- BIOMECHANICAL SHADERS ---
const char* charVertShader = R"(#version 310 es
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNorm;
uniform mat4 uMVP;
uniform mat4 uModel;
uniform float uTaper; // 1.0 = Cylinder, < 1.0 = Tapered Capsule
out vec3 vNorm;
out vec3 vWorldPos;

void main() {
    // Dynamically taper the geometry to create muscular shapes (thicker centers)
    vec3 taperedPos = aPos;
    // Taper factor is strongest at the top/bottom (joints) and 1.0 at the center (muscle belly)
    float distFromCenter = abs(aPos.y); 
    float taperFactor = mix(1.0, uTaper, distFromCenter * 2.0);
    taperedPos.xz *= taperFactor;

    vec4 worldPos = uModel * vec4(taperedPos, 1.0);
    vWorldPos = worldPos.xyz;
    vNorm = mat3(uModel) * aNorm; 
    gl_Position = uMVP * vec4(taperedPos, 1.0);
}
)";

const char* charFragShader = R"(#version 310 es
precision highp float;
in vec3 vNorm;
in vec3 vWorldPos;
out vec4 FragColor;
uniform vec3 uColor;
uniform vec3 uCameraPos;

void main() {
    vec3 norm = normalize(vNorm);
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 viewDir = normalize(uCameraPos - vWorldPos);

    // Photographic lighting model
    float diff = max(dot(norm, lightDir), 0.0);
    float ambient = 0.25;
    
    // RIM LIGHT / SSS: Simulates light bleeding through skin edges
    float rim = pow(1.0 - max(dot(viewDir, norm), 0.0), 3.0);
    vec3 sssColor = vec3(1.0, 0.4, 0.3) * rim * 0.3; // Flesh-tone bleed
    
    // SPECULAR: Waxy sheen for skin/fabric
    vec3 halfDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(norm, halfDir), 0.0), 40.0) * 0.3;

    vec3 finalColor = uColor * (diff + ambient) + sssColor + vec3(spec);
    
    // Distance Fog for scale immersion
    float dist = length(uCameraPos - vWorldPos);
    float fog = clamp(dist * 0.002, 0.0, 1.0);
    vec3 skyColor = vec3(0.45, 0.6, 0.8);

    FragColor = vec4(mix(finalColor, skyColor, fog), 1.0);
}
)";

int segmentVertexCount = 0;

Character::Character() : vao(0), vbo(0), program(0), lastX(0), lastZ(0), 
                         walkPhase(0), swingAmplitude(0), leanAngle(0), bankAngle(0) {}

void Character::init() {
    GLuint vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs, 1, &charVertShader, nullptr);
    glCompileShader(vs);
    
    GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs, 1, &charFragShader, nullptr);
    glCompileShader(fs);
    
    program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);

    // High-fidelity 32-segment cylinder for photoreal smoothness
    std::vector<float> data;
    int segs = 32;
    for (int i = 0; i < segs; ++i) {
        float t1 = (float)i / segs * 2.0f * M_PI;
        float t2 = (float)(i+1) / segs * 2.0f * M_PI;
        float c1 = cosf(t1), s1 = sinf(t1), c2 = cosf(t2), s2 = sinf(t2);
        
        // Side faces
        data.insert(data.end(), {c1*0.5f, -0.5f, s1*0.5f, c1, 0, s1});
        data.insert(data.end(), {c2*0.5f, -0.5f, s2*0.5f, c2, 0, s2});
        data.insert(data.end(), {c1*0.5f,  0.5f, s1*0.5f, c1, 0, s1});
        data.insert(data.end(), {c1*0.5f,  0.5f, s1*0.5f, c1, 0, s1});
        data.insert(data.end(), {c2*0.5f, -0.5f, s2*0.5f, c2, 0, s2});
        data.insert(data.end(), {c2*0.5f,  0.5f, s2*0.5f, c2, 0, s2});
        
        // Top Cap
        data.insert(data.end(), {0, 0.5f, 0, 0, 1, 0});
        data.insert(data.end(), {c1*0.5f, 0.5f, s1*0.5f, 0, 1, 0});
        data.insert(data.end(), {c2*0.5f, 0.5f, s2*0.5f, 0, 1, 0});

        // Bottom Cap
        data.insert(data.end(), {0, -0.5f, 0, 0, -1, 0});
        data.insert(data.end(), {c2*0.5f, -0.5f, s2*0.5f, 0, -1, 0});
        data.insert(data.end(), {c1*0.5f, -0.5f, s1*0.5f, 0, -1, 0});
    }
    segmentVertexCount = data.size() / 6;

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, data.size() * sizeof(float), data.data(), GL_STATIC_DRAW);
    
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), (void*)(3*sizeof(float)));
    glEnableVertexAttribArray(1);
}

void Character::render(const float* vp, float x, float y, float z, float yaw, float cameraX, float cameraZ) {
    if (!program) return;
    glUseProgram(program);
    glUniform3f(glGetUniformLocation(program, "uCameraPos"), cameraX, 1.8f, cameraZ);

    // Motion Vector Inference
    float dx = x - lastX, dz = z - lastZ;
    float dist = sqrtf(dx*dx + dz*dz);
    float speed = dist / 0.016f; // Units per second estimation
    lastX = x; lastZ = z;

    if (dist > 0.001f) {
        walkPhase += speed * 0.8f;
        swingAmplitude = std::min(1.0f, swingAmplitude + 0.15f);
        leanAngle = std::min(0.15f, speed * 0.04f); // Lean into the walk
    } else {
        swingAmplitude *= 0.85f;
        walkPhase *= 0.9f;
        leanAngle *= 0.9f;
    }

    // Secondary Biological Motion
    float hipSway = sinf(walkPhase) * 0.1f * swingAmplitude;
    float shoulderSway = -sinf(walkPhase) * 0.15f * swingAmplitude; // Balance rotation
    float verticalBounce = cosf(walkPhase * 2.0f) * 0.045f * swingAmplitude;

    // ROOT TRANSFORMATION
    float root[16]; makeIdentity(root);
    translateLocal(root, x, y + 0.95f + verticalBounce, z);
    rotateYLocal(root, yaw * (M_PI / 180.0f));
    rotateXLocal(root, leanAngle);

    // --- TORSO HIERARCHY ---
    float torso[16]; copyMat(torso, root);
    translateLocal(torso, 0, 0.38f, 0);
    rotateYLocal(torso, shoulderSway);
    
    // Muscular Chest (Tapered upward)
    float chestM[16]; copyMat(chestM, torso);
    scaleLocal(chestM, 0.44f, 0.62f, 0.28f);
    drawAnatomicalSegment(vp, chestM, 0.85f, 0.2f, 0.3f, 0.5f); // Blue shirt

    // Head (Anatomical 1:8 scale)
    float head[16]; copyMat(head, torso);
    translateLocal(head, 0, 0.45f, 0.03f);
    scaleLocal(head, 0.24f, 0.3f, 0.24f);
    drawAnatomicalSegment(vp, head, 0.95f, 0.9f, 0.75f, 0.65f); // Skin

    // --- KINETIC ARMS ---
    for (int i : {-1, 1}) { // -1 = Left, 1 = Right
        float armPhase = walkPhase + (i == 1 ? M_PI : 0);
        float shoulder[16]; copyMat(shoulder, torso);
        translateLocal(shoulder, i * 0.24f, 0.26f, 0); 
        rotateXLocal(shoulder, sinf(armPhase) * 0.55f * swingAmplitude);
        rotateZLocal(shoulder, i * 0.12f); // Natural "A" pose
        
        float upperArm[16]; copyMat(upperArm, shoulder);
        translateLocal(upperArm, 0, -0.18f, 0);
        scaleLocal(upperArm, 0.12f, 0.4f, 0.12f);
        drawAnatomicalSegment(vp, upperArm, 0.8f, 0.9f, 0.75f, 0.65f);

        float elbow[16]; copyMat(elbow, shoulder);
        translateLocal(elbow, 0, -0.4f, 0);
        rotateXLocal(elbow, -0.2f - std::abs(sinf(armPhase)) * 0.7f * swingAmplitude);
        float forearm[16]; copyMat(forearm, elbow);
        translateLocal(forearm, 0, -0.18f, 0);
        scaleLocal(forearm, 0.09f, 0.38f, 0.09f);
        drawAnatomicalSegment(vp, forearm, 0.7f, 0.9f, 0.75f, 0.65f);
    }

    // --- KINETIC LEGS ---
    for (int i : {-1, 1}) {
        float legPhase = walkPhase + (i == 1 ? 0 : M_PI);
        float hip[16]; copyMat(hip, root);
        translateLocal(hip, i * 0.14f, 0, 0);
        rotateYLocal(hip, hipSway * -i); // Biological hip tilt
        rotateXLocal(hip, sinf(legPhase) * 0.6f * swingAmplitude);

        float thigh[16]; copyMat(thigh, hip);
        translateLocal(thigh, 0, -0.25f, 0);
        scaleLocal(thigh, 0.18f, 0.52f, 0.18f); // Muscular quads
        drawAnatomicalSegment(vp, thigh, 0.75f, 0.25f, 0.25f, 0.28f); // Trousers

        float knee[16]; copyMat(knee, hip);
        translateLocal(knee, 0, -0.52f, 0); 
        float bend = std::max(0.0f, sinf(legPhase - 0.5f)) * 1.3f * swingAmplitude;
        rotateXLocal(knee, bend);
        
        float calf[16]; copyMat(calf, knee);
        translateLocal(calf, 0, -0.24f, 0);
        scaleLocal(calf, 0.15f, 0.52f, 0.15f); // Tapered calf
        drawAnatomicalSegment(vp, calf, 0.6f, 0.25f, 0.25f, 0.28f);
    }
}

void Character::drawAnatomicalSegment(const float* vp, const float* model, float taper, float r, float g, float b) {
    float mvp[16];
    matMul(mvp, vp, model);
    glUniformMatrix4fv(glGetUniformLocation(program, "uMVP"), 1, GL_FALSE, mvp);
    glUniformMatrix4fv(glGetUniformLocation(program, "uModel"), 1, GL_FALSE, model);
    glUniform3f(glGetUniformLocation(program, "uColor"), r, g, b);
    glUniform1f(glGetUniformLocation(program, "uTaper"), taper);
    
    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, segmentVertexCount);
}

// --- FULL MATRIX STACK IMPLEMENTATION ---

void Character::makeIdentity(float* m) {
    for(int i=0; i<16; i++) m[i] = (i%5 == 0) ? 1.0f : 0.0f;
}

void Character::copyMat(float* dst, const float* src) {
    for(int i=0; i<16; i++) dst[i] = src[i];
}

void Character::matMul(float* out, const float* a, const float* b) {
    float res[16];
    for(int c=0; c<4; c++) {
        for(int r=0; r<4; r++) {
            res[c*4+r] = a[0*4+r]*b[c*4+0] + a[1*4+r]*b[c*4+1] + a[2*4+r]*b[c*4+2] + a[3*4+r]*b[c*4+3];
        }
    }
    copyMat(out, res);
}

void Character::translateLocal(float* m, float x, float y, float z) {
    float t[16], res[16];
    makeIdentity(t); t[12] = x; t[13] = y; t[14] = z;
    matMul(res, m, t);
    copyMat(m, res);
}

void Character::rotateXLocal(float* m, float angle) {
    float r[16], res[16];
    makeIdentity(r);
    float c = cosf(angle), s = sinf(angle);
    r[5] = c; r[6] = s; r[9] = -s; r[10] = c;
    matMul(res, m, r);
    copyMat(m, res);
}

void Character::rotateYLocal(float* m, float angle) {
    float r[16], res[16];
    makeIdentity(r);
    float c = cosf(angle), s = sinf(angle);
    r[0] = c; r[2] = -s; r[8] = s; r[10] = c;
    matMul(res, m, r);
    copyMat(m, res);
}

void Character::rotateZLocal(float* m, float angle) {
    float r[16], res[16];
    makeIdentity(r);
    float c = cosf(angle), s = sinf(angle);
    r[0] = c; r[1] = s; r[4] = -s; r[5] = c;
    matMul(res, m, r);
    copyMat(m, res);
}

void Character::scaleLocal(float* m, float x, float y, float z) {
    float s[16], res[16];
    makeIdentity(s);
    s[0] = x; s[5] = y; s[10] = z;
    matMul(res, m, s);
    copyMat(m, res);
}
