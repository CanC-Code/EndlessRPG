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
out vec3 v_Tangent; // NEW: Points UP the stalk for Anisotropic fiber lighting
out float v_ColorMix; 
out float v_BladeHash; 
out float v_IsWheat;
out vec2 v_UV; 

const float EARTH_RADIUS = 6371000.0;

void main() {
    Blade b = blades[gl_InstanceID];
    
    // Sink the root deeply into the dirt to physically anchor it
    float elevation = b.pos.y - 0.08; 

    float distToCam = length(b.pos.xz - u_CameraPos.xz);
    float curvatureDrop = (distToCam * distToCam) / (2.0 * EARTH_RADIUS);
    elevation -= curvatureDrop;

    v_BladeHash = fract(sin(b.pos.x * 12.9898 + b.pos.z * 78.233) * 43758.5453);
    v_IsWheat = step(0.85, v_BladeHash); 

    float heightScale = mix(0.7, 1.5, v_BladeHash); 
    float hFactor = a_Pos.y / 1.4; 
    
    float uvX = (a_Pos.x < 0.0) ? -1.0 : (a_Pos.x > 0.0 ? 1.0 : 0.0);
    v_UV = vec2(uvX, hFactor);

    float physicalWidth = (v_IsWheat > 0.5) ? 0.12 : 0.04;
    
    vec3 worldPos = a_Pos;
    worldPos.x = uvX * physicalWidth; 
    worldPos.y *= heightScale; 

    float curve = hFactor * hFactor; 

    if (v_IsWheat < 0.5) {
        float foldDepth = (worldPos.x * worldPos.x) * 20.0; 
        worldPos.z -= foldDepth; 
    }

    // Calculate Tangent (Points up the blade, factoring in the wind/curve)
    v_Tangent = normalize(vec3(b.dir.x * 2.0 * hFactor, 1.0, b.dir.z * 2.0 * hFactor));

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
        
        // Update Tangent when trampled
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
