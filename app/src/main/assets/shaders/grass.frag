#version 310 es
precision highp float;

in vec3 v_WorldPos;
in vec3 v_Normal;
in float v_ColorMix;
in float v_BladeHash;
out vec4 FragColor;

uniform vec3 u_CameraPos;

void main() {
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 viewDir = normalize(u_CameraPos - v_WorldPos);
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    vec3 sunColor = vec3(1.0, 0.95, 0.85);

    // HUE DIVERSITY
    vec3 tipA = vec3(0.32, 0.60, 0.12); // Lush green
    vec3 tipB = vec3(0.40, 0.62, 0.08); // Sun-baked green
    vec3 dryStalk = vec3(0.55, 0.45, 0.20); // Dead, yellow/brown wheat grass
    
    vec3 finalTip;
    
    // 15% of the meadow consists of completely dead/dry grass blades
    if (v_BladeHash > 0.85) {
        finalTip = dryStalk;
    } else {
        finalTip = mix(tipA, tipB, v_BladeHash * 1.17); // Distribute greens
    }

    // DEEP AMBIENT OCCLUSION (Roots)
    // By aggressively darkening the roots, the grass looks incredibly thick and dense
    vec3 rootColor = vec3(0.04, 0.09, 0.02); // Almost black
    
    // We use a power curve so the darkness stays low to the ground
    float aoCurve = pow(v_ColorMix, 0.7); 
    vec3 albedo = mix(rootColor, finalTip, aoCurve);

    // PBR: Waxy Specular Highlight
    // Real grass has a cuticle layer that shines when the sun hits it
    vec3 halfVector = normalize(lightDir + viewDir);
    float specAmount = pow(max(dot(v_Normal, halfVector), 0.0), 8.0);
    // Dead grass is matte, alive grass is shiny
    float specIntensity = (v_BladeHash > 0.85) ? 0.0 : 0.15; 
    vec3 specular = sunColor * specAmount * specIntensity * v_ColorMix;

    // SUBSURFACE SCATTERING
    float backlight = max(dot(viewDir, -lightDir), 0.0);
    float scatter = pow(backlight, 4.0) * 0.6 * v_ColorMix; 
    
    // DIFFUSE LIGHTING
    // Wrap lighting slightly around the blade to soften shadows
    float diff = max(dot(v_Normal, lightDir) * 0.7 + 0.3, 0.0);
    
    vec3 ambient = albedo * skyColor * 0.25;
    vec3 finalColor = ambient + (albedo * sunColor * (diff + scatter)) + specular;

    float dist = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.0025, 2.0));

    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
