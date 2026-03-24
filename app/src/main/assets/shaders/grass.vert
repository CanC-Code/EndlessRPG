#version 310 es
precision highp float;

// Per-blade vertex attribute (base of blade in local space, Y in [0,1])
layout(location = 0) in vec3 a_Pos;

// Blade data written each frame by the compute shader
struct Blade {
    vec4 pos;   // .xyz = world position,  .w = blade height scale
    vec4 wind;  // .xz  = wind direction,  .w  = wind strength
};
layout(std430, binding = 0) readonly buffer BladeBuffer {
    Blade blades[];
};

uniform mat4 u_ViewProjection;

out float v_Height;  // 0 = root, 1 = tip

void main() {
    Blade b = blades[gl_InstanceID];

    float bladeHeight  = b.pos.w;
    vec2  windDir      = normalize(b.wind.xz);
    float windStrength = b.wind.w;

    // Scale the blade and apply quadratic wind bend toward the tip
    vec3 pos   = a_Pos;
    pos.y     *= bladeHeight;

    float bend = (a_Pos.y * a_Pos.y) * windStrength * 0.35;
    pos.x     += windDir.x * bend;
    pos.z     += windDir.y * bend;

    vec3 worldPos = pos + b.pos.xyz;

    v_Height    = a_Pos.y;           // already [0,1] in the fixed geometry
    gl_Position = u_ViewProjection * vec4(worldPos, 1.0);
}
