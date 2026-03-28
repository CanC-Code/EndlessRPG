#version 310 es
precision highp float;

in vec3 vNormal;
in vec3 vWorldPos;
in float vHeightTaper;

uniform vec3 u_CameraPos;
out vec4 FragColor;

void main() {
    vec3 lightDir = normalize(vec3(0.6, 0.8, 0.3));
    
    // Albedo Variation (Break up the uniform field with dry/green patches)
    float colorNoise = fract(sin(dot(floor(vWorldPos.xz), vec2(12.9898, 78.233))) * 43758.5453);
    vec3 colorGreen = vec3(0.25, 0.45, 0.15);
    vec3 colorDry = vec3(0.65, 0.6, 0.3);
    vec3 baseColor = mix(colorGreen, colorDry, colorNoise * 0.4 + 0.2);
    
    // Root to Tip gradient
    vec3 rootColor = baseColor * 0.3; 
    vec3 tipColor = baseColor * 1.2;
    vec3 grassColor = mix(rootColor, tipColor, vHeightTaper);
    
    // Basic Diffuse Lighting
    float diffuse = max(dot(vNormal, lightDir), 0.2);
    vec3 finalColor = grassColor * diffuse;

    // Atmospheric Fog
    float dist = length(vWorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.003, 2.0));
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    
    finalColor = mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0));
    FragColor = vec4(finalColor, 1.0);
}
