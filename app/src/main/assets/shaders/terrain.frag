#version 310 es
precision mediump float;
in vec3 Normal;
in vec3 FragPos;
out vec4 FragColor;
void main() {
    vec3 n = normalize(Normal);
    vec3 L = normalize(vec3(0.5, 1.0, 0.3));
    float diff = max(dot(n, L), 0.0);
    vec3 col = vec3(0.15, 0.32, 0.10) * (0.5 + diff * 0.8);
    FragColor = vec4(col, 1.0);
}
