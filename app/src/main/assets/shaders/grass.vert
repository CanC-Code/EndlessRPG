#version 310 es
precision highp float;
layout(location = 0) in vec3 a_Pos;

struct Blade { vec4 pos; vec4 dir; };
layout(std430, binding = 0) buffer GrassBuffer { Blade blades[]; };

uniform mat4 u_ViewProjection;
uniform vec3 u_CameraPos;
uniform vec3 u_PlayerPos; // EXACT PHYSICAL POSITION

out vec3 v_WorldPos;
out float v_ColorMix; 

const float EARTH_RADIUS = 6371000.0;
const float EARTH_CIRCUMFERENCE = 2.0 * 3.14159265 * EARTH_RADIUS;

// ... (Keep existing hash3, noise3, exactElevation logic here unchanged for the globe math) ...
float hash3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float noise3(vec3 x) {
    vec3 i = floor(x); vec3 f = fract(x); vec3 u = f * f * (3.0 - 2.0 * f);
    float a0 = hash3(i + vec3(0,0,0)); float a1 = hash3(i + vec3(1,0,0));
    float a2 = hash3(i + vec3(0,1,0)); float a3 = hash3(i + vec3(1,1,0));
    float a4 = hash3(i + vec3(0,0,1)); float a5 = hash3(i + vec3(1,0,1));
    float a6 = hash3(i + vec3(0,1,1)); float a7 = hash3(i + vec3(1,1,1));
    return mix(mix(mix(a0, a1, u.x), mix(a2, a3, u.x), u.y), mix(mix(a4, a5, u.x), mix(a6, a7, u.x), u.y), u.z);
}
float exactElevation(vec2 mapXZ) {
    float lon = (mapXZ.x / EARTH_CIRCUMFERENCE) * 2.0 * 3.14159265;
    float lat = (mapXZ.y / EARTH_CIRCUMFERENCE) * 2.0 * 3.14159265;
    vec3 s = vec3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon));
    vec3 p = s * 4000.0;
    return noise3(p * 0.01) * 30.0 + noise3(p * 0.03) * 10.0;
}

void main() {
    Blade b = blades[gl_InstanceID];
    
    float gridSpacing = 4.0;
    vec2 cell = floor(b.pos.xz / gridSpacing) * gridSpacing;
    vec2 t = (b.pos.xz - cell) / gridSpacing;
    float h00 = exactElevation(cell);
    float h10 = exactElevation(cell + vec2(gridSpacing, 0.0));
    float h01 = exactElevation(cell + vec2(0.0, gridSpacing));
    float h11 = exactElevation(cell + vec2(gridSpacing, gridSpacing));
    
    float elevation;
    if (t.x + t.y <= 1.0) elevation = h00 + (h10 - h00)*t.x + (h01 - h00)*t.y;
    else elevation = h11 + (h01 - h11)*(1.0 - t.x) + (h10 - h11)*(1.0 - t.y);

    float distToCam = length(b.pos.xz - u_CameraPos.xz);
    float curvatureDrop = (distToCam * distToCam) / (2.0 * EARTH_RADIUS);
    elevation -= curvatureDrop;

    vec3 worldPos = a_Pos;
    
    // Wind execution
    worldPos.x += b.dir.x * a_Pos.y; 
    worldPos.z += b.dir.z * a_Pos.y;
    
    // --- NEW: INTERACTIVE PHYSICAL TRAMPLING ---
    vec3 absoluteBladeRoot = vec3(b.pos.x, elevation, b.pos.z);
    vec3 distToPlayer = absoluteBladeRoot - u_PlayerPos;
    float d = length(distToPlayer);
    
    // If player is within 1.2 meters, bend and squash the grass
    if (d < 1.2) {
        float pushStrength = 1.0 - (d / 1.2);
        
        // Push the blade away from the player (XZ plane)
        vec2 pushDir = normalize(distToPlayer.xz + vec2(0.001)); // Prevent divide-by-zero
        worldPos.x += pushDir.x * pushStrength * 0.6 * a_Pos.y;
        worldPos.z += pushDir.y * pushStrength * 0.6 * a_Pos.y;
        
        // Trample it flat to the ground (Y plane)
        worldPos.y -= pushStrength * 0.75 * a_Pos.y; 
    }
    // ------------------------------------------
    
    float scale = smoothstep(100.0, 75.0, distToCam); 
    worldPos *= scale;
    worldPos += absoluteBladeRoot;
    
    v_WorldPos = worldPos;
    v_ColorMix = a_Pos.y / 1.4; 
    
    vec3 localPos = vec3(worldPos.x - u_CameraPos.x, worldPos.y, worldPos.z - u_CameraPos.z);
    gl_Position = u_ViewProjection * vec4(localPos, 1.0);
}
