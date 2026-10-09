#version 310 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec2 aUV;
layout(location=2) in vec4 aColor;
uniform mat4 uMVP;
out vec4 vColor;
out vec2 vUV;
out vec3 vWorldPos;
void main() {
    vColor = aColor;
    vUV = aUV;
    vWorldPos = aPos;
    gl_Position = uMVP * vec4(aPos, 1.0);
}
