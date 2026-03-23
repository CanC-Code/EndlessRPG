#!/bin/bash
# File: runtime/generate_engine.sh

mkdir -p app/src/main/cpp

cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include "models/AllModels.h"
#include "shaders/shaders.h"

// --- Standard Math Library ---
struct Mat4 { float m[16]; };
Mat4 m4I() { Mat4 r={0}; r.m[0]=r.m[5]=r.m[10]=r.m[15]=1.0f; return r; }
Mat4 m4mul(Mat4 a, Mat4 b) {
    Mat4 r={0};
    for(int c=0; c<4; ++c) for(int ro=0; ro<4; ++ro)
        r.m[c*4+ro] = a.m[0*4+ro]*b.m[c*4+0] + a.m[1*4+ro]*b.m[c*4+1] + a.m[2*4+ro]*b.m[c*4+2] + a.m[3*4+ro]*b.m[c*4+3];
    return r;
}
Mat4 m4T(float x, float y, float z) { Mat4 r=m4I(); r.m[12]=x; r.m[13]=y; r.m[14]=z; return r; }
Mat4 m4RY(float a) { Mat4 r=m4I(); r.m[0]=cosf(a); r.m[2]=-sinf(a); r.m[8]=sinf(a); r.m[10]=cosf(a); return r; }
Mat4 m4RX(float a) { Mat4 r=m4I(); r.m[5]=cosf(a); r.m[6]=sinf(a); r.m[9]=-sinf(a); r.m[10]=cosf(a); return r; }
Mat4 m4S(float x, float y, float z) { Mat4 r=m4I(); r.m[0]=x; r.m[5]=y; r.m[10]=z; return r; }

// --- Engine State ---
GLuint program, mvpLoc, modelLoc, colorLoc;
GLuint vTorso, vHead, vLimb, vSword, vShield, vTrunk, vLeaves, vRock, vGround;
float pX=0, pZ=0, camZoom=12.0f, pFacing=0, walkTime=0;

GLuint makeVAO(const float* d, int c) {
    GLuint vao, vbo;
    glGenVertexArrays(1, &vao); glBindVertexArray(vao);
    glGenBuffers(1, &vbo); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, c * 6 * sizeof(float), d, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), 0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6*sizeof(float), (void*)(3*sizeof(float))); glEnableVertexAttribArray(1);
    return vao;
}

void drawVAO(GLuint vao, int count, Mat4 model, Mat4 vp, float r, float g, float b) {
    glUniformMatrix4fv(modelLoc, 1, GL_FALSE, model.m);
    glUniformMatrix4fv(mvpLoc, 1, GL_FALSE, m4mul(vp, model).m);
    glUniform3f(colorLoc, r, g, b);
    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, count);
}

float hash2(float x, float y) {
    float res = sinf(x * 12.9898f + y * 78.233f) * 43758.5453f;
    return res - floorf(res);
}

extern "C" {
JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv* env, jobject obj) {
    program = glCreateProgram();
    GLuint sV=glCreateShader(GL_VERTEX_SHADER); glShaderSource(sV,1,&VERTEX_SHADER,0); glCompileShader(sV); glAttachShader(program,sV);
    GLuint sF=glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(sF,1,&FRAGMENT_SHADER,0); glCompileShader(sF); glAttachShader(program,sF);
    glLinkProgram(program);
    mvpLoc = glGetUniformLocation(program, "uMVP");
    modelLoc = glGetUniformLocation(program, "uModel");
    colorLoc = glGetUniformLocation(program, "uColor");
    
    vTorso=makeVAO(M_TORSO, N_CUBE); vHead=makeVAO(M_HEAD, N_CUBE); vLimb=makeVAO(M_LIMB, N_CUBE);
    vSword=makeVAO(M_SWORD, N_CUBE); vShield=makeVAO(M_SHIELD, N_CUBE);
    vTrunk=makeVAO(M_TREE_TRUNK, N_CUBE); vLeaves=makeVAO(M_TREE_LEAVES, N_CUBE);
    vRock=makeVAO(M_ROCK, N_CUBE); vGround=makeVAO(M_GROUND, N_CUBE);
    
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
}

JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv* env, jobject obj, jint w, jint h) { glViewport(0,0,w,h); }

JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv* env, jobject obj, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch) {
    float moveSpeed = 0.12f;
    float dx = ix * cosf(yaw) - iy * sinf(yaw);
    float dz = ix * sinf(yaw) + iy * cosf(yaw);
    
    if (fabs(ix) > 0.05f || fabs(iy) > 0.05f) {
        pX += dx * moveSpeed; pZ += dz * moveSpeed;
        pFacing = atan2f(dx, dz); 
        walkTime += 0.25f;
    } else {
        walkTime = 0.0f; // Return to idle stance
    }

    glClearColor(0.4f, 0.65f, 0.9f, 1.0f); // Fallback sky color
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); 
    glUseProgram(program);

    Mat4 vp = m4mul(m4T(0,0,-camZoom), m4mul(m4RX(pitch), m4RY(-yaw)));

    // 1. Draw Endless Grassy Grid
    drawVAO(vGround, N_CUBE, m4T(pX, 0.0f, pZ), vp, 0.25f, 0.65f, 0.25f);

    // 2. Procedural World Generation (Trees & Rocks)
    int cX = (int)floorf(pX / 6.0f);
    int cZ = (int)floorf(pZ / 6.0f);
    for(int x = -3; x <= 3; x++) {
        for(int z = -3; z <= 3; z++) {
            float h = hash2((float)(cX + x), (float)(cZ + z));
            if (h > 0.5f) {
                float oX = (cX + x) * 6.0f + hash2(h, 1.0f) * 4.0f;
                float oZ = (cZ + z) * 6.0f + hash2(h, 2.0f) * 4.0f;
                float sc = 0.7f + hash2(h, 3.0f) * 0.6f;
                
                if (h > 0.8f) { // Spawn Rock
                    drawVAO(vRock, N_CUBE, m4mul(m4T(oX, 0.25f, oZ), m4S(sc,sc,sc)), vp, 0.5f, 0.5f, 0.5f);
                } else { // Spawn Tree
                    Mat4 tBase = m4mul(m4T(oX, 1.0f, oZ), m4S(sc,sc,sc));
                    drawVAO(vTrunk, N_CUBE, tBase, vp, 0.4f, 0.25f, 0.1f);
                    drawVAO(vLeaves, N_CUBE, m4mul(tBase, m4T(0, 1.2f, 0)), vp, 0.1f, 0.5f, 0.1f);
                }
            }
        }
    }

    // 3. Draw Connected Hierarchical Character
    float bob = sinf(walkTime * 2.0f) * 0.05f;
    float sway = sinf(walkTime) * 0.8f;

    Mat4 base = m4mul(m4T(pX, 0.9f + bob, pZ), m4RY(pFacing));
    
    // Torso (Blue Shirt)
    drawVAO(vTorso, N_CUBE, base, vp, 0.1f, 0.4f, 0.8f);
    
    // Head (Peach Skin)
    drawVAO(vHead, N_CUBE, m4mul(base, m4T(0, 0.45f, 0)), vp, 0.9f, 0.7f, 0.6f);

    // Left Arm (Swings backward when Right Leg goes forward)
    Mat4 lShldr = m4mul(base, m4T(-0.28f, 0.2f, 0)); // Shoulder joint offset
    Mat4 lArm = m4mul(lShldr, m4RX(-sway));          // Pivot
    drawVAO(vLimb, N_CUBE, m4mul(lArm, m4T(0, -0.2f, 0)), vp, 0.9f, 0.7f, 0.6f);
    drawVAO(vShield, N_CUBE, m4mul(lArm, m4T(0, -0.3f, 0.15f)), vp, 0.7f, 0.3f, 0.1f); // Wooden Shield

    // Right Arm + Sword
    Mat4 rShldr = m4mul(base, m4T(0.28f, 0.2f, 0));
    Mat4 rArm = m4mul(rShldr, m4RX(sway));
    drawVAO(vLimb, N_CUBE, m4mul(rArm, m4T(0, -0.2f, 0)), vp, 0.9f, 0.7f, 0.6f);
    drawVAO(vSword, N_CUBE, m4mul(rArm, m4T(0, -0.4f, 0.2f)), vp, 0.8f, 0.8f, 0.8f); // Iron Sword

    // Left Leg (Brown Pants)
    Mat4 lHip = m4mul(base, m4T(-0.1f, -0.3f, 0));
    Mat4 lLeg = m4mul(lHip, m4RX(sway));
    drawVAO(vLimb, N_CUBE, m4mul(lLeg, m4T(0, -0.2f, 0)), vp, 0.4f, 0.3f, 0.2f);

    // Right Leg
    Mat4 rHip = m4mul(base, m4T(0.1f, -0.3f, 0));
    Mat4 rLeg = m4mul(rHip, m4RX(-sway));
    drawVAO(vLimb, N_CUBE, m4mul(rLeg, m4T(0, -0.2f, 0)), vp, 0.4f, 0.3f, 0.2f);
}

// Java Stubs
JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_setZoom(JNIEnv* env, jobject obj, jfloat z) { camZoom = z; }
JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv* env, jobject obj, jint id) {}
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getCameraYaw(JNIEnv* env, jobject obj) { return 0.0f; }
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getStamina(JNIEnv* env, jobject obj) { return 1.0f; }
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getHealth(JNIEnv* env, jobject obj) { return 1.0f; }
JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_setStamina(JNIEnv* env, jobject obj, jfloat v) {}
}
EOF
echo "[Engine] Generated native-lib.cpp"
