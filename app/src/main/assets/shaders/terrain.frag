#version 310 es
precision highp float;
in vec3 Normal;
in vec3 FragPos;
out vec4 FragColor;
uniform vec3 uCameraPos;
uniform vec3 uFogColor;
void main() {
    float d = length(FragPos - uCameraPos);
    float t = clamp((d - 60.0) / 180.0, 0.0, 1.0);
    vec3 nearCol = vec3(1.0, 0.1, 0.05);
    vec3 farCol  = uFogColor;
    FragColor = vec4(mix(nearCol, farCol, t), 1.0);
}
