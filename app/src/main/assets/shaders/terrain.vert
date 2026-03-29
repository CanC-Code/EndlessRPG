#version 310 es
layout(location = 0) in vec3 aPosition;

uniform mat4 u_MVP;
uniform vec3 u_CameraPos;

out vec3 vWorldPos;
out float vElevation;

float hash3(vec3 p) { 
    return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float noise3(vec3 x) {
    vec3 i = floor(x); 
    vec3 f = fract(x);
    vec3 u = f * f * (3.0 - 2.0 * f);
    float a0 = hash3(i + vec3(0,0,0));
    float a1 = hash3(i + vec3(1,0,0));
    float a2 = hash3(i + vec3(0,1,0)); 
    float a3 = hash3(i + vec3(1,1,0));
    float a4 = hash3(i + vec3(0,0,1)); 
    float a5 = hash3(i + vec3(1,0,1));
    float a6 = hash3(i + vec3(0,1,1));
    float a7 = hash3(i + vec3(1,1,1));
    return mix(mix(mix(a0, a1, u.x), mix(a2, a3, u.x), u.y), mix(mix(a4, a5, u.x), mix(a6, a7, u.x), u.y), u.z);
}

const float EARTH_RADIUS = 6371000.0;
const float EARTH_CIRCUMFERENCE = 2.0 * 3.14159265 * EARTH_RADIUS;

float exactElevation(vec2 mapXZ) {
    float lon = (mapXZ.x / EARTH_CIRCUMFERENCE) * 2.0 * 3.14159265;
    float lat = (mapXZ.y / EARTH_CIRCUMFERENCE) * 2.0 * 3.14159265;
    vec3 s = vec3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon));
    return noise3(s * 4000.0 * 0.01) * 30.0 + noise3(s * 4000.0 * 0.03) * 10.0;
}

void main() {
    vec3 worldPos = aPosition;

    // CRITICAL FIX: Snapping aligned exactly to 1.0 to match the C++ terrain grid step size
    vec2 snappedCam = floor(u_CameraPos.xz / 1.0) * 1.0;
    worldPos.x += snappedCam.x;
    worldPos.z += snappedCam.y;

    // Calculate exact height dynamically
    worldPos.y = exactElevation(worldPos.xz);

    vWorldPos = worldPos;
    vElevation = worldPos.y;
    gl_Position = u_MVP * vec4(worldPos, 1.0);
}
