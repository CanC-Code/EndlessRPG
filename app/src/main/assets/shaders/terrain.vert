#version 310 es
precision highp float;

layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec3 aColor;

out vec3 vColor;
out vec3 vNormal;
out vec3 vFragPos;

uniform mat4 uMVP;
uniform vec3 uChunkOffset;

const float TERRAIN_AMPLITUDE = 2.5;
const float TERRAIN_FREQUENCY = 0.2;

float terrain_h(float x, float z) {
    return TERRAIN_AMPLITUDE * sin(x * TERRAIN_FREQUENCY) * cos(z * TERRAIN_FREQUENCY);
}

void main() {
    vec4 worldPos = vec4(aPosition + uChunkOffset, 1.0);
    worldPos.y = terrain_h(worldPos.x, worldPos.z);

    vFragPos = worldPos.xyz;
    vColor = aColor;

    float dx = TERRAIN_AMPLITUDE * TERRAIN_FREQUENCY * cos(worldPos.x * TERRAIN_FREQUENCY) * cos(worldPos.z * TERRAIN_FREQUENCY);
    float dz = -TERRAIN_AMPLITUDE * TERRAIN_FREQUENCY * sin(worldPos.x * TERRAIN_FREQUENCY) * sin(worldPos.z * TERRAIN_FREQUENCY);
    vNormal = normalize(vec3(-dx, 1.0, -dz));

    gl_Position = uMVP * worldPos;
}
