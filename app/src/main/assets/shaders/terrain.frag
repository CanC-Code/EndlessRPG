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

    // Procedural Texturing
    vec3 c_grass = vec3(0.25, 0.4, 0.15);
    vec3 c_rock = vec3(0.45, 0.45, 0.45);
    vec3 c_snow = vec3(0.9, 0.9, 0.95);

    vec3 albedo = c_grass;
    if(v_Elevation > 35.0) albedo = mix(c_grass, c_rock, smoothstep(35.0, 50.0, v_Elevation));
    if(v_Elevation > 65.0) albedo = mix(c_rock, c_snow, smoothstep(65.0, 75.0, v_Elevation));

    // Make steep slopes rocky
    float slope = 1.0 - max(dot(v_Normal, vec3(0.0, 1.0, 0.0)), 0.0);
    albedo = mix(albedo, c_rock, smoothstep(0.1, 0.4, slope));

    // Basic Diffuse Lighting
    float diff = max(dot(v_Normal, lightDir), 0.2);
    vec3 finalColor = albedo * sunColor * diff;

    // Atmospheric Horizon Fog (Hides the edge of the world)
    float dist = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.0035, 2.0));
    
    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
