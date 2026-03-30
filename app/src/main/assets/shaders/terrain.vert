#version 310 es

layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec2 aTexCoord;
layout(location = 2) in vec3 aNormal;

out vec2 vTexCoord;
out vec3 vNormal;
out vec3 vFragPos;

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;

// Terrain generation parameters (Must match Character.cpp!)
const float TERRAIN_AMPLITUDE = 2.5;
const float TERRAIN_FREQUENCY = 0.2;

float getTerrainHeight(float x, float z) {
    // A standard procedural height calculation
    return TERRAIN_AMPLITUDE * sin(x * TERRAIN_FREQUENCY) * cos(z * TERRAIN_FREQUENCY);
}

void main() {
    vTexCoord = aTexCoord;
    
    // Calculate world position
    vec4 worldPos = uModel * vec4(aPosition, 1.0);
    
    // LOGIC FIX: Apply the procedural height to the world position Y
    worldPos.y = getTerrainHeight(worldPos.x, worldPos.z);
    
    vFragPos = vec3(worldPos);
    
    // Recalculate basic normals based on the derivative of the height function
    // (Optional but highly recommended for accurate lighting on procedurally altered terrain)
    float dx = TERRAIN_AMPLITUDE * TERRAIN_FREQUENCY * cos(worldPos.x * TERRAIN_FREQUENCY) * cos(worldPos.z * TERRAIN_FREQUENCY);
    float dz = -TERRAIN_AMPLITUDE * TERRAIN_FREQUENCY * sin(worldPos.x * TERRAIN_FREQUENCY) * sin(worldPos.z * TERRAIN_FREQUENCY);
    vec3 calculatedNormal = normalize(vec3(-dx, 1.0, -dz));
    
    // Apply normal matrix 
    vNormal = mat3(transpose(inverse(uModel))) * calculatedNormal;
    
    gl_Position = uProjection * uView * worldPos;
}
