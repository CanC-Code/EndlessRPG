#version 310 es
precision highp float;

in vec3 v_WorldPos;
in vec3 v_Normal;
in vec3 v_Tangent;
in float v_ColorMix;
in float v_BladeHash;
in float v_IsWheat;
in float v_Age; 
in float v_Height;
in vec2 v_UV; 

out vec4 FragColor;

uniform vec3 u_CameraPos;

void main() {
    float x = v_UV.x;
    float absX = abs(x);
    float y = v_UV.y;

    float anatomyMask = 0.0;
    vec3 albedo;
    
    vec3 youngGreen = vec3(0.28, 0.58, 0.15);
    vec3 ripeGold   = vec3(0.78, 0.62, 0.22);
    vec3 deadBrown  = vec3(0.55, 0.45, 0.25);
    
    vec3 wheatColor = mix(youngGreen, mix(ripeGold, deadBrown, smoothstep(0.8, 1.0, v_Age)), v_Age);

    if (v_IsWheat > 0.5) {
        float stemWidth = mix(0.04, 0.08, v_Age); 
        float isStem = 1.0 - smoothstep(stemWidth - 0.02, stemWidth, absX);

        float leafArc = absX - pow(max(0.0, y - 0.2), 0.5) * 2.0; 
        float isLeaf = (1.0 - smoothstep(0.0, 0.08, abs(leafArc))) * smoothstep(0.2, 0.5, y);

        float isSpike = 0.0;
        float isAwn = 0.0;
        
        float headStart = 0.75;
        float headHeight = 0.20;

        if (y > headStart && y < (headStart + headHeight)) {
            float localY = (y - headStart) / headHeight; 
            
            // Reduced frequency to prevent Moire static corruption
            float rows = 10.0; 
            float rowId = floor(localY * rows);
            float stagger = mod(rowId, 2.0) * 2.0 - 1.0; 
            
            vec2 cellUV = vec2(x * 2.0, fract(localY * rows));
            float kernelFatness = mix(0.15, 0.5, v_Age);
            
            float d = length(vec2(cellUV.x - stagger * kernelFatness, cellUV.y - 0.5));
            float seed = 1.0 - smoothstep(0.2, 0.4, d);
            
            float headTaper = sin(localY * 3.14159); 
            isSpike = seed * smoothstep(0.0, 0.2, headTaper - absX * 0.5);
        }

        if (y > headStart) {
            float awnLines = smoothstep(0.85, 1.0, sin(x * 12.0 + y * 30.0)) + 
                             smoothstep(0.85, 1.0, sin(x * -12.0 + y * 30.0));
            isAwn = awnLines * (1.0 - smoothstep(0.0, 0.6, absX)) * (1.0 - smoothstep(0.96, 1.0, y));
        }

        anatomyMask = max(max(isStem, isLeaf), isSpike);
        anatomyMask = max(anatomyMask, isAwn);

        // CLEAN DISCARD LOGIC: Completely erases the square billboard
        if (anatomyMask < 0.5) discard; 

        albedo = wheatColor;
        
        if (y > headStart && y < (headStart + headHeight) && isSpike > 0.0) {
            float seedCrevice = fract((y - headStart) / headHeight * 10.0);
            albedo *= mix(0.4, 1.0, smoothstep(0.0, 0.5, seedCrevice));
        }

    } else {
        float bladeWidth = 1.0 - pow(y, 1.5); 
        if (absX > bladeWidth) discard; 

        vec3 grassGreen = mix(vec3(0.25, 0.55, 0.12), vec3(0.35, 0.60, 0.10), v_BladeHash);
        albedo = mix(grassGreen, vec3(0.6, 0.6, 0.3), v_Age * 0.7); 
        
        float midrib = 1.0 - smoothstep(0.0, 0.15, absX);
        albedo = mix(albedo, albedo * 1.3, midrib * 0.5);
    }

    // Absolute Mud Collar
    float absoluteY = y * v_Height;
    float dirtCollar = 1.0 - smoothstep(0.0, 0.1, absoluteY); 
    
    vec3 dirtColor = vec3(0.18, 0.14, 0.10);
    albedo = mix(albedo, dirtColor, dirtCollar);
    albedo *= mix(0.1, 1.0, pow(y, 0.5));

    // Anisotropic Light
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 viewDir = normalize(u_CameraPos - v_WorldPos);
    
    float TdotL = dot(v_Tangent, lightDir);
    float TdotV = dot(v_Tangent, viewDir);
    float sinTHL = sqrt(1.0 - TdotL * TdotL);
    float sinTHV = sqrt(1.0 - TdotV * TdotV);
    
    float dirAtten = smoothstep(-1.0, 0.0, TdotL * TdotV);
    float anisoSpec = pow(max(sinTHL * sinTHV - TdotL * TdotV, 0.0), 12.0) * dirAtten;
    
    float specIntensity = mix(0.3, 0.05, v_Age); 
    vec3 specular = vec3(1.0, 0.95, 0.85) * anisoSpec * specIntensity * y; 

    float sssIntensity = mix(0.5, 0.1, v_Age);
    float backlight = max(dot(viewDir, -lightDir), 0.0);
    float scatter = pow(backlight, 3.0) * sssIntensity * y; 
    
    float diff = max(dot(v_Normal, lightDir) * 0.6 + 0.4, 0.0); 
    
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    vec3 ambient = albedo * skyColor * 0.5;
    vec3 finalColor = ambient + (albedo * vec3(1.0, 0.95, 0.85) * (diff + scatter)) + specular;

    float dist = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.0025, 2.0));

    FragColor = vec4(mix(skyColor, finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
