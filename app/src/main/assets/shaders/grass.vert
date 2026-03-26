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
out float v_Age; 
out float v_Height;
out vec2 v_UV; 

const float EARTH_RADIUS = 6371000.0;

float macroHash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float macroNoise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(macroHash(i), macroHash(i + vec2(1.0,0.0)), u.x),
               mix(macroHash(i + vec2(0.0,1.0)), macroHash(i + vec2(1.0,1.0)), u.x), u.y);
}

void main() {
    Blade b = blades[gl_InstanceID];
    
    float elevation = b.pos.y - 0.08; 
    float distToCam = length(b.pos.xz - u_CameraPos.xz);
    elevation -= (distToCam * distToCam) / (2.0 * EARTH_RADIUS);

    v_BladeHash = fract(sin(b.pos.x * 12.9898 + b.pos.z * 78.233) * 43758.5453);
    v_IsWheat = step(0.75, v_BladeHash); 

    float patchAge = macroNoise(b.pos.xz * 0.02); 
    v_Age = clamp(patchAge + (v_BladeHash * 0.4 - 0.2), 0.0, 1.0); 

    if (v_IsWheat > 0.5) {
        float matureHeight = mix(0.95, 1.35, v_BladeHash); 
        v_Height = mix(0.20, matureHeight, v_Age);    
    } else {
        float matureHeight = mix(0.25, 0.45, v_BladeHash); 
        v_Height = mix(0.08, matureHeight, v_Age);
    }

    float hFactor = a_Pos.y / 1.4; 
    float uvX = (a_Pos.x < 0.0) ? -1.0 : 1.0;
    v_UV = vec2(uvX, hFactor);

    float physicalWidth = (v_IsWheat > 0.5) ? 0.085 : 0.04; 

    // TRUE BILLBOARDING: Force the canvas to perfectly face the camera
    vec3 rootPos = vec3(b.pos.x, elevation, b.pos.z);
    vec3 toCam = normalize(u_CameraPos - rootPos);
    toCam.y = 0.0; // Keep it locked upright
    toCam = normalize(toCam);
    vec3 right = cross(vec3(0.0, 1.0, 0.0), toCam);

    // Build the billboard position
    vec3 offset = right * (uvX * physicalWidth);

    float curve = hFactor * hFactor; 
    float droopWeight = (v_IsWheat > 0.5) ? smoothstep(0.5, 1.0, hFactor) * v_Age : 0.0;

    // Wind and Physics applied relative to the root
    vec2 bendDir = normalize(b.dir.xz + vec2(sin(v_BladeHash * 6.0), cos(v_BladeHash * 6.0)));

    offset.x += bendDir.x * (droopWeight * 0.5 * v_Height + b.dir.x * curve);
    offset.z += bendDir.y * (droopWeight * 0.5 * v_Height + b.dir.z * curve);
    offset.y = (hFactor * v_Height) - (droopWeight * 0.35 * v_Height);

    // Player Interaction
    vec3 distToPlayer = rootPos - u_PlayerPos;
    float d = length(distToPlayer);
    if (d < 1.2) {
        float pushStrength = 1.0 - (d / 1.2);
        vec2 pushDir = normalize(distToPlayer.xz + vec2(0.001)); 
        offset.x += pushDir.x * pushStrength * curve;
        offset.z += pushDir.y * pushStrength * curve;
        offset.y -= pushStrength * curve; 
    }

    vec3 worldPos = rootPos + offset;
    float scale = smoothstep(120.0, 90.0, distToCam); 
    worldPos = mix(rootPos, worldPos, scale); // Collapse smoothly into the ground at a distance
    
    v_WorldPos = worldPos;
    v_ColorMix = hFactor; 
    v_Tangent = normalize(vec3(bendDir.x, 1.0 - droopWeight, bendDir.y));
    v_Normal = normalize(cross(right, v_Tangent)); // Perfect lighting normal based on the billboard
    
    vec3 localPos = vec3(worldPos.x - u_CameraPos.x, worldPos.y, worldPos.z - u_CameraPos.z);
    gl_Position = u_ViewProjection * vec4(localPos, 1.0);
}
