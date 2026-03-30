#version 310 es
precision highp float;

layout(location = 0) in vec3 aPosition;      // The local vertex of the grass blade model
layout(location = 1) in vec3 aInstanceOffset;// The X/Z world position from the compute shader buffer

out vec2 TexCoord;

uniform mat4 uView;
uniform mat4 uProjection;

const float TERRAIN_AMPLITUDE = 2.5;
const float TERRAIN_FREQUENCY = 0.2;

float getTerrainHeight(float x, float z) {
    return TERRAIN_AMPLITUDE * sin(x * TERRAIN_FREQUENCY) * cos(z * TERRAIN_FREQUENCY);
}

void main() {
    // Start with the local grass vertex
    vec4 worldPos = vec4(aPosition, 1.0);
    
    // Add the world offset for this specific grass blade
    worldPos.x += aInstanceOffset.x;
    worldPos.z += aInstanceOffset.z;
    
    // LOGIC FIX: Snap the geometry's Y position to the procedural terrain!
    // (We also add the local aPosition.y so the blade extends upwards from the ground)
    worldPos.y = getTerrainHeight(worldPos.x, worldPos.z) + aPosition.y;
    
    // Pass a vertical gradient (0.0 to 1.0) based on local height for the fragment shader
    TexCoord = vec2(0.5, aPosition.y); 

    gl_Position = uProjection * uView * worldPos;
}
