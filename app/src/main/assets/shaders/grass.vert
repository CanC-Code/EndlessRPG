#version 310 es
layout(location = 0) in vec3 aPos;       // Local blade geometry (8 vertices)
layout(location = 1) in vec4 aInstance;  // x, y, z world position, w = rotation/scale hash

uniform mat4 u_ViewProjection;
uniform vec3 u_PlayerPos;
uniform float u_Time;

out vec3 vNormal;
out vec2 vUV;
out vec3 vWorldPos;
out float vHeightTaper;

void main() {
    float hash = aInstance.w;
    float scale = 0.8 + (fract(hash * 13.33) * 0.6); // Random height variance
    
    // Base vertex height (0.0 at root, 1.0 at tip)
    float normalizedHeight = aPos.y / 1.40; 
    vHeightTaper = normalizedHeight;
    vUV = vec2(aPos.x + 0.5, normalizedHeight);

    // Rotate blade randomly around Y axis
    float angle = hash * 6.28318;
    float c = cos(angle), s = sin(angle);
    mat3 rotY = mat3(
        c, 0.0, s,
        0.0, 1.0, 0.0,
        -s, 0.0, c
    );

    vec3 localPos = rotY * (aPos * vec3(1.0, scale, 1.0));
    vec3 worldPos = localPos + aInstance.xyz;

    // --- PROCEDURAL WIND PHYSICS ---
    // Multi-octave sine waves moving across world XZ coordinates
    float windStrength = 0.15;
    float windSpeed = 2.5;
    vec2 windDir = normalize(vec2(1.0, 0.5));
    float windPhase = dot(worldPos.xz, windDir) * 0.2 + u_Time * windSpeed;
    float windBend = (sin(windPhase) + sin(windPhase * 2.3) * 0.5) * windStrength;
    
    // --- PLAYER COLLISION KINEMATICS ---
    // Push grass away radially based on proximity to the player
    vec2 toPlayerXZ = worldPos.xz - u_PlayerPos.xz;
    float distToPlayer = length(toPlayerXZ);
    float collisionRadius = 0.8; // Player physical radius
    
    if (distToPlayer < collisionRadius) {
        float pushForce = (collisionRadius - distToPlayer) / collisionRadius;
        // Smoothstep for natural organic bending
        pushForce = smoothstep(0.0, 1.0, pushForce);
        vec2 pushDir = normalize(toPlayerXZ);
        // Only bend the upper vertices, keep roots grounded
        worldPos.xz -= pushDir * pushForce * normalizedHeight * 0.6;
        worldPos.y -= pushForce * normalizedHeight * 0.3; // Squash down
    }

    // Apply wind bending (mostly affects the tip)
    worldPos.xz += windDir * windBend * pow(normalizedHeight, 2.0);

    vWorldPos = worldPos;
    vNormal = normalize(rotY * vec3(0.0, 0.0, 1.0));
    
    gl_Position = u_ViewProjection * vec4(worldPos, 1.0);
}
