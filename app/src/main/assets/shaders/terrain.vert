#version 310 es
precision highp float;

layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec2 aTexCoord;
layout(location = 2) in vec3 aNormal;

// Standardized output names to strictly match the fragment shader
out vec2 TexCoord;
out vec3 Normal;
out vec3 FragPos;

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;

const float TERRAIN_AMPLITUDE = 2.5;
const float TERRAIN_FREQUENCY = 0.2;

float getTerrainHeight(float x, float z) {
    return TERRAIN_AMPLITUDE * sin(x * TERRAIN_FREQUENCY) * cos(z * TERRAIN_FREQUENCY);
}

void main() {
    vec4 worldPos = uModel * vec4(aPosition, 1.0);
    
    // Apply procedural height
    worldPos.y = getTerrainHeight(worldPos.x, worldPos.z);
    
    FragPos = worldPos.xyz;
    TexCoord = aTexCoord;
    
    // Recalculate normals
    float dx = TERRAIN_AMPLITUDE * TERRAIN_FREQUENCY * cos(worldPos.x * TERRAIN_FREQUENCY) * cos(worldPos.z * TERRAIN_FREQUENCY);
    float dz = -TERRAIN_AMPLITUDE * TERRAIN_FREQUENCY * sin(worldPos.x * TERRAIN_FREQUENCY) * sin(worldPos.z * TERRAIN_FREQUENCY);
    vec3 calculatedNormal = normalize(vec3(-dx, 1.0, -dz));
    
    Normal = mat3(transpose(inverse(uModel))) * calculatedNormal;
    
    gl_Position = uProjection * uView * worldPos;
}
