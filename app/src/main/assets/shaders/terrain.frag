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

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
               mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}

void main() {
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 viewDir = normalize(u_CameraPos - v_WorldPos);
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    vec3 sunColor = vec3(1.0, 0.95, 0.85);

    vec3 c_silt   = vec3(0.38, 0.31, 0.24); 
    vec3 c_dirt   = vec3(0.18, 0.14, 0.10); 
    vec3 c_gravel = vec3(0.40, 0.38, 0.36); 
    vec3 c_rock   = vec3(0.15, 0.15, 0.16); 

    // Procedural Normal Mapping
    vec2 eps = vec2(0.05, 0.0);
    float bumpL = noise((v_WorldPos.xz - eps.xy) * 5.0);
    float bumpR = noise((v_WorldPos.xz + eps.xy) * 5.0);
    float bumpD = noise((v_WorldPos.xz - eps.yx) * 5.0);
    float bumpU = noise((v_WorldPos.xz + eps.yx) * 5.0);
    
    vec3 perturbedNormal = normalize(v_Normal + vec3(bumpL - bumpR, 0.6, bumpD - bumpU) * 0.8);

    // Color Blending
    float detailMix = smoothstep(0.3, 0.7, v_DetailNoise);
    vec3 albedo = mix(c_silt, c_dirt, detailMix);
    
    float gravelMask = smoothstep(0.45, 0.65, v_GravelNoise);
    albedo = mix(albedo, c_gravel, gravelMask);

    float slope = 1.0 - max(dot(v_Normal, vec3(0.0, 1.0, 0.0)), 0.0);
    albedo = mix(albedo, c_rock, smoothstep(0.2, 0.5, slope));

    // CAVITY MAPPING (Micro-shadows for pores in the dirt)
    // We use high frequency hash noise to punch tiny black dots into the soil, creating deep porosity
    float cavityNoise = hash(v_WorldPos.xz * 15.0);
    albedo *= mix(0.5, 1.0, smoothstep(0.1, 0.6, cavityNoise));

    // Dust Kickup
    float distToPlayer = length(v_WorldPos - u_PlayerPos);
    if (distToPlayer < 1.0) {
        float dustKickup = (1.0 - distToPlayer) * 0.15;
        albedo += vec3(dustKickup); 
    }

    // OREN-NAYAR ROUGH DIFFUSE (PBR for porous dirt)
    float NdotL = max(dot(perturbedNormal, lightDir), 0.0);
    float NdotV = max(dot(perturbedNormal, viewDir), 0.0);
    
    // Fake Oren-Nayar approximation for mobile efficiency
    float angleSoftening = NdotL * (1.0 + 0.3 * (1.0 - NdotV));
    float diff = max(angleSoftening, 0.05); // Preserves deep shadows in the cavities

    // FRESNEL SPECULAR (Rocks reflect at glancing angles, dirt stays matte)
    vec3 halfVector = normalize(lightDir + viewDir);
    float baseSpec = pow(max(dot(perturbedNormal, halfVector), 0.0), 8.0);
    float fresnel = pow(1.0 - NdotV, 4.0); // Glancing angle reflection
    
    float roughness = mix(0.0, 0.3, gravelMask + smoothstep(0.2, 0.5, slope)); // Only rocks/gravel are shiny
    vec3 specular = sunColor * baseSpec * fresnel * roughness;

    vec3 ambient = albedo * skyColor * 0.3;
    vec3 finalColor = ambient + (albedo * sunColor * diff) + specular;

    float distToCam = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(distToCam * 0.0025, 2.0));
    
    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
