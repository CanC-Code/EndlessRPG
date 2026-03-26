#version 310 es
precision highp float;

in vec3 vNormal;
in vec2 vUV;
in vec3 vWorldPos;
in float vHeightTaper;

uniform vec3 u_CameraPos;

out vec4 FragColor;

void main() {
    vec3 viewDir = normalize(u_CameraPos - vWorldPos);
    vec3 lightDir = normalize(vec3(0.6, 0.8, 0.3)); // Sun direction
    
    // Albedo Variation (Base color shifts based on world position to create patches of dry/green grass)
    float colorNoise = fract(sin(dot(vWorldPos.xz, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 colorGreen = vec3(0.25, 0.45, 0.15);
    vec3 colorDry = vec3(0.65, 0.6, 0.3);
    vec3 baseColor = mix(colorGreen, colorDry, colorNoise * 0.4 + 0.2);

    // Tip gradient (lighter at the top, dark near the soil)
    baseColor = mix(baseColor * 0.3, baseColor * 1.2, vHeightTaper);

    // Two-sided normal handling for flat quad foliage
    vec3 normal = dot(vNormal, viewDir) < 0.0 ? -vNormal : vNormal;

    // Diffuse Lighting
    float diff = max(dot(normal, lightDir), 0.0);
    
    // SUBSURFACE SCATTERING (Translucency when looking towards the sun through the grass)
    float backLight = max(dot(viewDir, -lightDir), 0.0);
    float translucency = pow(backLight, 4.0) * 0.6 * vHeightTaper; // Only tips let light through
    vec3 scatterColor = vec3(0.7, 0.8, 0.3) * translucency;

    // Ambient Occlusion at the roots
    float ao = mix(0.1, 1.0, vHeightTaper);

    vec3 finalColor = baseColor * (diff + 0.2) * ao + scatterColor;
    
    // Aerial Perspective (Fog)
    float dist = length(u_CameraPos - vWorldPos);
    float fogFactor = exp(-dist * 0.015);
    vec3 fogColor = vec3(0.5, 0.65, 0.8); // Atmospheric blue/gray
    
    FragColor = vec4(mix(fogColor, finalColor, fogFactor), 1.0);
}
