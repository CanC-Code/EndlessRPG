#version 310 es
precision highp float;

layout(location = 0) in vec3 a_Pos;

struct Blade { 
    vec4 pos; 
    vec4 wind; 
};

layout(std430, binding = 0) buffer B { 
    Blade blades[]; 
};

uniform mat4 u_ViewProjection;
out float v_Height;

void main() {
    Blade b = blades[gl_InstanceID];
    vec3 bladePos = b.pos.xyz;
    float bladeHeight = b.pos.w;
    
    // Normalize wind direction and get wind strength
    vec2 windDir = normalize(b.wind.xz);
    float windStrength = b.wind.w;

    vec3 pos = a_Pos;
    
    // Scale the raw blade height by the procedural height
    pos.y *= bladeHeight;
    
    // Quadratic wind bending so the root stays still and the tip bends
    float bendFactor = (a_Pos.y * a_Pos.y) * windStrength;
    pos.x += windDir.x * bendFactor;
    pos.z += windDir.y * bendFactor;

    // Shift the local blade to its world position
    vec3 worldPos = pos + bladePos;

    // Pass the unscaled Y (0.0 to 1.0) to the fragment shader for coloring
    v_Height = a_Pos.y; 
    
    gl_Position = u_ViewProjection * vec4(worldPos, 1.0);
}
