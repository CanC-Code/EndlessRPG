#version 310 es
layout(location = 0) in vec2 aPos; // X, Z grid coordinates

uniform mat4 u_ViewProjection;
uniform vec3 u_CameraPos;

out vec3 vWorldPos;
out vec3 vNormal;
out float vSlope;

// ============================================================
// MUST match GrassRenderer::getElevation() in Renderer.cpp
// exactly — same hash seeds, same scale, same 3 octaves.
// Previously used hash(vec2) with seeds 127.1/311.7 which
// produced a completely different surface than the CPU,
// causing grass roots to float above (or sink below) ground.
// ============================================================

float hash3(float px, float py, float pz) {
    float dt = px * 12.9898 + py * 78.233 + pz * 37.719;
    float sn = sin(dt) * 43758.5453;
    return fract(sn);
}

float noise3(float px, float py, float pz) {
    float ix = floor(px), iy = floor(py), iz = floor(pz);
    float fx = px - ix, fy = py - iy, fz = pz - iz;
    float ux = fx * fx * (3.0 - 2.0 * fx);
    float uy = fy * fy * (3.0 - 2.0 * fy);
    float uz = fz * fz * (3.0 - 2.0 * fz);

    float a0 = hash3(ix,       iy, iz);
    float a1 = hash3(ix + 1.0, iy, iz);
    float a2 = hash3(ix,       iy + 1.0, iz);
    float a3 = hash3(ix + 1.0, iy + 1.0, iz);
    float a4 = hash3(ix,       iy, iz + 1.0);
    float a5 = hash3(ix + 1.0, iy, iz + 1.0);
    float a6 = hash3(ix,       iy + 1.0, iz + 1.0);
    float a7 = hash3(ix + 1.0, iy + 1.0, iz + 1.0);

    float mx0 = mix(a0, a1, ux);
    float mx1 = mix(a2, a3, ux);
    float mx2 = mix(a4, a5, ux);
    float mx3 = mix(a6, a7, ux);
    float my0 = mix(mx0, mx1, uy);
    float my1 = mix(mx2, mx3, uy);
    return mix(my0, my1, uz);
}

// noiseScale = 0.005, py fixed at 0.0 — identical to CPU exactElevation lambda
float getH(vec2 p) {
    float nx = p.x * 0.005;
    float nz = p.y * 0.005;
    float h  = noise3(nx,            0.0, nz           ) * 35.0;
    h       += noise3(nx * 4.0,      0.0, nz * 4.0     ) * 12.0;
    h       += noise3(nx * 10.0,     0.0, nz * 10.0    ) *  3.0;
    return h;
}

void main() {
    float y = getH(aPos);
    vWorldPos = vec3(aPos.x, y, aPos.y);

    // Finite-difference normal for per-vertex lighting
    float e  = 0.5;
    float hL = getH(aPos + vec2(-e,  0.0));
    float hR = getH(aPos + vec2( e,  0.0));
    float hD = getH(aPos + vec2(0.0, -e));
    float hU = getH(aPos + vec2(0.0,  e));
    vNormal = normalize(vec3(hL - hR, 2.0 * e, hD - hU));

    vSlope = 1.0 - vNormal.y; // 0 = flat, 1 = vertical
    gl_Position = u_ViewProjection * vec4(vWorldPos, 1.0);
}
