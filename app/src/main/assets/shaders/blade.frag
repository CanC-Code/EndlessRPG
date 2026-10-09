#version 310 es
precision mediump float;
in vec4 vColor;
in vec2 vUV;
in vec3 vWorldPos;
uniform vec3 uCameraPos;
uniform vec3 uFogColor;
uniform float uFogDensity;
out vec4 FragColor;
void main() {
    float t = vUV.y;
    vec3 c = vColor.rgb * (0.7 + 0.3 * t);
    float dist = length(vWorldPos - uCameraPos);
    float fog = 1.0 - exp(-uFogDensity * uFogDensity * dist * dist);
    c = mix(c, uFogColor, fog);
    FragColor = vec4(c, 1.0);
}
