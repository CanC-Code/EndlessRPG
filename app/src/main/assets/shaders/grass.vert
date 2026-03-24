#version 310 es
precision highp float;

// Base geometry of a single blade (passed via VBO)
layout(location = 0) in vec3 a_Position; 

// SSBO containing the logic from the compute shader
struct GrassBlade {
    vec4 position_and_height;
    vec4 tilt_and_wind;
};
layout(std430, binding = 0) buffer GrassBuffer {
    GrassBlade blades[];
};

uniform mat4 u_ViewProjection;

out vec2 v_UV;
out float v_HeightData;

void main() {
    // gl_InstanceID tells us which specific blade we are currently drawing
    GrassBlade thisBlade = blades[gl_InstanceID];
    
    vec3 localPos = a_Position;
    
    // Scale the blade by its growth height
    localPos.y *= thisBlade.position_and_height.w;
    
    // Apply wind bending (more bend at the top of the blade)
    float heightFactor = clamp(a_Position.y, 0.0, 1.0);
    vec3 windOffset = vec3(thisBlade.tilt_and_wind.x, 0.0, thisBlade.tilt_and_wind.z) * thisBlade.tilt_and_wind.w * heightFactor * heightFactor;
    
    vec3 finalWorldPos = thisBlade.position_and_height.xyz + localPos + windOffset;
    
    gl_Position = u_ViewProjection * vec4(finalWorldPos, 1.0);
    
    // Pass data to the fragment shader for coloring
    v_UV = vec2(a_Position.x + 0.5, a_Position.y); 
    v_HeightData = heightFactor;
}
