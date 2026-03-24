#version 310 es
precision mediump float;

in float v_Height;
in float v_Type;

out vec4 FragColor;

// ACES Filmic Tone Mapping for cinematic photorealism
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

    // --- PROCEDURAL COLOR PALETTES ---
    if (v_Type < 0.15) {
        // Wheat / Seed Stalks
        colorRoot = vec3(0.12, 0.09, 0.05);  
        colorTip  = vec3(0.95, 0.80, 0.40);  
    } 
    else if (v_Type < 0.30) {
        // Dead / Dry Broken Stems
        colorRoot = vec3(0.10, 0.08, 0.05);  
        colorTip  = vec3(0.65, 0.55, 0.45);  
    } 
    else {
        // Prairie Sod Grass
        float greenVar = (v_Type - 0.3) / 0.7; 
        colorRoot = vec3(0.01, 0.10 + (greenVar * 0.05), 0.01); 
        vec3 tipA = vec3(0.25, 0.65, 0.15); 
        vec3 tipB = vec3(0.40, 0.75, 0.20); 
        colorTip  = mix(tipA, tipB, greenVar); 
    }

    // --- LIGHTING & FAKE AMBIENT OCCLUSION ---
    float heightMix = clamp(v_Height * 0.9, 0.0, 1.0);
    
    // Non-linear curve for deeper shadows at the root (Fake AO)
    float ao = smoothstep(0.0, 0.4, v_Height);
    vec3 albedo = mix(colorRoot, colorTip, heightMix * heightMix) * (0.2 + 0.8 * ao);
    
    // Fake Subsurface Scattering (Sun bleeding through tips)
    float translucency = smoothstep(0.5, 1.2, v_Height);
    vec3 sss = vec3(0.30, 0.35, 0.10) * translucency; 
    
    vec3 finalColor = albedo + sss;

    // --- ATMOSPHERIC PERSPECTIVE (DISTANCE FOG) ---
    // gl_FragCoord.w is (1.0 / Z_view). Therefore, 1.0 / gl_FragCoord.w gives exact linear distance!
    float linearDepth = 1.0 / gl_FragCoord.w;
    
    // Start fading at 8 units away, fully hidden by 20 units (the edge of our 512x512 grid)
    float fogFactor = smoothstep(8.0, 20.0, linearDepth);
    
    // The fog color EXACTLY matches our glClearColor from the Renderer (0.5, 0.75, 1.0)
    vec3 fogColor = vec3(0.5, 0.75, 1.0);
    
    // Add a warm "Sun Haze" to the fog based on height for volumetric realism
    vec3 sunHaze = vec3(0.95, 0.85, 0.70) * 0.5 * translucency;
    fogColor += sunHaze;

    // Blend the grass into the sky
    finalColor = mix(finalColor, fogColor, fogFactor);

    // --- CAMERA SENSOR TONE MAPPING ---
    // Boost exposure slightly, then apply ACES filmic curve
    finalColor = ACESFilm(finalColor * 1.3); 

    FragColor = vec4(finalColor, 1.0);
}
