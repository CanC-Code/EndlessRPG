#version 310 es
precision highp float;

layout(location = 0) in vec3 a_Pos;
layout(location = 1) in vec3 a_Normal;

uniform mat4 u_VP;
uniform vec3 u_Pos;
uniform float u_Yaw;

out vec3 v_Normal;

void main() {
    // Rotate character based on yaw
    float s = sin(u_Yaw);
    float c = cos(u_Yaw);
    mat3 rotY = mat3(c, 0, s, 0, 1, 0, -s, 0, c);
    
    vec3 worldPos = (rotY * a_Pos) + u_Pos;
    v_Normal = rotY * a_Normal;
    
    gl_Position = u_VP * vec4(worldPos, 1.0);
}
