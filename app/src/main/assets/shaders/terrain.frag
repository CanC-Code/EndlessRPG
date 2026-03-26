#version 310 es
precision highp float;

in vec3 vWorldPos;
in vec3 vNormal;
in float vSlope;

uniform vec3 u_CameraPos;
out vec4 FragColor;

void main() {
    vec3 lightDir = normalize(vec3(0.6, 0.8, 0.3));
    vec3 viewDir = normalize(u_CameraPos - vWorldPos);
    
    // Biome Blending
    vec3 soilColor = vec3(0.15, 0.12, 0.1);  // Dark wet soil
    vec3 grassBase = vec3(0.2, 0.35, 0.12); // Lush moss/grass
    vec3 rockColor = vec3(0.3, 0.3, 0.35);  // Gray stone
    
    // Flat areas are grass, steep areas are rock
    vec3 baseColor = mix(grassBase, rockColor, smoothstep(0.3, 0.7, vSlope));
    baseColor = mix(baseColor, soilColor, 0.2); // Add earth tones

    // Lighting
    float diff = max(dot(vNormal, lightDir), 0.0);
    float ambient = 0.25;
    
    vec3 finalColor = baseColor * (diff + ambient);
    
    // Distance Fog (Atmospheric Perspective)
    float dist = length(u_CameraPos - vWorldPos);
    float fog = clamp(exp(-dist * 0.01), 0.0, 1.0);
    vec3 skyColor = vec3(0.5, 0.65, 0.8);

    FragColor = vec4(mix(skyColor, finalColor, fog), 1.0);
}
