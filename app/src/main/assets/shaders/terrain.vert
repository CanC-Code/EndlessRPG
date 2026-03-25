#version 310 es
precision highp float;
layout(location = 0) in vec2 a_XZ;

uniform mat4 u_ViewProjection;
uniform vec3 u_CameraPos;

out vec3 v_WorldPos;
out vec3 v_Normal;
out float v_Elevation;
out float v_GravelNoise;
out float v_DetailNoise;

const float EARTH_RADIUS = 6371000.0;
const float EARTH_CIRCUMFERENCE = 2.0 * 3.14159265 * EARTH_RADIUS;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float noise3(vec3 x) {
    vec3 i = floor(x); vec3 f = fract(x); vec3 u = f * f * (3.0 - 2.0 * f);
    float a0 = hash3(i + vec3(0,0,0)); float a1 = hash3(i + vec3(1,0,0));
    float a2 = hash3(i + vec3(0,1,0)); float a3 = hash3(i + vec3(1,1,0));
    float a4 = hash3(i + vec3(0,0,1)); float a5 = hash3(i + vec3(1,0,1));
    float a6 = hash3(i + vec3(0,1,1)); float a7 = hash3(i + vec3(1,1,1));
    return mix(mix(mix(a0, a1, u.x), mix(a2, a3, u.x), u.y), mix(mix(a4, a5, u.x), mix(a6, a7, u.x), u.y), u.z);
}

// 2D Noise replacing expensive Fragment fBm
float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(hash2(i + vec2(0.0,0.0)), hash2(i + vec2(1.0,0.0)), u.x),
               mix(hash2(i + vec2(0.0,1.0)), hash2(i + vec2(1.0,1.0)), u.x), u.y);
}
float fbm(vec2 p) {
    float f = 0.0; float amp = 0.5;
    for(int i=0; i<3; i++) { // Capped to 3 octaves for massive performance boost
        f += amp * noise2(p); p *= 2.0; amp *= 0.5;
    }
    return f;
}

float exactElevation(vec2 mapXZ) {
    float lon = (mapXZ.x / EARTH_CIRCUMFERENCE) * 2.0 * 3.14159265;
    float lat = (mapXZ.y / EARTH_CIRCUMFERENCE) * 2.0 * 3.14159265;
    vec3 s = vec3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon));
    vec3 p = s * 4000.0;
    return noise3(p * 0.01) * 30.0 + noise3(p * 0.03) * 10.0;
}

void main() {
    vec2 camSnap = floor(u_CameraPos.xz / 4.0) * 4.0;
    vec2 absoluteXZ = a_XZ + camSnap;
    float y = exactElevation(absoluteXZ);
    
    float distToCam = length(absoluteXZ - u_CameraPos.xz);
    float curvatureDrop = (distToCam * distToCam) / (2.0 * EARTH_RADIUS);
    y -= curvatureDrop;
    
    v_WorldPos = vec3(absoluteXZ.x, y, absoluteXZ.y);
    v_Elevation = y + curvatureDrop; 

    float eps = 1.0;
    float hL = exactElevation(absoluteXZ - vec2(eps, 0.0));
    float hR = exactElevation(absoluteXZ + vec2(eps, 0.0));
    float hD = exactElevation(absoluteXZ - vec2(0.0, eps));
    float hU = exactElevation(absoluteXZ + vec2(0.0, eps));
    v_Normal = normalize(vec3(hL - hR, 2.0 * eps, hD - hU));

    // HUGE GPU FIX: We pre-calculate the geological textures here!
    v_GravelNoise = fbm(absoluteXZ * 0.5);
    v_DetailNoise = fbm(absoluteXZ * 2.0);

    vec3 localPos = vec3(a_XZ.x + (camSnap.x - u_CameraPos.x), y, a_XZ.y + (camSnap.y - u_CameraPos.z));
    gl_Position = u_ViewProjection * vec4(localPos, 1.0);
}
