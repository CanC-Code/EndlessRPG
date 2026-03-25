#version 310 es
precision highp float;

in vec3 v_WorldPos;
in vec3 v_Normal;
in float v_ColorMix;
in float v_BladeHash;
in float v_IsWheat;
out vec4 FragColor;

uniform vec3 u_CameraPos;

void main() {
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 viewDir = normalize(u_CameraPos - v_WorldPos);
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    vec3 sunColor = vec3(1.0, 0.95, 0.85);

    // HUE DIVERSITY
    vec3 tipA = vec3(0.32, 0.60, 0.12); 
    vec3 tipB = vec3(0.40, 0.62, 0.08); 
    vec3 wheatTip = vec3(0.60, 0.50, 0.25); // Golden wheat color
    
    vec3 finalTip;
    if (v_IsWheat > 0.5) {
        finalTip = wheatTip;
    } else {
        finalTip = mix(tipA, tipB, v_BladeHash * 1.17); 
    }

    vec3 rootColor = vec3(0.04, 0.09, 0.02); 
    float aoCurve = pow(v_ColorMix, 0.7); 
    vec3 albedo = mix(rootColor, finalTip, aoCurve);

    // 1. MACRO DETAIL: STALK FIBERS (Striations)
    // Generates vertical lines running up the tube
    float fibers = sin(v_WorldPos.x * 400.0) * 0.5 + 0.5;
    albedo *= mix(0.85, 1.0, fibers);

    // 2. MACRO DETAIL: WHEAT SEEDS
    // Generates granular bumps on the upper bulge of the wheat stalks
    float specIntensity = 0.15; // Normal grass is waxy/shiny
    if (v_IsWheat > 0.5 && v_ColorMix > 0.6) {
        float seeds = sin(v_WorldPos.y * 200.0) * sin(v_WorldPos.x * 200.0);
        albedo *= mix(0.7, 1.1, seeds); // Dark and light speckles
        specIntensity = 0.0; // Wheat heads are matte, not shiny
    }

    // 3. SOIL ROOT BLENDING (Anti-Floating)
    // The bottom 15% of the grass stalk takes on the color of the dirt mesh
    // This literally paints mud onto the bottom of the grass, fusing it visually to the ground.
    vec3 dirtColor = vec3(0.18, 0.14, 0.10); // Matches the dirt in terrain.frag
    float dirtMask = 1.0 - smoothstep(0.0, 0.15, v_ColorMix);
    albedo = mix(albedo, dirtColor, dirtMask * 0.85);

    // PBR LIGHTING & TRANSLUCENCY
    vec3 halfVector = normalize(lightDir + viewDir);
    float specAmount = pow(max(dot(v_Normal, halfVector), 0.0), 8.0);
    vec3 specular = sunColor * specAmount * specIntensity * v_ColorMix;

    float backlight = max(dot(viewDir, -lightDir), 0.0);
    float scatter = pow(backlight, 4.0) * 0.6 * v_ColorMix; 
    
    float diff = max(dot(v_Normal, lightDir) * 0.7 + 0.3, 0.0);
    
    vec3 ambient = albedo * skyColor * 0.25;
    vec3 finalColor = ambient + (albedo * sunColor * (diff + scatter)) + specular;

    float dist = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.0025, 2.0));

    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
