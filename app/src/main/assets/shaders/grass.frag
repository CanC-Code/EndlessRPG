#version 310 es
precision mediump float;

in float v_Height;
out vec4 FragColor;

void main() {
    vec3 colorBottom = vec3(0.05, 0.20, 0.05); // Dark, shaded roots
    vec3 colorTop    = vec3(0.35, 0.65, 0.15); // Sunlit tips
    
    vec3 finalColor = mix(colorBottom, colorTop, v_Height);
    
    FragColor = vec4(finalColor, 1.0);
}
