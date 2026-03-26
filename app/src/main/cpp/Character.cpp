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
uniform float uTaperStart; 
uniform float uTaperEnd;
out vec3 vNorm;
out vec3 vWorldPos;

void main() {
    vec3 taperedPos = aPos;
    // Apply tapering: mix between start radius (bottom) and end radius (top)
    float taperFactor = mix(uTaperStart, uTaperEnd, aPos.y + 0.5);
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

    float diff = max(dot(norm, lightDir), 0.0);
    float ambient = 0.25;
    
    // RIM LIGHT / SSS Approximation
    float rim = pow(1.0 - max(dot(viewDir, norm), 0.0), 3.0);
    vec3 sssColor = vec3(1.0, 0.4, 0.3) * rim * 0.3;
    
    vec3 halfDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(norm, halfDir), 0.0), 40.0) * 0.3;

    FragColor = vec4(uColor * (diff + ambient) + sssColor + vec3(spec), 1.0);
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

    std::vector<float> data;
    int segs = 32;
    for (int i = 0; i < segs; ++i) {
        float t1 = (float)i / segs * 2.0f * M_PI;
        float t2 = (float)(i+1) / segs * 2.0f * M_PI;
        float c1 = cosf(t1), s1 = sinf(t1), c2 = cosf(t2), s2 = sinf(t2);
        data.insert(data.end(), {c1*0.5f, -0.5f, s1*0.5f, c1, 0, s1,  c2*0.5f, -0.5f, s2*0.5f, c2, 0, s2,  c1*0.5f, 0.5f, s1*0.5f, c1, 0, s1});
        data.insert(data.end(), {c1*0.5f, 0.5f, s1*0.5f, c1, 0, s1,  c2*0.5f, -0.5f, s2*0.5f, c2, 0, s2,  c2*0.5f, 0.5f, s2*0.5f, c2, 0, s2});
        data.insert(data.end(), {0, 0.5f, 0, 0, 1, 0,  c1*0.5f, 0.5f, s1*0.5f, 0, 1, 0,  c2*0.5f, 0.5f, s2*0.5f, 0, 1, 0});
        data.insert(data.end(), {0, -0.5f, 0, 0, -1, 0,  c2*0.5f, -0.5f, s2*0.5f, 0, -1, 0,  c1*0.5f, -0.5f, s1*0.5f, 0, -1, 0});
    }
    segmentVertexCount = data.size() / 6;

    glGenVertexArrays(1, &vao); glGenBuffers(1, &vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, data.size() * sizeof(float), data.data(), GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), (void*)0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), (void*)(3*sizeof(float))); glEnableVertexAttribArray(1);
}

void Character::render(const float* vp, float x, float y, float z, float yaw, float cameraX, float cameraZ) {
    if (!program) return;
    glUseProgram(program);
    glUniform3f(glGetUniformLocation(program, "uCameraPos"), cameraX, 1.8f, cameraZ);

    float dx = x - lastX, dz = z - lastZ;
    float dist = sqrtf(dx*dx + dz*dz);
    float speed = dist / 0.016f;
    lastX = x; lastZ = z;

    if (dist > 0.001f) {
        walkPhase += speed * 0.8f;
        swingAmplitude = std::min(1.0f, swingAmplitude + 0.15f);
        leanAngle = std::min(0.15f, speed * 0.04f);
    } else {
        swingAmplitude *= 0.85f;
        walkPhase *= 0.9f;
        leanAngle *= 0.9f;
    }

    float hipSway = sinf(walkPhase) * 0.1f * swingAmplitude;
    float shoulderSway = -sinf(walkPhase) * 0.15f * swingAmplitude;
    float verticalBounce = cosf(walkPhase * 2.0f) * 0.045f * swingAmplitude;

    float root[16]; makeIdentity(root);
    translateLocal(root, x, y + 0.95f + verticalBounce, z);
    rotateYLocal(root, yaw * (M_PI / 180.0f));
    rotateXLocal(root, leanAngle);

    // UPPER BODY
    float torso[16]; copyMat(torso, root);
    translateLocal(torso, 0, 0.38f, 0);
    rotateYLocal(torso, shoulderSway);
    
    float chestM[16]; copyMat(chestM, torso);
    scaleLocal(chestM, 0.44f, 0.62f, 0.28f);
    drawAnatomicalSegment(vp, chestM, 0.85f, 1.1f, 0.15f, 0.25f, 0.45f, cameraX, cameraZ);

    float headM[16]; copyMat(headM, torso);
    translateLocal(headM, 0, 0.45f, 0.03f);
    scaleLocal(headM, 0.24f, 0.3f, 0.24f);
    drawAnatomicalSegment(vp, headM, 0.95f, 0.95f, 0.85f, 0.7f, 0.6f, cameraX, cameraZ);

    for (int i : {-1, 1}) { // Arms
        float armPhase = walkPhase + (i == 1 ? M_PI : 0);
        float shoulder[16]; copyMat(shoulder, torso);
        translateLocal(shoulder, i * 0.24f, 0.26f, 0); 
        rotateXLocal(shoulder, sinf(armPhase) * 0.55f * swingAmplitude);
        rotateZLocal(shoulder, i * 0.12f);
        
        float upperArm[16]; copyMat(upperArm, shoulder);
        translateLocal(upperArm, 0, -0.18f, 0);
        scaleLocal(upperArm, 0.12f, 0.4f, 0.12f);
        drawAnatomicalSegment(vp, upperArm, 0.8f, 1.0f, 0.85f, 0.7f, 0.6f, cameraX, cameraZ);

        float elbow[16]; copyMat(elbow, shoulder);
        translateLocal(elbow, 0, -0.4f, 0);
        rotateXLocal(elbow, -0.2f - std::abs(sinf(armPhase)) * 0.7f * swingAmplitude);
        float forearm[16]; copyMat(forearm, elbow);
        translateLocal(forearm, 0, -0.18f, 0);
        scaleLocal(forearm, 0.09f, 0.38f, 0.09f);
        drawAnatomicalSegment(vp, forearm, 0.7f, 1.0f, 0.85f, 0.7f, 0.6f, cameraX, cameraZ);
    }

    for (int i : {-1, 1}) { // Legs
        float legPhase = walkPhase + (i == 1 ? 0 : M_PI);
        float hip[16]; copyMat(hip, root);
        translateLocal(hip, i * 0.14f, 0, 0);
        rotateYLocal(hip, hipSway * -i);
        rotateXLocal(hip, sinf(legPhase) * 0.6f * swingAmplitude);

        float thigh[16]; copyMat(thigh, hip);
        translateLocal(thigh, 0, -0.25f, 0);
        scaleLocal(thigh, 0.18f, 0.52f, 0.18f);
        drawAnatomicalSegment(vp, thigh, 0.75f, 1.1f, 0.15f, 0.15f, 0.18f, cameraX, cameraZ);

        float knee[16]; copyMat(knee, hip);
        translateLocal(knee, 0, -0.52f, 0); 
        rotateXLocal(knee, std::max(0.0f, sinf(legPhase - 0.5f)) * 1.3f * swingAmplitude);
        float calf[16]; copyMat(calf, knee);
        translateLocal(calf, 0, -0.24f, 0);
        scaleLocal(calf, 0.15f, 0.52f, 0.15f);
        drawAnatomicalSegment(vp, calf, 0.6f, 1.1f, 0.15f, 0.15f, 0.18f, cameraX, cameraZ);
    }
}

