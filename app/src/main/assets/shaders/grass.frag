#version 310 es
precision mediump float;

in vec2 TexCoord;
out vec4 FragColor;

void main() {
    // Simple procedural grass styling (dark green at the root, vibrant green at the tip)
    vec3 baseColor = vec3(0.1, 0.4, 0.1);
    vec3 tipColor  = vec3(0.3, 0.7, 0.2);
    
    // TexCoord.y represents the height along the blade of grass
    vec3 finalColor = mix(baseColor, tipColor, TexCoord.y);
    
    FragColor = vec4(finalColor, 1.0);
}
