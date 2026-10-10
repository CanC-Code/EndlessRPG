#version 310 es
precision highp float;

in vec3 vColor;
in vec3 vNormal;
in vec3 vFragPos;

out vec4 FragColor;

uniform vec3 uCameraPos;
uniform vec3 uFogColor;

void main() {
    vec3 n = normalize(vNormal);
    vec3 L = normalize(vec3(0.5, 1.0, 0.3));
    float diff = max(dot(n, L), 0.0);
    vec3 col = vColor * (0.55 + diff * 0.75);

    float dist = length(vFragPos - uCameraPos);
    float fog = clamp((dist - 60.0) / 180.0, 0.0, 1.0);
    fog = fog * fog;
    col = mix(col, uFogColor, fog);

    FragColor = vec4(col, 1.0);
}
