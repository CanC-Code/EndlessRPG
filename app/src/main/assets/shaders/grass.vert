#version 310 es
precision highp float;

layout(location = 0) in vec3 a_Pos;

struct Blade { 
    vec4 pos; 
    vec4 wind; 
};

layout(std430, binding = 0) buffer B { 
    Blade blades[]; 
};

uniform mat4 u_ViewProjection;
out float v_Height;

// Creates a matrix to rotate the grass blade around its vertical Y-axis
mat3 rotationY(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return mat3(
        c, 0.0, s,
        0.0, 1.0, 0.0,
        -s, 0.0, c
    );
}

void main() {
    // 1. Extract data from the Compute Shader SSBO
    Blade b = blades[gl_InstanceID];
    vec3 bladePos = b.pos.xyz;
    float bladeHeight = b.pos.w;
    
    vec2 windDir = b.wind.xy;
    float rotAngle = b.wind.z;
    float windStrength = b.wind.w;

    vec3 localPos = a_Pos;
    
    // 2. Scale the blade to its individual procedural height
    localPos.y *= bladeHeight;
    
    // 3. Rotate the blade locally so the field looks chaotic and dense
    localPos = rotationY(rotAngle) * localPos;

    // 4. Advanced Wind Bending Mechanics
    // We use the raw a_Pos.y (0.0 at root, ~1.1 at tip) to find how far up the blade we are
    float heightPercent = a_Pos.y; 
    
    // The higher up the blade, the exponentially harder the wind pushes it
    float bendFactor = pow(heightPercent, 2.0) * windStrength; 
    
    // Push the blade horizontally along the fluid wind direction
    localPos.x += windDir.x * bendFactor;
    localPos.z += windDir.y * bendFactor;
    
    // Structural physics: As the blade bends forward, it must lose some vertical height
    localPos.y -= bendFactor * 0.3;

    // Shift the calculated local geometry into its final world position
    vec3 worldPos = localPos + bladePos;

    // Pass the height gradient data to the fragment shader for perfect coloring
    v_Height = a_Pos.y; 
    
    gl_Position = u_ViewProjection * vec4(worldPos, 1.0);
}
