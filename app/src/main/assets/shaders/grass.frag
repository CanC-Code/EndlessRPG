#version 310 es
precision highp float;

in vec3 v_WorldPos;
in vec3 v_Normal;
in vec3 v_Tangent;
in float v_ColorMix;
in float v_BladeHash;
in float v_IsWheat;
in float v_Age; 
in vec2 v_UV; 

out vec4 FragColor;

uniform vec3 u_CameraPos;

void main() {
    float x = v_UV.x;
    float absX = abs(x);
    float y = v_UV.y;

    float anatomyMask = 0.0;
    vec3 albedo;
    
    // Dynamic Life-Cycle Colors
    vec3 youngGreen = vec3(0.25, 0.55, 0.12);
    vec3 ripeGold   = vec3(0.75, 0.60, 0.25);
    vec3 deadBrown  = vec3(0.50, 0.40, 0.20);
    
    // The base color shifts depending on the age of this specific plant
    vec3 wheatColor = mix(youngGreen, mix(ripeGold, deadBrown, smoothstep(0.8, 1.0, v_Age)), v_Age);

    if (v_IsWheat > 0.5) {
        // STEM (Thickens slightly as it grows)
        float stemWidth = mix(0.03, 0.05, v_Age); 
        float isStem = 1.0 - smoothstep(stemWidth - 0.02, stemWidth, absX);

        // LEAF (Flag Leaf drooping down)
        float leafArc = absX - pow(max(0.0, y - 0.3), 0.5) * mix(1.0, 2.5, v_Age); // Droops more with age
        float isLeaf = (1.0 - smoothstep(0.0, 0.06, abs(leafArc))) * smoothstep(0.3, 0.6, y);

        // SPIKELETS & KERNELS (Anatomically correct overlapping seeds)
        float isSpike = 0.0;
        float isAwn = 0.0;
        
        if (y > 0.55) {
            float localY = (y - 0.55) / 0.45; // 0.0 to 1.0 along the seed head
            float rows = 14.0;
            float rowId = floor(localY * rows);
            float stagger = mod(rowId, 2.0) * 2.0 - 1.0; 
            
            vec2 cellUV = vec2(x * 2.5, fract(localY * rows));
            
            // Plumpness: Kernels swell dramatically as the wheat matures
            float kernelFatness = mix(0.12, 0.35, v_Age);
            
            // Perfect teardrop seed shape
            float d = length(vec2(cellUV.x - stagger * kernelFatness, cellUV.y - 0.5));
            float seed = 1.0 - smoothstep(0.2, 0.35, d);
            
            float headTaper = sin(localY * 3.1415); 
            isSpike = seed * smoothstep(0.0, 0.2, headTaper - absX * 0.5);
            
            // AWNS (Bristles that shoot out from the tips of the kernels)
            // They splay outward as the kernels get fat
            float awnSplay = mix(15.0, 30.0, v_Age); 
            float awnLines = smoothstep(0.95, 1.0, sin(x * awnSplay + y * 30.0)) + 
                             smoothstep(0.95, 1.0, sin(x * -awnSplay + y * 30.0));
            isAwn = awnLines * smoothstep(0.6, 1.0, y) * (1.0 - smoothstep(0.0, 0.9, absX));
        }

        anatomyMask = max(max(isStem, isLeaf), isSpike);
        anatomyMask = max(anatomyMask, isAwn);

        if (anatomyMask < 0.2) discard; 

        albedo = wheatColor;
        
        // Deep ambient occlusion in the crevices of the swollen seeds
        if (y > 0.55 && isSpike > 0.0) {
            float seedCrevice = fract((y - 0.55) / 0.45 * 14.0);
            albedo *= mix(0.3, 1.0, smoothstep(0.0, 0.4, seedCrevice));
        }

    } else {
        // NORMAL GRASS (Also affected by the maturity patch noise)
        float bladeWidth = 1.0 - pow(y, 1.2); 
        if (absX > bladeWidth) discard; 

        vec3 grassGreen = mix(vec3(0.25, 0.55, 0.12), vec3(0.35, 0.60, 0.10), v_BladeHash);
        // Grass turns slightly yellow/dry in mature patches
        albedo = mix(grassGreen, vec3(0.6, 0.6, 0.3), v_Age * 0.7); 
        
        float midrib = 1.0 - smoothstep(0.0, 0.1, absX);
        albedo = mix(albedo, albedo * 1.4, midrib * 0.5);
    }

    // --- PBR RENDERING ---

    // DIRT COLLAR (Mud fusion)
    vec3 dirtColor = vec3(0.18, 0.14, 0.10);
    float dirtCollar = 1.0 - smoothstep(0.0, 0.12, y); 
    albedo = mix(albedo, dirtColor, dirtCollar);
    albedo *= mix(0.05, 1.0, pow(y, 0.5)); // Deep root shadowing

    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 viewDir = normalize(u_CameraPos - v_WorldPos);
    
    // ANISOTROPIC LIGHTING (Fibrous Hair Shading)
    float TdotL = dot(v_Tangent, lightDir);
    float TdotV = dot(v_Tangent, viewDir);
    float sinTHL = sqrt(1.0 - TdotL * TdotL);
    float sinTHV = sqrt(1.0 - TdotV * TdotV);
    
    float dirAtten = smoothstep(-1.0, 0.0, TdotL * TdotV);
    float anisoSpec = pow(max(sinTHL * sinTHV - TdotL * TdotV, 0.0), 16.0) * dirAtten;
    
    // Specularity physics: Young plants are waxy/shiny. Mature/dead plants are matte/dry.
    float specIntensity = mix(0.25, 0.02, v_Age); 
    vec3 specular = vec3(1.0, 0.95, 0.85) * anisoSpec * specIntensity * y; 

    // SUBSURFACE SCATTERING (Translucency)
    // Young green leaves scatter lots of light. Dry golden kernels block it.
    float sssIntensity = mix(0.6, 0.1, v_Age);
    float backlight = max(dot(viewDir, -lightDir), 0.0);
    float scatter = pow(backlight, 3.0) * sssIntensity * y; 
    
    float diff = max(dot(v_Normal, lightDir) * 0.5 + 0.5, 0.0); 
    
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    vec3 ambient = albedo * skyColor * 0.4;
    vec3 finalColor = ambient + (albedo * vec3(1.0, 0.95, 0.85) * (diff + scatter)) + specular;

    float dist = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.0025, 2.0));

    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
