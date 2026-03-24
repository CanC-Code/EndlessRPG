#version 310 es
precision highp float;

in vec3 v_WorldPos;
in vec3 v_Normal;
in float v_Elevation;

uniform vec3 u_CameraPos; // Passed from C++ to calculate specular reflections

out vec4 FragColor;

// --- NOISE & HASH FUNCTIONS ---
float hash(vec2 p) { 
    vec2 p2 = fract(p * vec2(5.3983, 5.4427));
    p2 += dot(p2.yx, p2.xy + vec2(21.5351, 14.3137));
    return fract(p2.x * p2.y * 95.4337);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float f = 0.0;
    float amp = 0.5;
    for(int i = 0; i < 4; i++) { // 4 octaves for extra detail
        f += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return f;
}

// ACES Tone Mapping (Matches grass)
vec3 ACESFilm(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    // =======================================================
    // --- 1. PROCEDURAL BUMP MAPPING (MICRO-NORMALS)
    // =======================================================
    // Calculate the gradient (slope) of our high-frequency noise
    vec2 eps = vec2(0.02, 0.0);
    float bumpScale = 15.0; // High frequency for dust/rock granularity
    
    // Sample the noise around the current pixel to find the tiny local slopes
    float dFdx = fbm((v_WorldPos.xz + eps.xy) * bumpScale) - fbm((v_WorldPos.xz - eps.xy) * bumpScale);
    float dFdz = fbm((v_WorldPos.xz + eps.yx) * bumpScale) - fbm((v_WorldPos.xz - eps.yx) * bumpScale);
    
    // Twist the geometric normal using our noise gradient
    vec3 bumpedNormal = normalize(v_Normal + vec3(-dFdx, 0.0, -dFdz) * 1.5);
    
    // Recalculate slope using the newly roughened normal
    float rawSlope = 1.0 - v_Normal.y;
    float bumpedSlope = 1.0 - bumpedNormal.y;

    // =======================================================
    // --- 2. ORGANIC MATERIAL TEXTURING
    // =======================================================
    float macroNoise = fbm(v_WorldPos.xz * 0.3); // Large sweeping patches
    float dustNoise = fbm(v_WorldPos.xz * 6.0);  // Small, scattered details
    
    // Color Palettes
    vec3 dustColor = mix(vec3(0.35, 0.28, 0.20), vec3(0.42, 0.34, 0.24), dustNoise); // Bright, sandy dust
    vec3 mudColor  = mix(vec3(0.12, 0.09, 0.06), vec3(0.18, 0.13, 0.08), macroNoise); // Deep, rich root soil
    vec3 rockColor = mix(vec3(0.20, 0.19, 0.18), vec3(0.30, 0.28, 0.26), dustNoise);  // Hard grey slate
    
    // Blending Logic
    // 1. Blend mud and dust together in flat areas based on large noise patches
    vec3 groundColor = mix(mudColor, dustColor, smoothstep(0.3, 0.7, macroNoise));
    
    // 2. If the slope is steep, the dirt washes away to reveal the rock beneath
    float rockBlend = smoothstep(0.20, 0.45, bumpedSlope + (macroNoise * 0.15));
    vec3 albedo = mix(groundColor, rockColor, rockBlend);

    // =======================================================
    // --- 3. CINEMATIC LIGHTING
    // =======================================================
    vec3 sunDir = normalize(vec3(1.0, 0.8, 0.6)); 
    
    // Diffuse lighting uses our rough, bumped normal so the dirt casts micro-shadows
    float diffuse = max(dot(bumpedNormal, sunDir), 0.0);
    
    // Specular Highlight (Only the rock faces should look slightly hard/shiny)
    vec3 viewDir = normalize(u_CameraPos - v_WorldPos);
    vec3 reflectDir = reflect(-sunDir, bumpedNormal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 16.0);
    float rockHighlight = spec * rockBlend * 0.25; 
    
    vec3 ambient = vec3(0.05, 0.06, 0.08);
    vec3 finalColor = albedo * (diffuse * vec3(1.0, 0.9, 0.7) + ambient) + (vec3(1.0, 0.9, 0.7) * rockHighlight);

    // =======================================================
    // --- 4. WARM ATMOSPHERIC PERSPECTIVE (FOG)
    // =======================================================
    float linearDepth = 1.0 / gl_FragCoord.w;
    float fogFactor = smoothstep(6.0, 22.0, linearDepth); 
    
    vec3 fogColor = vec3(0.75, 0.85, 0.95); 
    vec3 sunHaze = vec3(1.0, 0.8, 0.5) * 0.6; 
    
    finalColor = mix(finalColor, fogColor + sunHaze, fogFactor);

    // =======================================================
    // --- 5. CAMERA TONE MAPPING
    // =======================================================
    finalColor = ACESFilm(finalColor * 1.4); 

    FragColor = vec4(finalColor, 1.0);
}
