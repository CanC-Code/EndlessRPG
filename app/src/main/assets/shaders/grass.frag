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

    // ORGANIC HUE VARIATION
    // Blend between healthy green, dry yellowish-green, and deep clover based on the Blade Hash
    vec3 tipA = vec3(0.35, 0.65, 0.15); // Standard lively green
    vec3 tipB = vec3(0.45, 0.65, 0.10); // Slightly drier/yellowish
    vec3 tipC = vec3(0.20, 0.55, 0.18); // Deep rich green
    
    vec3 finalTip;
    if (v_BladeHash < 0.33) finalTip = mix(tipA, tipB, v_BladeHash * 3.0);
    else if (v_BladeHash < 0.66) finalTip = mix(tipB, tipC, (v_BladeHash - 0.33) * 3.0);
    else finalTip = mix(tipC, tipA, (v_BladeHash - 0.66) * 3.0);

    vec3 rootColor = vec3(0.08, 0.18, 0.05); // Roots stay dark to fake ambient occlusion
    vec3 albedo = mix(rootColor, finalTip, v_ColorMix);

    // SUBSURFACE SCATTERING (Translucency)
    // When the light is behind the grass, the light bleeds through the thin tips
    float backlight = max(dot(viewDir, -lightDir), 0.0);
    float scatter = pow(backlight, 3.0) * 0.6 * v_ColorMix; // Only the thin tips scatter light
    
    // Standard diffuse lighting
    float diff = max(dot(v_Normal, lightDir), 0.2);
    
    // Combine diffuse and scattered light
    vec3 finalColor = albedo * sunColor * (diff + scatter);

    // Atmosphere
    float dist = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.003, 2.0));

    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
