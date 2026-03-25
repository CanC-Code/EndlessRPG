#version 310 es
precision highp float;
layout(location = 0) in vec3 a_Pos;

struct Blade { vec4 pos; vec4 dir; };
layout(std430, binding = 0) buffer GrassBuffer { Blade blades[]; };

uniform mat4 u_ViewProjection;
uniform vec3 u_CameraPos;
out vec3 v_WorldPos;

float hash(float n) { return fract(sin(n) * 43758.5453123); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f*f*(3.0-2.0*f);
    float a = hash(i.x + i.y * 57.0); float b = hash(i.x + 1.0 + i.y * 57.0);
    float c = hash(i.x + (i.y + 1.0) * 57.0); float d = hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
    return a + (b-a)*u.x + (c-a)*u.y*(1.0-u.x) + (d-b)*u.y*u.x;
}
float getElevation(vec2 p) {
    float h = noise(p * 0.05) * 5.0 + noise(p * 0.1) * 2.0;
    h += pow(noise(p * 0.01), 2.0) * 80.0;
    return h;
}

void main() {
    Blade b = blades[gl_InstanceID];
    float elevation = getElevation(b.pos.xz);
    
    vec3 worldPos = a_Pos;
    
    // Wind deformation
    worldPos.x += b.dir.x * a_Pos.y; 
    worldPos.z += b.dir.z * a_Pos.y;
    
    // Distance-based shrinking (Sinks grass into ground at edges to prevent pop-in)
    float dist = length(vec3(b.pos.x, elevation, b.pos.z) - u_CameraPos);
    float scale = smoothstep(100.0, 75.0, dist); 
    
    worldPos *= scale;
    worldPos += vec3(b.pos.x, elevation, b.pos.z);
    
    v_WorldPos = worldPos;
    gl_Position = u_ViewProjection * vec4(worldPos, 1.0);
}
