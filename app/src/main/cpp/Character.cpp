#include "Character.h"
#include <android/log.h>
#include <string>

// --- SHADERS FOR 3D LIGHTING ---
const char* charVertShader = R"(#version 310 es
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNorm;
uniform mat4 uMVP;
uniform mat4 uModel;
out vec3 vNorm;
void main() {
    gl_Position = uMVP * vec4(aPos, 1.0);
    vNorm = mat3(uModel) * aNorm; // Rotate normals with the limb
}
)";

const char* charFragShader = R"(#version 310 es
precision highp float;
in vec3 vNorm;
out vec4 FragColor;
uniform vec3 uColor;
void main() {
    vec3 norm = normalize(vNorm);
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    float diff = max(dot(norm, lightDir), 0.2); // Soft lighting
    FragColor = vec4(uColor * diff, 1.0);
}
)";

Character::Character() : vao(0), vbo(0), program(0), lastX(0), lastZ(0), walkPhase(0), swingAmplitude(0) {}

void Character::init() {
    // Compile basic shaders
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

    // 1x1x1 Cube centered at 0,0,0 with Normals
    float cubeData[] = {
        // Front (Z+)
        -0.5f,-0.5f, 0.5f,  0,0,1,   0.5f,-0.5f, 0.5f,  0,0,1,   0.5f, 0.5f, 0.5f,  0,0,1,
         0.5f, 0.5f, 0.5f,  0,0,1,  -0.5f, 0.5f, 0.5f,  0,0,1,  -0.5f,-0.5f, 0.5f,  0,0,1,
        // Back (Z-)
        -0.5f,-0.5f,-0.5f,  0,0,-1, -0.5f, 0.5f,-0.5f,  0,0,-1,  0.5f, 0.5f,-0.5f,  0,0,-1,
         0.5f, 0.5f,-0.5f,  0,0,-1,  0.5f,-0.5f,-0.5f,  0,0,-1, -0.5f,-0.5f,-0.5f,  0,0,-1,
        // Left (X-)
        -0.5f,-0.5f,-0.5f, -1,0,0,  -0.5f,-0.5f, 0.5f, -1,0,0,  -0.5f, 0.5f, 0.5f, -1,0,0,
        -0.5f, 0.5f, 0.5f, -1,0,0,  -0.5f, 0.5f,-0.5f, -1,0,0,  -0.5f,-0.5f,-0.5f, -1,0,0,
        // Right (X+)
         0.5f,-0.5f,-0.5f,  1,0,0,   0.5f, 0.5f,-0.5f,  1,0,0,   0.5f, 0.5f, 0.5f,  1,0,0,
         0.5f, 0.5f, 0.5f,  1,0,0,   0.5f,-0.5f, 0.5f,  1,0,0,   0.5f,-0.5f,-0.5f,  1,0,0,
        // Top (Y+)
        -0.5f, 0.5f,-0.5f,  0,1,0,  -0.5f, 0.5f, 0.5f,  0,1,0,   0.5f, 0.5f, 0.5f,  0,1,0,
         0.5f, 0.5f, 0.5f,  0,1,0,   0.5f, 0.5f,-0.5f,  0,1,0,  -0.5f, 0.5f,-0.5f,  0,1,0,
        // Bottom (Y-)
        -0.5f,-0.5f,-0.5f,  0,-1,0,  0.5f,-0.5f,-0.5f,  0,-1,0,  0.5f,-0.5f, 0.5f,  0,-1,0,
         0.5f,-0.5f, 0.5f,  0,-1,0, -0.5f,-0.5f, 0.5f,  0,-1,0, -0.5f,-0.5f,-0.5f,  0,-1,0
    };

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(cubeData), cubeData, GL_STATIC_DRAW);
    
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);
}

