#version 310 es
precision highp float;

in vec3 v_WorldPos;
in vec3 v_Normal;
in float v_Elevation;
out vec4 FragColor;

uniform vec3 u_CameraPos;
uniform vec3 u_PlayerPos;

// Fractal Brownian Motion for geological micro-details
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
               mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}
float fbm(vec2 p) {
    float f = 0.0; float amp = 0.5;
    for(int i=0; i<4; i++) {
        f += amp * noise(p);
        p *= 2.0; amp *= 0.5;
    }
    return f;
}

void main() {
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    vec3 sunColor = vec3(1.0, 0.95, 0.85);

    // Geological Material Palette
    vec3 c_silt   = vec3(0.42, 0.36, 0.28); // Fine dust/dirt
    vec3 c_dirt   = vec3(0.28, 0.22, 0.16); // Dark rich soil
    vec3 c_gravel = vec3(0.35, 0.35, 0.35); // Chunky grey gravel
    vec3 c_rock   = vec3(0.20, 0.20, 0.20); // Solid bedrock
    
    // Generate high-detail procedural noise masks
    float detailNoise = fbm(v_WorldPos.xz * 2.0);
    float gravelNoise = fbm(v_WorldPos.xz * 0.5);

    // 1. Base Ground (Blend Dust/Silt and Rich Dirt using micro-noise)
    vec3 albedo = mix(c_silt, c_dirt, smoothstep(0.3, 0.7, detailNoise));
    
    // 2. Gravel Patches (Overlay gravel in natural scattered formations)
    float gravelMask = smoothstep(0.45, 0.65, gravelNoise);
    albedo = mix(albedo, c_gravel, gravelMask * 0.7);

    // 3. Slope Bedrock (Expose solid rock on steep angles)
    float slope = 1.0 - max(dot(v_Normal, vec3(0.0, 1.0, 0.0)), 0.0);
    albedo = mix(albedo, c_rock, smoothstep(0.15, 0.45, slope));

    // 4. Player Interactive Dust Disturbance
    // Brightens the silt slightly under the player's feet to mimic disturbed dust
    float distToPlayer = length(v_WorldPos - u_PlayerPos);
    if (distToPlayer < 1.0) {
        float dustKickup = (1.0 - distToPlayer) * 0.15;
        albedo += vec3(dustKickup); // Brightens the dirt locally
    }

    // Lighting
    float diff = max(dot(v_Normal, lightDir), 0.2);
    vec3 finalColor = albedo * sunColor * diff;

    // Atmosphere
    float distToCam = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(distToCam * 0.003, 2.0));
    
    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
