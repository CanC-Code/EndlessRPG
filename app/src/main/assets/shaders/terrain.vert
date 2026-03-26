#version 310 es
layout(location = 0) in vec2 aPos; // X, Z grid coordinates

uniform mat4 u_ViewProjection;
uniform vec3 u_CameraPos;

out vec3 vWorldPos;
out vec3 vNormal;
out float vSlope;

// Replicate the CPU noise for perfect vertex-grounding
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(hash(i+vec2(0,0)), hash(i+vec2(1,0)), u.x),
               mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), u.x), u.y);
}

float getH(vec2 p) {
    float h = noise(p * 0.01) * 35.0;
    h += noise(p * 0.04) * 12.0;
    return h;
}

void main() {
    float y = getH(aPos);
    vWorldPos = vec3(aPos.x, y, aPos.y);
    
    // Calculate normals on the GPU for lighting
    float e = 0.5;
    float hL = getH(aPos + vec2(-e, 0.0));
    float hR = getH(aPos + vec2(e, 0.0));
    float hD = getH(aPos + vec2(0.0, -e));
    float hU = getH(aPos + vec2(0.0, e));
    vNormal = normalize(vec3(hL - hR, 2.0 * e, hD - hU));
    
    vSlope = 1.0 - vNormal.y; // 0.0 = Flat, 1.0 = Vertical
    gl_Position = u_ViewProjection * vec4(vWorldPos, 1.0);
}
