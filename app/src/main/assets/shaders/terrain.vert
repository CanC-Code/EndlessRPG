#version 310 es
precision highp float;

// We only need X and Z coordinates for the flat grid; the shader calculates Y.
layout(location = 0) in vec2 a_Pos; 

uniform mat4 u_ViewProjection;
uniform vec3 u_CameraPos;

out vec3 v_WorldPos;
out vec3 v_Normal;
out float v_Elevation;

// ==========================================
// --- IDENTICAL MATH TO GRASS.COMP ---
// (This guarantees the ground and grass roots match perfectly)
// ==========================================
float hash(vec2 p) { 
    vec2 p2 = fract(p * vec2(5.3983, 5.4427));
    p2 += dot(p2.yx, p2.xy + vec2(21.5351, 14.3137));
    return fract(p2.x * p2.y * 95.4337);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float f = 0.0;
    float amp = 0.5;
    for(int i = 0; i < 3; i++) {
        f += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return f;
}

float getElevation(vec2 pos) {
    float base = fbm(pos * 0.005);
    float mountains = pow(fbm(pos * 0.015 + vec2(100.0)), 2.5) * 50.0;
    float plateaus = smoothstep(0.4, 0.6, fbm(pos * 0.02)) * 12.0;
    float hills = fbm(pos * 0.035) * 8.0;
    float biomeMask = smoothstep(0.35, 0.65, base);
    
    float elevation = mix(plateaus + hills, mountains, biomeMask);
    elevation += fbm(pos * 0.3) * 0.4; // Micro-details
    
    return elevation;
}

void main() {
    // Snap the grid to the nearest whole number relative to the camera
    // This makes the ground seamlessly follow the player infinitely
    vec2 snappedCam = floor(u_CameraPos.xz);
    vec2 worldXZ = a_Pos + snappedCam;
    
    // Calculate vertical elevation
    float elevation = getElevation(worldXZ);
    v_WorldPos = vec3(worldXZ.x, elevation, worldXZ.y);
    v_Elevation = elevation;

    // --- PROCEDURAL NORMALS (For 3D Lighting) ---
    // By sampling the height of the terrain slightly to the left, right, up, and down,
    // we can calculate the exact slope and angle of the ground at this vertex.
    float eps = 0.1;
    float hL = getElevation(worldXZ + vec2(-eps, 0.0));
    float hR = getElevation(worldXZ + vec2(eps, 0.0));
    float hD = getElevation(worldXZ + vec2(0.0, -eps));
    float hU = getElevation(worldXZ + vec2(0.0, eps));
    
    v_Normal = normalize(vec3(hL - hR, 2.0 * eps, hD - hU));
    
    gl_Position = u_ViewProjection * vec4(v_WorldPos, 1.0);
}
