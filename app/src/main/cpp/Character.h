#pragma once
#include <GLES3/gl31.h>
#include <cmath>
#include <algorithm>

class Character {
public:
    Character();
    void init();
    void render(const float* vp, float x, float y, float z, float yaw, float cameraX, float cameraZ);

private:
    GLuint vao, vbo, program;
    float lastX, lastZ;
    float walkPhase;
    float swingAmplitude;
    float leanAngle; // Forward tilt based on speed
    float bankAngle; // Sideways tilt based on turning

    // Matrix Math
    void makeIdentity(float* m);
    void matMul(float* out, const float* a, const float* b);
    void copyMat(float* dst, const float* src);
    void translateLocal(float* m, float x, float y, float z);
    void rotateXLocal(float* m, float angleRad);
    void rotateYLocal(float* m, float angleRad);
    void rotateZLocal(float* m, float angleRad);
    void scaleLocal(float* m, float x, float y, float z);

    // DRAWING SYSTEM: Start radius, end radius, and length for anatomical tapering
    void drawAnatomicalSegment(const float* vp, const float* model, float rStart, float rEnd, float colorR, float colorG, float colorB, float camX, float camZ);
};
