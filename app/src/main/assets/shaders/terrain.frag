#version 310 es
precision highp float;

in vec3 vWorldPos;
in float vElevation;

uniform vec3 u_CameraPos;
out vec4 FragColor;

void main() {
    // Base dirt/grass color for the ground
    vec3 groundColor = vec3(0.15, 0.25, 0.10); // Darkish green-brown soil
    
    // Atmospheric Fog
    float dist = length(vWorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.003, 2.0));
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    
    vec3 finalColor = mix(skyColor, groundColor, clamp(fogFactor, 0.0, 1.0));
    FragColor = vec4(finalColor, 1.0);
}