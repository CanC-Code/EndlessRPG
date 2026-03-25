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
out float v_ColorMix; 
out float v_BladeHash; 

const float EARTH_RADIUS = 6371000.0;

void main() {
    Blade b = blades[gl_InstanceID];
    float elevation = b.pos.y;

    float distToCam = length(b.pos.xz - u_CameraPos.xz);
    float curvatureDrop = (distToCam * distToCam) / (2.0 * EARTH_RADIUS);
    elevation -= curvatureDrop;

    // Generate Blade Hash (0.0 to 1.0)
    v_BladeHash = fract(sin(b.pos.x * 12.9898 + b.pos.z * 78.233) * 43758.5453);

    // BIOLOGICAL DIVERSITY: Randomize height and width per blade
    float heightScale = mix(0.7, 1.5, v_BladeHash); 
    float widthScale = mix(0.8, 1.2, fract(v_BladeHash * 10.0));
    
    vec3 worldPos = a_Pos;
    worldPos.x *= widthScale; // Randomize thickness
    worldPos.y *= heightScale; // Randomize tallness

    float hFactor = worldPos.y / (1.4 * heightScale); 
    float curve = hFactor * hFactor; 

    // Wind and Trample curve
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
    }
    
    float scale = smoothstep(120.0, 90.0, distToCam); // Extended draw distance slightly
    worldPos *= scale;
    worldPos += absoluteBladeRoot;
    
    v_WorldPos = worldPos;
    v_ColorMix = hFactor; 
    v_Normal = normalize(vec3(b.dir.x * hFactor, 1.0, b.dir.z * hFactor));
    
    vec3 localPos = vec3(worldPos.x - u_CameraPos.x, worldPos.y, worldPos.z - u_CameraPos.z);
    gl_Position = u_ViewProjection * vec4(localPos, 1.0);
}
