#version 310 es
precision highp float;

layout(location = 0) in vec2 a_XZ;

uniform mat4 u_ViewProjection;
uniform vec3 u_CameraPos;

out vec3 v_WorldPos;
out float v_Elevation;

// --- NOISE FUNCTIONS (Simplified FBM for vertex) ---
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(hash(i + vec2(0,0)), hash(i + vec2(1,0)), u.x),
               mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y);
}

float getElevation(vec2 p) {
    // This MUST match your Renderer.cpp getElevation exactly
    float h = noise(p * 0.035) * 8.0; 
    h += pow(noise(p * 0.015 + 100.0), 2.5) * 50.0 * smoothstep(0.35, 0.65, noise(p * 0.005));
    return h;
}

void main() {
    // Snapping the grid to the camera to create "Infinite" terrain
    vec2 worldXZ = a_XZ + floor(u_CameraPos.xz);
    float elevation = getElevation(worldXZ);
    
    v_WorldPos = vec3(worldXZ.x, elevation, worldXZ.y);
    v_Elevation = elevation;
    
    gl_Position = u_ViewProjection * vec4(v_WorldPos, 1.0);
}
