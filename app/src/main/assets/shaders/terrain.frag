#version 310 es
precision highp float;

in vec3 v_WorldPos;
in vec3 v_Normal;
in float v_Elevation;
in float v_GravelNoise;
in float v_DetailNoise;
out vec4 FragColor;

uniform vec3 u_CameraPos;
uniform vec3 u_PlayerPos;

void main() {
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 viewDir = normalize(u_CameraPos - v_WorldPos);
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    vec3 sunColor = vec3(1.0, 0.95, 0.85);

    vec3 c_silt   = vec3(0.42, 0.36, 0.28); 
    vec3 c_dirt   = vec3(0.28, 0.22, 0.16); 
    vec3 c_gravel = vec3(0.35, 0.35, 0.35); 
    vec3 c_rock   = vec3(0.20, 0.20, 0.20); 

    // TEXTURE BLENDING
    vec3 albedo = mix(c_silt, c_dirt, smoothstep(0.3, 0.7, v_DetailNoise));
    float gravelMask = smoothstep(0.45, 0.65, v_GravelNoise);
    albedo = mix(albedo, c_gravel, gravelMask * 0.7);

    float slope = 1.0 - max(dot(v_Normal, vec3(0.0, 1.0, 0.0)), 0.0);
    albedo = mix(albedo, c_rock, smoothstep(0.15, 0.45, slope));

    // DUST KICKUP
    float distToPlayer = length(v_WorldPos - u_PlayerPos);
    if (distToPlayer < 1.0) {
        float dustKickup = (1.0 - distToPlayer) * 0.15;
        albedo += vec3(dustKickup); 
    }

    // FAKE BUMP MAPPING / MICRO-SHADOWING
    // We modify the diffuse lighting based on the noise to fake tiny granular shadows
    float bumpDetail = (v_DetailNoise - 0.5) * 0.3; // Silt/Dirt bumps
    float bumpGravel = (v_GravelNoise - 0.5) * 0.8 * gravelMask; // Harsher gravel shadows
    float microShadow = 1.0 + bumpDetail + bumpGravel;
    
    float diff = max(dot(v_Normal, lightDir), 0.1);
    diff *= clamp(microShadow, 0.3, 1.5); // Apply the tiny granular shadows

    // SPECULAR HIGHLIGHTS (Makes rocks and packed dirt look slightly reflective/tactile)
    vec3 halfVector = normalize(lightDir + viewDir);
    float specAmount = pow(max(dot(v_Normal, halfVector), 0.0), 16.0);
    // Only rocks and gravel get strong specular highlights
    float specIntensity = mix(0.02, 0.15, smoothstep(0.1, 0.4, slope) + gravelMask); 
    vec3 specular = sunColor * specAmount * specIntensity;

    vec3 finalColor = (albedo * sunColor * diff) + specular;

    // FOG
    float distToCam = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(distToCam * 0.003, 2.0));
    
    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
