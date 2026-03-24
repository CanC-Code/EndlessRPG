#version 310 es
precision highp float;

in vec3 v_WorldPos;
in vec3 v_Normal;
in float v_Elevation;

out vec4 FragColor;

// Basic procedural hash for texturing
float hash(vec2 p) { 
    vec2 p2 = fract(p * vec2(5.3983, 5.4427));
    p2 += dot(p2.yx, p2.xy + vec2(21.5351, 14.3137));
    return fract(p2.x * p2.y * 95.4337);
}

// 2D Noise for breaking up the dirt and rock colors
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// ACES Filmic Tone Mapping (Must match the grass exactly)
vec3 ACESFilm(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    // 1. Calculate the slope (0.0 is perfectly flat ground, 1.0 is a vertical cliff wall)
    float slope = 1.0 - v_Normal.y;
    
    // 2. Procedural Texturing
    // Create some noise to make the ground look patchy and organic
    float detailNoise = noise(v_WorldPos.xz * 2.0);
    float macroNoise = noise(v_WorldPos.xz * 0.1);
    
    // Dirt / Mud Palette (Dark, rich browns)
    vec3 dirtColor = mix(vec3(0.08, 0.06, 0.04), vec3(0.12, 0.09, 0.06), detailNoise);
    
    // Rock / Cliff Palette (Grays and dry earth)
    vec3 rockColor = mix(vec3(0.25, 0.22, 0.20), vec3(0.15, 0.14, 0.13), macroNoise);
    
    // 3. Slope Blending
    // If the slope is steep (> 0.4), it becomes rock. If flat, it stays dirt.
    // We add detailNoise to the blend edge so the transition looks jagged and natural, not perfectly straight.
    float rockBlend = smoothstep(0.3, 0.5, slope + (detailNoise * 0.1));
    vec3 albedo = mix(dirtColor, rockColor, rockBlend);
    
    // 4. Directional Sunlight
    // Matches the golden hour lighting angle from the grass shader
    vec3 sunDir = normalize(vec3(1.0, 0.8, 0.6)); 
    float diffuse = max(dot(v_Normal, sunDir), 0.0);
    
    // Ambient light (so shadows aren't pitch black)
    vec3 ambient = vec3(0.05, 0.06, 0.08);
    
    // Apply lighting
    vec3 finalColor = albedo * (diffuse * vec3(1.0, 0.9, 0.7) + ambient);
    
    // =======================================================
    // --- WARM ATMOSPHERIC PERSPECTIVE (FOG)
    // --- EXACT match to the grass shader to prevent seams
    // =======================================================
    float linearDepth = 1.0 / gl_FragCoord.w;
    float fogFactor = smoothstep(6.0, 22.0, linearDepth); 
    
    vec3 fogColor = vec3(0.75, 0.85, 0.95); 
    vec3 sunHaze = vec3(1.0, 0.8, 0.5) * 0.6; 
    
    finalColor = mix(finalColor, fogColor + sunHaze, fogFactor);

    // Tone Mapping
    finalColor = ACESFilm(finalColor * 1.4); 

    FragColor = vec4(finalColor, 1.0);
}
