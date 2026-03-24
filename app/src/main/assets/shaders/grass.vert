#version 310 es
precision highp float;

layout(location = 0) in vec3 a_Pos;

struct Blade { vec4 pos; vec4 wind; };
layout(std430, binding = 0) buffer B { Blade blades[]; };

uniform mat4 u_ViewProjection;
out float v_Height;

void main() {
    Blade b = blades[gl_InstanceID];
    vec3 bladePos = b.pos.xyz;
    float bladeHeight = b.pos.w;
    
    vec2 windDir = normalize(b.wind.xz);
    float windStrength = b.wind.w;

    vec3 pos = a_Pos;
    pos.y *= bladeHeight;
    
    // Advanced wind curvature
    float bendFactor = (a_Pos.y * a_Pos.y) * windStrength;
    pos.x += windDir.x * bendFactor;
    pos.z += windDir.y * bendFactor;

    vec3 worldPos = pos + bladePos;
    v_Height = a_Pos.y; 
    
    gl_Position = u_ViewProjection * vec4(worldPos, 1.0);
}
