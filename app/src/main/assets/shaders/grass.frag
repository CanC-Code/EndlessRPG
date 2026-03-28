#version 310 es
precision highp float;

in vec3 vNormal;
in vec2 vUV;
in vec3 vWorldPos;
in float vHeightTaper; // Replaces v_ColorMix

uniform vec3 u_CameraPos;
out vec4 FragColor;

void main() {
    vec3 viewDir = normalize(u_CameraPos - vWorldPos);
    vec3 lightDir = normalize(vec3(0.6, 0.8, 0.3)); // Sun direction
    
    // Albedo Variation (Base color shifts based on world position to create patches)
    float colorNoise = fract(sin(dot(vWorldPos.xz, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 colorGreen = vec3(0.25, 0.45, 0.15);
    vec3 colorDry = vec3(0.65, 0.6, 0.3);
    vec3 baseColor = mix(colorGreen, colorDry, colorNoise * 0.4 + 0.2);
    
    // RESTORED: Tip gradient (lighter at the top, dark root near the soil)
    vec3 rootColor = baseColor * 0.3; 
    vec3 tipColor = baseColor * 1.2;
    vec3 grassColor = mix(rootColor, tipColor, vHeightTaper);
    
    // Basic Diffuse Lighting
    float diffuse = max(dot(vNormal, lightDir), 0.2);
    vec3 finalColor = grassColor * diffuse;

    // RESTORED: Atmospheric Fog
    float dist = length(vWorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.003, 2.0));
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    
    // Blend final grass color with the sky color based on distance
    finalColor = mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0));

    FragColor = vec4(finalColor, 1.0);
}
