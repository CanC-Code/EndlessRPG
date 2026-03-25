#version 310 es
precision highp float;

in vec3 v_WorldPos;
in vec3 v_Normal;
in float v_Elevation;
out vec4 FragColor;

uniform vec3 u_CameraPos;

void main() {
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    vec3 sunColor = vec3(1.0, 0.95, 0.85);

    // Warm, lush, photographic colors
    vec3 c_grass = vec3(0.2, 0.35, 0.12);
    vec3 c_dirt = vec3(0.35, 0.28, 0.22); 

    // Smooth slope transitioning (No Voxels!)
    float slope = 1.0 - max(dot(v_Normal, vec3(0.0, 1.0, 0.0)), 0.0);
    vec3 albedo = mix(c_grass, c_dirt, smoothstep(0.1, 0.4, slope));

    float diff = max(dot(v_Normal, lightDir), 0.2);
    vec3 finalColor = albedo * sunColor * diff;

    float dist = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.003, 2.0));
    
    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
