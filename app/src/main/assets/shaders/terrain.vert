#version 310 es
precision highp float;
layout(location = 0) in vec2 a_XZ;

uniform mat4 u_ViewProjection;
uniform vec3 u_CameraPos;

out vec3 v_WorldPos;
out vec3 v_Normal;
out float v_Elevation;

float hash(float n) { return fract(sin(n) * 43758.5453123); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f*f*(3.0-2.0*f);
    float a = hash(i.x + i.y * 57.0); float b = hash(i.x + 1.0 + i.y * 57.0);
    float c = hash(i.x + (i.y + 1.0) * 57.0); float d = hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
    return a + (b-a)*u.x + (c-a)*u.y*(1.0-u.x) + (d-b)*u.y*u.x;
}

// Gentle rolling hills
float exactElevation(vec2 p) {
    float h = noise(p * 0.01) * 30.0 + noise(p * 0.03) * 10.0;
    h += noise(p * 0.1) * 2.0;
    return h;
}

void main() {
    vec2 camSnap = floor(u_CameraPos.xz / 4.0) * 4.0;
    vec2 worldXZ = a_XZ + camSnap;
    float y = exactElevation(worldXZ);
    
    v_WorldPos = vec3(worldXZ.x, y, worldXZ.y);
    v_Elevation = y;

    // Smooth normals for beautiful photographic lighting
    float eps = 1.0;
    float hL = exactElevation(worldXZ - vec2(eps, 0.0));
    float hR = exactElevation(worldXZ + vec2(eps, 0.0));
    float hD = exactElevation(worldXZ - vec2(0.0, eps));
    float hU = exactElevation(worldXZ + vec2(0.0, eps));
    v_Normal = normalize(vec3(hL - hR, 2.0 * eps, hD - hU));

    gl_Position = u_ViewProjection * vec4(v_WorldPos, 1.0);
}
