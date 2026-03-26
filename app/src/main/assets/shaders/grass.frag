#version 310 es
precision highp float;

in vec3 v_WorldPos;
in vec3 v_Normal;
in vec3 v_Tangent;
in float v_ColorMix;
in float v_BladeHash;
in float v_IsWheat;
in vec2 v_UV; 

out vec4 FragColor;

uniform vec3 u_CameraPos;

void main() {
    float x = v_UV.x;
    float absX = abs(x);
    float y = v_UV.y;

    float anatomyMask = 1.0;
    vec3 albedo;

    // BOTANICAL SIGNED DISTANCE FIELDS (Refined for Plump Wheat Seeds)
    if (v_IsWheat > 0.5) {
        float stemWidth = 0.05; // Slightly thicker, tube-like stem
        float isStem = 1.0 - smoothstep(stemWidth - 0.02, stemWidth, absX);

        float nodeDist = min(abs(y - 0.25), abs(y - 0.5)); 
        float isNode = (1.0 - smoothstep(0.0, 0.025, nodeDist)) * (1.0 - smoothstep(0.0, stemWidth + 0.05, absX));

        float leafArc = absX - pow(max(0.0, y - 0.25), 0.5) * 1.5;
        float isLeaf = (1.0 - smoothstep(0.0, 0.05, abs(leafArc))) * smoothstep(0.25, 0.45, y);

        // Plump, overlapping kernels
        float isSpike = 0.0;
        if (y > 0.6 && y < 0.9) {
            float localY = (y - 0.6) / 0.3; 
            float row = floor(localY * 16.0);
            float stagger = mod(row, 2.0) * 2.0 - 1.0; 
            
            vec2 cellUV = vec2(x * 2.0, fract(localY * 16.0));
            // Rounder, plumper seed shape
            float seed = 1.0 - smoothstep(0.25, 0.5, length(vec2(cellUV.x - stagger * 0.3, cellUV.y - 0.5)));
            
            float headTaper = sin(localY * 3.1415) * 0.85; 
            isSpike = seed * smoothstep(0.0, 0.15, headTaper - absX);
        }

        // Razor thin, jagged awns
        float awnLines = smoothstep(0.95, 1.0, sin(x * 40.0 + y * 25.0)) + smoothstep(0.95, 1.0, sin(x * -40.0 + y * 25.0));
        float isAwn = awnLines * smoothstep(0.65, 1.0, y) * (1.0 - smoothstep(0.0, 0.8, absX));

        anatomyMask = max(max(max(isStem, isNode), isLeaf), isSpike);
        anatomyMask = max(anatomyMask, isAwn);

        if (anatomyMask < 0.5) discard; 

        vec3 stemColor = vec3(0.58, 0.52, 0.28);
        vec3 spikeColor = vec3(0.70, 0.58, 0.22); 
        albedo = mix(stemColor, spikeColor, smoothstep(0.5, 0.7, y));
        
        // Add fake ambient occlusion between the wheat kernels
        if (y > 0.6 && y < 0.9) {
            float seedCrevice = fract((y - 0.6) / 0.3 * 16.0);
            albedo *= mix(0.4, 1.0, smoothstep(0.0, 0.3, seedCrevice));
        }

    } else {
        float bladeWidth = 1.0 - pow(y, 1.2); 
        if (absX > bladeWidth) discard; 

        vec3 tipA = vec3(0.32, 0.60, 0.12); 
        vec3 tipB = vec3(0.40, 0.62, 0.08); 
        vec3 grassColor = mix(tipA, tipB, v_BladeHash);
        
        float midrib = 1.0 - smoothstep(0.0, 0.1, absX);
        albedo = mix(grassColor, grassColor * 1.4, midrib * 0.5);
    }

    // THE DIRT COLLAR (Anti-Floating)
    // Aggressively blend the root into the color of the dirt, and drop the brightness to near-black
    vec3 dirtColor = vec3(0.18, 0.14, 0.10);
    float dirtCollar = 1.0 - smoothstep(0.0, 0.12, y); // Bottom 12% is caked in mud
    albedo = mix(albedo, dirtColor, dirtCollar);
    
    // Deep Base Ambient Occlusion
    albedo *= mix(0.05, 1.0, pow(y, 0.5)); // Roots are 95% black in the shadows!

    // ANISOTROPIC LIGHTING (Photorealistic Hair/Fiber glow)
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 viewDir = normalize(u_CameraPos - v_WorldPos);
    
    float TdotL = dot(v_Tangent, lightDir);
    float TdotV = dot(v_Tangent, viewDir);
    float sinTHL = sqrt(1.0 - TdotL * TdotL);
    float sinTHV = sqrt(1.0 - TdotV * TdotV);
    
    // This creates a vertical band of light instead of a circle
    float dirAtten = smoothstep(-1.0, 0.0, TdotL * TdotV);
    float anisoSpec = pow(max(sinTHL * sinTHV - TdotL * TdotV, 0.0), 16.0) * dirAtten;
    
    float specIntensity = (v_IsWheat > 0.5) ? 0.3 : 0.1; // Wheat is highly fibrous and catches the sun
    vec3 specular = vec3(1.0, 0.95, 0.85) * anisoSpec * specIntensity * y; // Only tips get specular

    // Soft Diffuse & Translucency
    float diff = max(dot(v_Normal, lightDir) * 0.5 + 0.5, 0.0); // Wrapped diffuse for organic scattering
    float backlight = max(dot(viewDir, -lightDir), 0.0);
    float scatter = pow(backlight, 3.0) * 0.5 * y; 
    
    vec3 ambient = albedo * vec3(0.45, 0.6, 0.8) * 0.4;
    vec3 finalColor = ambient + (albedo * vec3(1.0, 0.95, 0.85) * (diff + scatter)) + specular;

    float dist = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.0025, 2.0));

    FragColor = vec4(mix(vec3(0.45, 0.6, 0.8), finalColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