// --- BIOMECHANICAL WALK CYCLE & KINEMATICS ---
void Character::render(const float* vp, float x, float y, float z, float yaw) {
    if (!program) return;
    glUseProgram(program);

    // 1. INFER MOVEMENT AND PACE
    float dx = x - lastX;
    float dz = z - lastZ;
    float dist = sqrtf(dx*dx + dz*dz);
    lastX = x; lastZ = z;

    if (dist > 0.002f) {
        walkPhase += dist * 12.0f; // Standard Pacing: 12 rad/m ensures ~1.8 steps per meter
        swingAmplitude += (1.0f - swingAmplitude) * 0.1f; // Blend into walk
    } else {
        swingAmplitude += (0.0f - swingAmplitude) * 0.15f; // Blend into standing
        // Smoothly rest feet together
        walkPhase += (0.0f - sinf(walkPhase)) * 0.1f; 
    }

    float maxLegSwing = 0.6f;
    float maxKneeBend = 1.1f;
    float maxArmSwing = 0.5f;
    float maxElbowBend = 0.8f;

    float phaseR = walkPhase;
    float phaseL = walkPhase + M_PI; // Left side is exactly opposite

    // Pelvis bobs down when legs spread, up when legs cross
    float pelvisBob = cosf(walkPhase * 2.0f) * 0.03f * swingAmplitude;

    // --- HIERARCHICAL BONES ---

    // 1. ROOT (Pelvis) - Standing height is 1.0m to the hip joint
    float root[16]; makeIdentity(root);
    translateLocal(root, x, y + 1.0f + pelvisBob, z);
    rotateYLocal(root, yaw * (M_PI / 180.0f) + M_PI); // Align with camera view

    // 2. TORSO
    float torso[16]; copyMat(torso, root);
    translateLocal(torso, 0.0f, 0.3f, 0.0f); // Center of Torso
    // Slight torso rotation opposite to the leading leg
    rotateYLocal(torso, sinf(walkPhase) * 0.1f * swingAmplitude); 
    
    float torsoDraw[16]; copyMat(torsoDraw, torso);
    scaleLocal(torsoDraw, 0.35f, 0.6f, 0.2f);
    drawSegment(vp, torsoDraw, 0.2f, 0.4f, 0.6f); // Blue shirt

    // 3. HEAD
    float head[16]; copyMat(head, torso);
    translateLocal(head, 0.0f, 0.42f, 0.0f);
    float headDraw[16]; copyMat(headDraw, head);
    scaleLocal(headDraw, 0.22f, 0.25f, 0.22f);
    drawSegment(vp, headDraw, 0.9f, 0.75f, 0.65f); // Skin tone

    // --- LEGS ---
    
    // Right Leg
    float rThigh[16]; copyMat(rThigh, root);
    translateLocal(rThigh, 0.12f, 0.0f, 0.0f); // Hip socket
    rotateXLocal(rThigh, sinf(phaseR) * maxLegSwing * swingAmplitude);
    
    float rThighDraw[16]; copyMat(rThighDraw, rThigh);
    translateLocal(rThighDraw, 0.0f, -0.225f, 0.0f);
    scaleLocal(rThighDraw, 0.12f, 0.45f, 0.12f);
    drawSegment(vp, rThighDraw, 0.3f, 0.3f, 0.3f); // Pants

    float rCalf[16]; copyMat(rCalf, rThigh);
    translateLocal(rCalf, 0.0f, -0.45f, 0.0f); // Knee joint
    // Knees physically only bend backward (positive X rotation)
    float rKneeBend = std::max(0.0f, sinf(phaseR - 0.6f)) * maxKneeBend * swingAmplitude;
    rotateXLocal(rCalf, rKneeBend);
    
    float rCalfDraw[16]; copyMat(rCalfDraw, rCalf);
    translateLocal(rCalfDraw, 0.0f, -0.225f, 0.0f);
    scaleLocal(rCalfDraw, 0.1f, 0.45f, 0.1f);
    drawSegment(vp, rCalfDraw, 0.3f, 0.3f, 0.3f); // Pants

    // Left Leg
    float lThigh[16]; copyMat(lThigh, root);
    translateLocal(lThigh, -0.12f, 0.0f, 0.0f);
    rotateXLocal(lThigh, sinf(phaseL) * maxLegSwing * swingAmplitude);
    
    float lThighDraw[16]; copyMat(lThighDraw, lThigh);
    translateLocal(lThighDraw, 0.0f, -0.225f, 0.0f);
    scaleLocal(lThighDraw, 0.12f, 0.45f, 0.12f);
    drawSegment(vp, lThighDraw, 0.3f, 0.3f, 0.3f);

    float lCalf[16]; copyMat(lCalf, lThigh);
    translateLocal(lCalf, 0.0f, -0.45f, 0.0f);
    float lKneeBend = std::max(0.0f, sinf(phaseL - 0.6f)) * maxKneeBend * swingAmplitude;
    rotateXLocal(lCalf, lKneeBend);
    
    float lCalfDraw[16]; copyMat(lCalfDraw, lCalf);
    translateLocal(lCalfDraw, 0.0f, -0.225f, 0.0f);
    scaleLocal(lCalfDraw, 0.1f, 0.45f, 0.1f);
    drawSegment(vp, lCalfDraw, 0.3f, 0.3f, 0.3f);

    // --- ARMS ---
    
    // Right Arm (Swings with Left Leg)
    float rArmPhase = phaseL;
    float rBicep[16]; copyMat(rBicep, torso);
    translateLocal(rBicep, 0.22f, 0.2f, 0.0f); // Shoulder socket
    rotateZLocal(rBicep, -0.1f); // Rest arms slightly outward
    rotateXLocal(rBicep, sinf(rArmPhase) * maxArmSwing * swingAmplitude);

    float rBicepDraw[16]; copyMat(rBicepDraw, rBicep);
    translateLocal(rBicepDraw, 0.0f, -0.175f, 0.0f);
    scaleLocal(rBicepDraw, 0.09f, 0.35f, 0.09f);
    drawSegment(vp, rBicepDraw, 0.9f, 0.75f, 0.65f); // Skin

    float rForearm[16]; copyMat(rForearm, rBicep);
    translateLocal(rForearm, 0.0f, -0.35f, 0.0f); // Elbow joint
    // Elbows physically only bend forward (negative X rotation)
    float rElbowBend = std::min(0.0f, sinf(rArmPhase - 0.6f)) * maxElbowBend * swingAmplitude;
    rotateXLocal(rForearm, rElbowBend - 0.1f); // Stand with slight elbow bend

    float rForearmDraw[16]; copyMat(rForearmDraw, rForearm);
    translateLocal(rForearmDraw, 0.0f, -0.175f, 0.0f);
    scaleLocal(rForearmDraw, 0.08f, 0.35f, 0.08f);
    drawSegment(vp, rForearmDraw, 0.9f, 0.75f, 0.65f);

    // Left Arm (Swings with Right Leg)
    float lArmPhase = phaseR;
    float lBicep[16]; copyMat(lBicep, torso);
    translateLocal(lBicep, -0.22f, 0.2f, 0.0f);
    rotateZLocal(lBicep, 0.1f); 
    rotateXLocal(lBicep, sinf(lArmPhase) * maxArmSwing * swingAmplitude);

    float lBicepDraw[16]; copyMat(lBicepDraw, lBicep);
    translateLocal(lBicepDraw, 0.0f, -0.175f, 0.0f);
    scaleLocal(lBicepDraw, 0.09f, 0.35f, 0.09f);
    drawSegment(vp, lBicepDraw, 0.9f, 0.75f, 0.65f);

    float lForearm[16]; copyMat(lForearm, lBicep);
    translateLocal(lForearm, 0.0f, -0.35f, 0.0f);
    float lElbowBend = std::min(0.0f, sinf(lArmPhase - 0.6f)) * maxElbowBend * swingAmplitude;
    rotateXLocal(lForearm, lElbowBend - 0.1f);

    float lForearmDraw[16]; copyMat(lForearmDraw, lForearm);
    translateLocal(lForearmDraw, 0.0f, -0.175f, 0.0f);
    scaleLocal(lForearmDraw, 0.08f, 0.35f, 0.08f);
    drawSegment(vp, lForearmDraw, 0.9f, 0.75f, 0.65f);
}

