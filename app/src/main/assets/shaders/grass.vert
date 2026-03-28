#version 310 es
// This shader uses instancing. gl_InstanceID tells us which blade we are drawing.
// gl_VertexID tells us which vertex of the triangle we are drawing.

struct Blade { vec4 pos; vec4 dir; };
layout(std430, binding = 0) buffer GrassBuffer { Blade blades[]; };

uniform mat4 u_MVP;

out vec3 vWorldPos;
out float vHeightTaper;

void main() {
    Blade b = blades[gl_InstanceID];
    vec3 basePos = b.pos.xyz;
    vec3 windDir = b.dir.xyz;

    // Build a simple triangle for the grass blade
    // ID 0: Bottom Left, ID 1: Bottom Right, ID 2: Top Center
    float width = 0.1;
    float height = 1.0;
    
    vec3 offset = vec3(0.0);
    if (gl_VertexID == 0) {
        offset = vec3(-width, 0.0, 0.0);
        vHeightTaper = 0.0;
    } else if (gl_VertexID == 1) {
        offset = vec3(width, 0.0, 0.0);
        vHeightTaper = 0.0;
    } else {
        offset = vec3(0.0, height, 0.0) + windDir; // Tip bends with wind
        vHeightTaper = 1.0;
    }

    vec3 finalPos = basePos + offset;
    vWorldPos = finalPos;
    gl_Position = u_MVP * vec4(finalPos, 1.0);
}
