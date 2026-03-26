#pragma once
#include <GLES3/gl31.h>
#include <cmath>
#include <algorithm>

class Character {
public:
    Character();
    void init();
    // Upgraded signature to accept terrain slope angles (Pitch and Roll)
    void render(const float* vp, float x, float y, float z, float yaw, float pitch, float roll, float cameraX, float cameraZ);

private:
    GLuint vao, vbo, program;
    float lastX, lastY, lastZ;
    float walkPhase;
    float swingAmplitude;
    float leanAngle;
    float bankAngle;

    void makeIdentity(float* m);
    void matMul(float* out, const float* a, const float* b);
    void copyMat(float* dst, const float* src);
    void translateLocal(float* m, float x, float y, float z);
    void rotateXLocal(float* m, float angleRad);
    void rotateYLocal(float* m, float angleRad);
    void rotateZLocal(float* m, float angleRad);
    void scaleLocal(float* m, float x, float y, float z);

    void drawAnatomicalSegment(const float* vp, const float* model, float rStart, float rEnd, float colorR, float colorG, float colorB, float camX, float camZ);
};
