#version 310 es
precision highp float;
layout(location = 0) in vec3 a_Pos;

struct Blade { vec4 pos; vec4 dir; };
layout(std430, binding = 0) buffer GrassBuffer { Blade blades[]; };

uniform mat4 u_ViewProjection;
uniform vec3 u_CameraPos;
uniform vec3 u_PlayerPos; 

out vec3 v_WorldPos;
out float v_ColorMix; 

const float EARTH_RADIUS = 6371000.0;

void main() {
    Blade b = blades[gl_InstanceID];
    
    // Grab the pre-baked altitude from the Compute Shader! No expensive 3D logic here!
    float elevation = b.pos.y;

    float distToCam = length(b.pos.xz - u_CameraPos.xz);
    float curvatureDrop = (distToCam * distToCam) / (2.0 * EARTH_RADIUS);
    elevation -= curvatureDrop;

    vec3 worldPos = a_Pos;
    
    worldPos.x += b.dir.x * a_Pos.y; 
    worldPos.z += b.dir.z * a_Pos.y;
    
    vec3 absoluteBladeRoot = vec3(b.pos.x, elevation, b.pos.z);
    vec3 distToPlayer = absoluteBladeRoot - u_PlayerPos;
    float d = length(distToPlayer);
    
    if (d < 1.2) {
        float pushStrength = 1.0 - (d / 1.2);
        
        vec2 pushDir = normalize(distToPlayer.xz + vec2(0.001)); 
        worldPos.x += pushDir.x * pushStrength * 0.6 * a_Pos.y;
        worldPos.z += pushDir.y * pushStrength * 0.6 * a_Pos.y;
        worldPos.y -= pushStrength * 0.75 * a_Pos.y; 
    }
    
    float scale = smoothstep(100.0, 75.0, distToCam); 
    worldPos *= scale;
    worldPos += absoluteBladeRoot;
    
    v_WorldPos = worldPos;
    v_ColorMix = a_Pos.y / 1.4; 
    
    vec3 localPos = vec3(worldPos.x - u_CameraPos.x, worldPos.y, worldPos.z - u_CameraPos.z);
    gl_Position = u_ViewProjection * vec4(localPos, 1.0);
}
