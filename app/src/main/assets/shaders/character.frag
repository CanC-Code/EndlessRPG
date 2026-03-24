#version 310 es
precision highp float;

in vec3 v_Normal;
out vec4 FragColor;

void main() {
    vec3 lightDir = normalize(vec3(1.0, 1.0, 0.5));
    float diff = max(dot(v_Normal, lightDir), 0.2);
    
    // Simple cinematic grey character material
    vec3 color = vec3(0.5, 0.5, 0.6) * diff;
    
    // Apply ACES-like contrast
    color = pow(color, vec3(1.2));
    
    FragColor = vec4(color, 1.0);
}