void Character::drawSegment(const float* vp, const float* model, float r, float g, float b) {
    float mvp[16];
    matMul(mvp, vp, model);
    
    glUniformMatrix4fv(glGetUniformLocation(program, "uMVP"), 1, GL_FALSE, mvp);
    glUniformMatrix4fv(glGetUniformLocation(program, "uModel"), 1, GL_FALSE, model);
    glUniform3f(glGetUniformLocation(program, "uColor"), r, g, b);
    
    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, 36);
}

// --- LIGHTWEIGHT MATRIX MATH SYSTEM ---

void Character::makeIdentity(float* m) {
    for(int i=0; i<16; i++) m[i] = (i%5 == 0) ? 1.0f : 0.0f;
}

void Character::copyMat(float* dst, const float* src) {
    for(int i=0; i<16; i++) dst[i] = src[i];
}

void Character::matMul(float* out, const float* a, const float* b) {
    for(int c=0; c<4; c++) {
        for(int r=0; r<4; r++) {
            out[c*4+r] = a[0*4+r]*b[c*4+0] + a[1*4+r]*b[c*4+1] + a[2*4+r]*b[c*4+2] + a[3*4+r]*b[c*4+3];
        }
    }
}

void Character::translateLocal(float* m, float x, float y, float z) {
    float t[16], res[16];
    makeIdentity(t);
    t[12] = x; t[13] = y; t[14] = z;
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
