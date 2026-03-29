#version 310 es
layout(location = 0) in vec3 aPosition;

uniform mat4 u_MVP;
uniform vec3 u_CameraPos;

out vec3 vWorldPos;
out vec3 vNormal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(hash(i+vec2(0,0)), hash(i+vec2(1,0)), u.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), u.x), u.y);
}

float getH(vec2 p) {
    return noise(p * 0.05) * 15.0 + noise(p * 0.1) * 5.0;
}

void main() {
    vec3 worldPos = aPosition;
    
    // Snap to the 1.0 unit C++ grid to prevent crawling
    vec2 snapped = floor(u_CameraPos.xz / 1.0) * 1.0; 
    worldPos.xz += snapped;
    worldPos.y = getH(worldPos.xz);

    // Analytical Normals for realistic lighting
    float e = 0.1;
    float hX = getH(worldPos.xz + vec2(e, 0.0));
    float hZ = getH(worldPos.xz + vec2(0.0, e));
    vNormal = normalize(vec3(worldPos.y - hX, e, worldPos.y - hZ));

    vWorldPos = worldPos;
    gl_Position = u_MVP * vec4(worldPos, 1.0);
}
