#version 310 es
precision mediump float;

in vec2 v_UV;
in float v_HeightData;

out vec4 FragColor;

void main() {
    // Gradient from root to tip
    vec3 rootColor = vec3(0.05, 0.2, 0.02);
    vec3 tipColor = vec3(0.3, 0.5, 0.1);
    
    // Add some sub-surface scattering fake by brightening the tips
    vec3 finalColor = mix(rootColor, tipColor, v_HeightData);
    
    FragColor = vec4(finalColor, 1.0);
}
