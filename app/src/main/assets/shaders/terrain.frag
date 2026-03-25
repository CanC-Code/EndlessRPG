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

// Re-declare noise for calculating physical bump normals
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

    // Highly realistic Earth Palette
    vec3 c_silt   = vec3(0.38, 0.31, 0.24); // Fine dusty silt
    vec3 c_dirt   = vec3(0.18, 0.14, 0.10); // Deep rich, slightly damp soil
    vec3 c_gravel = vec3(0.40, 0.38, 0.36); // Coarse grey stones
    vec3 c_rock   = vec3(0.15, 0.15, 0.16); // Bedrock

    // --- PROCEDURAL NORMAL MAPPING ---
    // Calculate the slope of the noise to create physical 3D bumps
    vec2 eps = vec2(0.05, 0.0);
    float bumpL = noise((v_WorldPos.xz - eps.xy) * 4.0);
    float bumpR = noise((v_WorldPos.xz + eps.xy) * 4.0);
    float bumpD = noise((v_WorldPos.xz - eps.yx) * 4.0);
    float bumpU = noise((v_WorldPos.xz + eps.yx) * 4.0);
    
    // Tilt the base normal using the noise derivative
    vec3 perturbedNormal = normalize(v_Normal + vec3(bumpL - bumpR, 0.8, bumpD - bumpU) * 0.6);

    // TEXTURE BLENDING
    float detailMix = smoothstep(0.3, 0.7, v_DetailNoise);
    vec3 albedo = mix(c_silt, c_dirt, detailMix);
    
    float gravelMask = smoothstep(0.45, 0.65, v_GravelNoise);
    albedo = mix(albedo, c_gravel, gravelMask);

    float slope = 1.0 - max(dot(v_Normal, vec3(0.0, 1.0, 0.0)), 0.0);
    albedo = mix(albedo, c_rock, smoothstep(0.2, 0.5, slope));

    // INTERACTIVE DUST
    float distToPlayer = length(v_WorldPos - u_PlayerPos);
    if (distToPlayer < 1.0) {
        float dustKickup = (1.0 - distToPlayer) * 0.12;
        albedo += vec3(dustKickup); 
    }

    // PBR LIGHTING & SPECULARITY
    float diff = max(dot(perturbedNormal, lightDir), 0.05); // Deep shadows in the crevices
    
    // Damp soil and smooth pebbles reflect light. Silt does not.
    vec3 halfVector = normalize(lightDir + viewDir);
    float specAmount = pow(max(dot(perturbedNormal, halfVector), 0.0), 12.0);
    float roughness = mix(0.0, 0.25, detailMix + gravelMask); // Dirt and gravel are shiny, silt is matte
    vec3 specular = sunColor * specAmount * roughness;

    // Apply soft ambient lighting to prevent pitch-black shadows
    vec3 ambient = albedo * skyColor * 0.3;
    vec3 finalColor = ambient + (albedo * sunColor * diff) + specular;

    // FOG
    float distToCam = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(distToCam * 0.0025, 2.0));
    
    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