void Character::drawAnatomicalSegment(const float* vp, const float* model, float rStart, float rEnd, float colorR, float colorG, float colorB, float camX, float camZ) {
    float mvp[16]; matMul(mvp, vp, model);
    glUniformMatrix4fv(glGetUniformLocation(program, "uMVP"), 1, GL_FALSE, mvp);
    glUniformMatrix4fv(glGetUniformLocation(program, "uModel"), 1, GL_FALSE, model);
    glUniform3f(glGetUniformLocation(program, "uColor"), colorR, colorG, colorB);
    glUniform1f(glGetUniformLocation(program, "uTaperStart"), rStart);
    glUniform1f(glGetUniformLocation(program, "uTaperEnd"), rEnd);
    glUniform3f(glGetUniformLocation(program, "uCameraPos"), camX, 1.8f, camZ);
    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, segmentVertexCount);
}

// Full Matrix Helpers
void Character::makeIdentity(float* m) { for(int i=0; i<16; i++) m[i]=(i%5==0)?1.f:0.f; }
void Character::copyMat(float* d, const float* s) { for(int i=0; i<16; i++) d[i]=s[i]; }
void Character::matMul(float* o, const float* a, const float* b) {
    float r[16];
    for(int c=0; c<4; c++) for(int rr=0; rr<4; rr++)
        r[c*4+rr] = a[0*4+rr]*b[c*4+0] + a[1*4+rr]*b[c*4+1] + a[2*4+rr]*b[c*4+2] + a[3*4+rr]*b[c*4+3];
    copyMat(o, r);
}
void Character::translateLocal(float* m, float x, float y, float z) {
    float t[16], r[16]; makeIdentity(t); t[12]=x; t[13]=y; t[14]=z; matMul(r, m, t); copyMat(m, r);
}
void Character::rotateXLocal(float* m, float a) {
    float r[16], res[16]; makeIdentity(r); r[5]=cosf(a); r[6]=sinf(a); r[9]=-sinf(a); r[10]=cosf(a);
    matMul(res, m, r); copyMat(m, res);
}
void Character::rotateYLocal(float* m, float a) {
    float r[16], res[16]; makeIdentity(r); r[0]=cosf(a); r[2]=-sinf(a); r[8]=sinf(a); r[10]=cosf(a);
    matMul(res, m, r); copyMat(m, res);
}
void Character::rotateZLocal(float* m, float a) {
    float r[16], res[16]; makeIdentity(r); r[0]=cosf(a); r[1]=sinf(a); r[4]=-sinf(a); r[5]=cosf(a);
    matMul(res, m, r); copyMat(m, res);
}
void Character::scaleLocal(float* m, float x, float y, float z) {
    float s[16], r[16]; makeIdentity(s); s[0]=x; s[5]=y; s[10]=z; matMul(r, m, s); copyMat(m, r);
}
