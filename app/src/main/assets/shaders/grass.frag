#version 310 es
precision highp float; // Upgraded precision for better color blending and noise calculation

in float v_Height;
in float v_Type;

out vec4 FragColor;

// High-frequency noise for natural texture (film grain / plant fibers)
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// ACES Filmic Tone Mapping for cinematic camera realism
vec3 ACESFilm(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    vec3 colorRoot;
    vec3 colorTip;

    // =======================================================
    // --- WARM "GOLDEN HOUR" PROCEDURAL PALETTES
    // =======================================================
    if (v_Type < 0.15) {
        // Wheat / Seed Stalks - Rich, bright golden yellow
        colorRoot = vec3(0.25, 0.18, 0.08);  
        colorTip  = vec3(1.00, 0.85, 0.45);  
    } 
    else if (v_Type < 0.30) {
        // Dead / Dry Broken Stems - Sun-bleached tan
        colorRoot = vec3(0.18, 0.14, 0.10);  
        colorTip  = vec3(0.80, 0.70, 0.55);  
    } 
    else {
        // Prairie Sod Grass - Warmer, sun-baked greens
        float greenVar = (v_Type - 0.3) / 0.7; 
        colorRoot = vec3(0.02, 0.15 + (greenVar * 0.08), 0.03); 
        
        vec3 tipA = vec3(0.40, 0.70, 0.20); // Yellow-green
        vec3 tipB = vec3(0.60, 0.80, 0.25); // Bright sunlit green
        colorTip  = mix(tipA, tipB, greenVar); 
    }

    // =======================================================
    // --- CINEMATIC LIGHTING & MICRO-TEXTURE
    // =======================================================
    float heightMix = clamp(v_Height * 0.9, 0.0, 1.0);
    
    // Ambient Occlusion (Darker, heavier roots)
    float ao = smoothstep(0.0, 0.5, v_Height);
    vec3 albedo = mix(colorRoot, colorTip, heightMix * heightMix) * (0.15 + 0.85 * ao);
    
    // Fibrous Texture: Add subtle noise to simulate grass veins and break up flat colors
    float noise = random(gl_FragCoord.xy) * 0.06;
    albedo += (noise * ao); // Apply texture mostly to illuminated areas
    
    // Intense Subsurface Scattering (Warm sunlight bleeding through thin tips)
    float translucency = smoothstep(0.5, 1.2, v_Height);
    vec3 sss = vec3(0.60, 0.55, 0.20) * (translucency * translucency); 
    
    // Specular Rim Highlight (The bright white/gold edge of the grass catching the sun)
    float rim = smoothstep(0.9, 1.15, v_Height);
    vec3 rimLight = vec3(1.0, 0.95, 0.8) * rim * (v_Type < 0.15 ? 1.0 : 0.4); // Wheat catches more light

    vec3 finalColor = albedo + sss + rimLight;

    // =======================================================
    // --- WARM ATMOSPHERIC PERSPECTIVE (FOG)
    // =======================================================
    float linearDepth = 1.0 / gl_FragCoord.w;
    float fogFactor = smoothstep(6.0, 22.0, linearDepth); 
    
    // Instead of flat blue, we use a warm, hazy golden sunset fog
    vec3 fogColor = vec3(0.75, 0.85, 0.95); // Bright hazy sky
    vec3 sunHaze = vec3(1.0, 0.8, 0.5) * 0.6; // Golden light
    
    finalColor = mix(finalColor, fogColor + sunHaze, fogFactor);

    // =======================================================
    // --- CAMERA SENSOR TONE MAPPING
    // =======================================================
    finalColor = ACESFilm(finalColor * 1.4); // Boosted exposure for that bright outdoor feel

    FragColor = vec4(finalColor, 1.0);
}
