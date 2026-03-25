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
out float v_IsWheat;

const float EARTH_RADIUS = 6371000.0;

void main() {
    Blade b = blades[gl_InstanceID];
    
    // 1. PHYSICAL ROOT EMBEDDING
    // Push the root 5cm underground so it penetrates the dirt mesh instead of hovering
    float elevation = b.pos.y - 0.05; 

    float distToCam = length(b.pos.xz - u_CameraPos.xz);
    float curvatureDrop = (distToCam * distToCam) / (2.0 * EARTH_RADIUS);
    elevation -= curvatureDrop;

    v_BladeHash = fract(sin(b.pos.x * 12.9898 + b.pos.z * 78.233) * 43758.5453);
    v_IsWheat = step(0.85, v_BladeHash); // 1.0 if this blade is a dead wheat stalk, 0.0 if normal grass

    float heightScale = mix(0.7, 1.5, v_BladeHash); 
    float widthScale = mix(0.7, 1.3, fract(v_BladeHash * 10.0));
    
    vec3 worldPos = a_Pos;
    worldPos.x *= widthScale; 
    worldPos.y *= heightScale; 

    float hFactor = worldPos.y / (1.4 * heightScale); 
    float curve = hFactor * hFactor; 

    // 2. PROCEDURAL TUBULAR FOLDING
    // Fold the outer edges of the flat strip backward to create a U-shaped 3D cylinder
    float edgeWidth = a_Pos.x * widthScale;
    float foldDepth = (edgeWidth * edgeWidth) * 25.0; 
    worldPos.z -= foldDepth; 

    // 3. WHEAT HEAD GENERATION
    // Bulge the top 30% of the wheat stalks to form thick seed heads
    float wheatBulge = smoothstep(0.6, 0.8, hFactor) * (1.0 - smoothstep(0.95, 1.0, hFactor));
    worldPos.x += sign(edgeWidth) * wheatBulge * 0.04 * v_IsWheat;

    // Apply wind and trample to the folded structure
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
    
    float scale = smoothstep(120.0, 90.0, distToCam); 
    worldPos *= scale;
    worldPos += absoluteBladeRoot;
    
    v_WorldPos = worldPos;
    v_ColorMix = hFactor; 
    
    // TUBULAR NORMALS: Splay the normals outward so light treats the flat polygon like a round pipe
    vec3 localNormal = normalize(vec3(edgeWidth * 15.0, 0.2, 1.0));
    v_Normal = localNormal; // (Simplified for performance, standard lighting will handle the rest)
    
    vec3 localPos = vec3(worldPos.x - u_CameraPos.x, worldPos.y, worldPos.z - u_CameraPos.z);
    gl_Position = u_ViewProjection * vec4(localPos, 1.0);
}
