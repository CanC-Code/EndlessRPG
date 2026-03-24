#version 310 es
precision mediump float;

in float v_Height;
out vec4 FragColor;

void main() {
    vec3 colorRoot = vec3(0.02, 0.15, 0.02);
    vec3 colorTip  = vec3(0.40, 0.70, 0.15);
    vec3 finalColor = mix(colorRoot, colorTip, v_Height * v_Height); // Non-linear gradient
    FragColor = vec4(finalColor, 1.0);
}
