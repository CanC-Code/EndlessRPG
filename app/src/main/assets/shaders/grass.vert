#version 310 es
precision highp float;
layout(location = 0) in vec3 a_Pos;

struct Blade { vec4 pos; vec4 dir; };
layout(std430, binding = 0) buffer GrassBuffer { Blade blades[]; };

uniform mat4 u_ViewProjection;
uniform vec3 u_CameraPos;
uniform vec3 u_PlayerPos; 

out vec3 v_WorldPos;
out vec3 v_Normal;
out vec3 v_Tangent; 
out float v_ColorMix; 
out float v_BladeHash; 
out float v_IsWheat;
out float v_Age; // NEW: The biological age of the plant
out vec2 v_UV; 

const float EARTH_RADIUS = 6371000.0;

// Macro noise to group growth stages into natural geographical patches
float macroHash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float macroNoise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(macroHash(i), macroHash(i + vec2(1.0,0.0)), u.x),
               mix(macroHash(i + vec2(0.0,1.0)), macroHash(i + vec2(1.0,1.0)), u.x), u.y);
}

void main() {
    Blade b = blades[gl_InstanceID];
    
    // Physical Root Embedding
    float elevation = b.pos.y - 0.08; 
    float distToCam = length(b.pos.xz - u_CameraPos.xz);
    elevation -= (distToCam * distToCam) / (2.0 * EARTH_RADIUS);

    v_BladeHash = fract(sin(b.pos.x * 12.9898 + b.pos.z * 78.233) * 43758.5453);
    v_IsWheat = step(0.80, v_BladeHash); // 20% Wheat

    // BIOLOGICAL AGE (0.0 = Young/Green/Straight, 1.0 = Mature/Gold/Heavy)
    // We blend large 50m patches with individual micro-variations
    float patchAge = macroNoise(b.pos.xz * 0.02); 
    v_Age = clamp(patchAge + (v_BladeHash * 0.4 - 0.2), 0.0, 1.0); 

    float heightScale = mix(0.8, 1.6, v_BladeHash); 
    float hFactor = a_Pos.y / 1.4; 
    
    float uvX = (a_Pos.x < 0.0) ? -1.0 : (a_Pos.x > 0.0 ? 1.0 : 0.0);
    v_UV = vec2(uvX, hFactor);

    // Widen canvas to support wide, drooping leaves and spreading awns
    float physicalWidth = (v_IsWheat > 0.5) ? 0.16 : 0.05;
    
    vec3 worldPos = a_Pos;
    worldPos.x = uvX * physicalWidth; 
    worldPos.y *= heightScale; 

    float curve = hFactor * hFactor; 

    if (v_IsWheat < 0.5) {
        float foldDepth = (worldPos.x * worldPos.x) * 20.0; 
        worldPos.z -= foldDepth; 
    }

    // --- HEAVY GRAIN DROOP PHYSICS ---
    if (v_IsWheat > 0.5) {
        // As wheat matures (v_Age -> 1.0), the top 40% gets incredibly heavy
        float droopWeight = smoothstep(0.5, 1.0, hFactor) * v_Age;
        
        // Bend it forward heavily, imitating the iconic arched hook of ripe wheat
        worldPos.x += sign(b.dir.x + 0.001) * droopWeight * 0.6;
        worldPos.y -= droopWeight * 0.4; // Pull the head down physically
    }

    v_Tangent = normalize(vec3(b.dir.x * 2.0 * hFactor, 1.0, b.dir.z * 2.0 * hFactor));

    // Wind and Trample
    worldPos.x += b.dir.x * curve; 
    worldPos.z += b.dir.z * curve;
    
    vec3 absoluteBladeRoot = vec3(b.pos.x, elevation, b.pos.z);
    vec3 distToPlayer = absoluteBladeRoot - u_PlayerPos;
    float d = length(distToPlayer);
    
    if (d < 1.2) {
        float pushStrength = 1.0 - (d / 1.2);
        vec2 pushDir = normalize(distToPlayer.xz + vec2(0.001)); 
        worldPos.x += pushDir.x * pushStrength * 0.8 * curve;
        worldPos.z += pushDir.y * pushStrength * 0.8 * curve;
        worldPos.y -= pushStrength * 0.8 * curve; 
        v_Tangent = normalize(vec3(pushDir.x, 0.2, pushDir.y)); 
    }
    
    float scale = smoothstep(120.0, 90.0, distToCam); 
    worldPos *= scale;
    worldPos += absoluteBladeRoot;
    
    v_WorldPos = worldPos;
    v_ColorMix = hFactor; 
    v_Normal = normalize(vec3(worldPos.x * 10.0, 0.2, 1.0));
    
    vec3 localPos = vec3(worldPos.x - u_CameraPos.x, worldPos.y, worldPos.z - u_CameraPos.z);
    gl_Position = u_ViewProjection * vec4(localPos, 1.0);
}
