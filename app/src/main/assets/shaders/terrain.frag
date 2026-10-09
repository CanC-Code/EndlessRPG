#version 310 es
precision highp float;

in vec3 Normal;
in vec3 FragPos;
out vec4 FragColor;

uniform vec3 uCameraPos;
uniform vec3 uFogColor;

void main() {
    // Debug: R=position X pattern, G=position Z pattern, B=distance from camera
    float d = length(FragPos - uCameraPos);
    float dN = clamp(d / 200.0, 0.0, 1.0);
    FragColor = vec4(fract(FragPos.x * 0.1), fract(FragPos.z * 0.1), dN, 1.0);
}
