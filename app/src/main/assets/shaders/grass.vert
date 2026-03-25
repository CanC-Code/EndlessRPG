#version 310 es
precision highp float;
layout(location = 0) in vec3 a_Pos;

struct Blade { vec4 pos; vec4 dir; };
layout(std430, binding = 0) buffer GrassBuffer { Blade blades[]; };

uniform mat4 u_ViewProjection;
uniform vec3 u_CameraPos;
out vec3 v_WorldPos;
out float v_ColorMix; // Passes height up the blade for the gradient

float hash(float n) { return fract(sin(n) * 43758.5453123); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f*f*(3.0-2.0*f);
    float a = hash(i.x + i.y * 57.0); float b = hash(i.x + 1.0 + i.y * 57.0);
    float c = hash(i.x + (i.y + 1.0) * 57.0); float d = hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
    return a + (b-a)*u.x + (c-a)*u.y*(1.0-u.x) + (d-b)*u.y*u.x;
}
float exactElevation(vec2 p) {
    float h = noise(p * 0.01) * 30.0 + noise(p * 0.03) * 10.0;
    return h + noise(p * 0.1) * 2.0;
}

void main() {
    Blade b = blades[gl_InstanceID];
    
    // MATHEMATICALLY GLUES GRASS TO THE FLAT TRIANGLES (Fixes the floating bug!)
    float gridSpacing = 4.0;
    vec2 cell = floor(b.pos.xz / gridSpacing) * gridSpacing;
    vec2 t = (b.pos.xz - cell) / gridSpacing;
    float h00 = exactElevation(cell);
    float h10 = exactElevation(cell + vec2(gridSpacing, 0.0));
    float h01 = exactElevation(cell + vec2(0.0, gridSpacing));
    float h11 = exactElevation(cell + vec2(gridSpacing, gridSpacing));
    
    float elevation;
    if (t.x + t.y <= 1.0) elevation = h00 + (h10 - h00)*t.x + (h01 - h00)*t.y;
    else elevation = h11 + (h01 - h11)*(1.0 - t.x) + (h10 - h11)*(1.0 - t.y);

    vec3 worldPos = a_Pos;
    
    // Wind deformation
    worldPos.x += b.dir.x * a_Pos.y; 
    worldPos.z += b.dir.z * a_Pos.y;
    
    float dist = length(vec3(b.pos.x, elevation, b.pos.z) - u_CameraPos);
    float scale = smoothstep(100.0, 75.0, dist); 
    
    worldPos *= scale;
    worldPos += vec3(b.pos.x, elevation, b.pos.z);
    
    v_WorldPos = worldPos;
    v_ColorMix = a_Pos.y / 1.4; // Grass blades are 1.4 units tall
    
    gl_Position = u_ViewProjection * vec4(worldPos, 1.0);
}
