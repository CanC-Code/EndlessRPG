#pragma once
#include <GLES3/gl31.h>
#include <cmath>
#include <algorithm>

class Character {
public:
    Character();
    void init();
    // Dynamically infers walking animation based on positional changes
    void render(const float* vp, float x, float y, float z, float yaw);

private:
    GLuint vao, vbo, program;
    
    // Animation Tracking
    float lastX, lastZ;
    float walkPhase;
    float swingAmplitude;

    // Matrix Math Utilities for Hierarchical Bones
    void makeIdentity(float* m);
    void matMul(float* out, const float* a, const float* b);
    void copyMat(float* dst, const float* src);
    void translateLocal(float* m, float x, float y, float z);
    void rotateXLocal(float* m, float angleRad);
    void rotateYLocal(float* m, float angleRad);
    void rotateZLocal(float* m, float angleRad);
    void scaleLocal(float* m, float x, float y, float z);

    // Renders a single anatomical segment
    void drawSegment(const float* vp, const float* model, float r, float g, float b);
};
