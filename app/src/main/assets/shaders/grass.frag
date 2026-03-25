#version 310 es
precision highp float;

in vec3 v_WorldPos;
in vec3 v_Normal;
in float v_ColorMix;
in float v_BladeHash;
in float v_IsWheat;
in vec2 v_UV; // -1 to 1 on X, 0 to 1 on Y

out vec4 FragColor;

uniform vec3 u_CameraPos;

void main() {
    float x = v_UV.x;
    float absX = abs(x);
    float y = v_UV.y;

    float anatomyMask = 1.0;
    vec3 albedo;

    // BOTANICAL SIGNED DISTANCE FIELDS (SDF)
    if (v_IsWheat > 0.5) {
        // 1. STEM (Culm)
        float stemWidth = 0.06;
        float isStem = 1.0 - smoothstep(stemWidth - 0.02, stemWidth, absX);

        // 2. NODES (Swollen joints on the stem)
        float nodeDist = min(abs(y - 0.25), abs(y - 0.5)); // Nodes at 25% and 50% height
        float isNode = (1.0 - smoothstep(0.0, 0.02, nodeDist)) * (1.0 - smoothstep(0.0, stemWidth + 0.04, absX));

        // 3. LEAVES (Peeling away from nodes)
        float leafArc = absX - pow(max(0.0, y - 0.25), 0.5) * 1.5;
        float isLeaf = (1.0 - smoothstep(0.0, 0.04, abs(leafArc))) * smoothstep(0.25, 0.45, y);

        // 4. SPIKELETS (The overlapping seeds/kernels)
        float isSpike = 0.0;
        if (y > 0.6 && y < 0.9) {
            float localY = (y - 0.6) / 0.3; // Normalize spike length 0 to 1
            float row = floor(localY * 14.0);
            float stagger = mod(row, 2.0) * 2.0 - 1.0; // Alternate left/right
            
            vec2 cellUV = vec2(x * 2.0, fract(localY * 14.0));
            float seed = 1.0 - smoothstep(0.2, 0.45, length(vec2(cellUV.x - stagger * 0.25, cellUV.y - 0.5)));
            
            float headTaper = sin(localY * 3.1415) * 0.8; // Bulges in the middle, pinches at ends
            isSpike = seed * smoothstep(0.0, 0.1, headTaper - absX);
        }

        // 5. AWNS (The long spiky bristles)
        // High frequency sine waves criss-crossing upwards
        float awnLines = smoothstep(0.9, 1.0, sin(x * 30.0 + y * 20.0)) + smoothstep(0.9, 1.0, sin(x * -30.0 + y * 20.0));
        float isAwn = awnLines * smoothstep(0.65, 1.0, y) * (1.0 - smoothstep(0.0, 0.8, absX));

        // 6. FIBROUS ROOTS (Crown)
        float rootCurve = smoothstep(0.8, 1.0, sin(absX * 20.0 - y * 50.0));
        float isRoot = rootCurve * (1.0 - smoothstep(0.0, 0.1, y)); // Only at the very bottom

        // Combine all body parts into one solid mask
        anatomyMask = max(max(max(max(isStem, isNode), isLeaf), isSpike), isRoot);
        anatomyMask = max(anatomyMask, isAwn);

        if (anatomyMask < 0.5) discard; // ERASE ALL EMPTY SPACE!

        // WHEAT COLORING
        vec3 stemColor = vec3(0.55, 0.50, 0.25);
        vec3 spikeColor = vec3(0.65, 0.55, 0.20); 
        vec3 rootColor = vec3(0.18, 0.14, 0.10); // Matches the dirt perfectly

        albedo = mix(stemColor, spikeColor, smoothstep(0.5, 0.7, y));
        albedo = mix(albedo, rootColor, isRoot * (1.0 - smoothstep(0.0, 0.08, y))); // Paint mud on roots

    } else {
        // NORMAL GRASS SDFS
        float bladeWidth = 1.0 - pow(y, 1.5); // Smooth organic taper to the tip
        if (absX > bladeWidth) discard; 

        vec3 tipA = vec3(0.32, 0.60, 0.12); 
        vec3 tipB = vec3(0.40, 0.62, 0.08); 
        vec3 grassColor = mix(tipA, tipB, v_BladeHash);
        
        // Midrib (The central lighter vein on grass blades)
        float midrib = 1.0 - smoothstep(0.0, 0.08, absX);
        albedo = mix(grassColor, grassColor * 1.3, midrib * 0.4);

        vec3 rootColor = vec3(0.06, 0.12, 0.04); 
        albedo = mix(rootColor, albedo, pow(v_ColorMix, 0.6));
        
        // Dirt Root Blending
        vec3 dirtColor = vec3(0.18, 0.14, 0.10);
        albedo = mix(albedo, dirtColor, 1.0 - smoothstep(0.0, 0.1, y));
    }

    // PBR LIGHTING & TRANSLUCENCY
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 viewDir = normalize(u_CameraPos - v_WorldPos);
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    vec3 sunColor = vec3(1.0, 0.95, 0.85);

    vec3 halfVector = normalize(lightDir + viewDir);
    float specAmount = pow(max(dot(v_Normal, halfVector), 0.0), 12.0);
    float specIntensity = (v_IsWheat > 0.5) ? 0.0 : 0.15; // Wheat is matte, grass is waxy
    vec3 specular = sunColor * specAmount * specIntensity * v_ColorMix;

    float backlight = max(dot(viewDir, -lightDir), 0.0);
    float scatter = pow(backlight, 4.0) * 0.6 * v_ColorMix; 
    
    float diff = max(dot(v_Normal, lightDir) * 0.7 + 0.3, 0.0);
    
    vec3 ambient = albedo * skyColor * 0.3;
    vec3 finalColor = ambient + (albedo * sunColor * (diff + scatter)) + specular;

    float dist = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.0025, 2.0));

    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
