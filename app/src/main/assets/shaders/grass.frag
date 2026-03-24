#version 310 es
precision mediump float;

in float v_Height;
in float v_Type; // Caught from the Vertex Shader

out vec4 FragColor;

void main() {
    vec3 colorRoot;
    vec3 colorTip;

    // =======================================================
    // --- PROCEDURAL COLOR PALETTES (PRAIRIE BIODIVERSITY)
    // =======================================================

    if (v_Type < 0.15) {
        // SPECIES 1: Tall Wheat / Seed Stalks
        colorRoot = vec3(0.18, 0.15, 0.10);  // Deep earthy shadow
        colorTip  = vec3(0.85, 0.75, 0.35);  // Golden sunlit wheat head
    } 
    else if (v_Type < 0.30) {
        // SPECIES 2: Dead / Dry Broken Stems
        colorRoot = vec3(0.15, 0.12, 0.08);  // Dark rotting brown
        colorTip  = vec3(0.55, 0.48, 0.38);  // Dry, bleached tan
    } 
    else {
        // SPECIES 3: Prairie Sod Grass Blades
        // We use the remaining v_Type data to create micro-variations in the green
        // so no two patches of grass are the exact same shade.
        float greenVar = (v_Type - 0.3) / 0.7; // Normalize to 0.0 -> 1.0
        
        colorRoot = vec3(0.02, 0.15 + (greenVar * 0.05), 0.02); // Deep shaded green
        
        // Ranges from vibrant green to a slightly yellowish late-summer green
        vec3 tipA = vec3(0.20, 0.55, 0.10); 
        vec3 tipB = vec3(0.35, 0.65, 0.15); 
        colorTip  = mix(tipA, tipB, greenVar); 
    }

    // =======================================================
    // --- LIGHTING & BLENDING
    // =======================================================

    // 1. Height Gradient: Mix the root and tip colors based on pixel height.
    // We use an exponential curve (heightMix * heightMix) so the dark roots 
    // stay low to the ground and the bright colors pop nicely at the top.
    float heightMix = clamp(v_Height * 0.9, 0.0, 1.0);
    vec3 finalColor = mix(colorRoot, colorTip, heightMix * heightMix);
    
    // 2. Fake Subsurface Scattering (Sunlight filtering through thin tips)
    // This adds a warm, glowing yellowish tint to the very top of the tallest blades
    float translucency = smoothstep(0.6, 1.2, v_Height);
    finalColor += vec3(0.15, 0.15, 0.0) * translucency;

    FragColor = vec4(finalColor, 1.0);
}
