#!/bin/bash
# File: runtime/generate_shaders.sh
# Purpose: Generates the advanced GLSL shaders for pencil realism and environment.

mkdir -p app/src/main/assets/shaders

cat << 'EOF' > app/src/main/assets/shaders/pencil_vert.glsl
#version 300 es
layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec3 aNormal;
layout(location = 2) in vec2 aTexCoord;
layout(location = 3) in ivec4 aBoneIDs;
layout(location = 4) in vec4 aWeights;

const int MAX_BONES = 100;
uniform mat4 uBoneTransforms[MAX_BONES];
uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;
uniform vec3 uSunDirection;

out vec3 vFragPos;
out vec3 vNormal;
out vec2 vTexCoord;
out float vLightIntensity;

void main() {
    mat4 boneTransform = uBoneTransforms[aBoneIDs[0]] * aWeights[0];
    boneTransform += uBoneTransforms[aBoneIDs[1]] * aWeights[1];
    boneTransform += uBoneTransforms[aBoneIDs[2]] * aWeights[2];
    boneTransform += uBoneTransforms[aBoneIDs[3]] * aWeights[3];

    vec4 localPosition = boneTransform * vec4(aPosition, 1.0);
    vec3 localNormal = mat3(boneTransform) * aNormal;

    vFragPos = vec3(uModel * localPosition);
    vNormal = normalize(mat3(uModel) * localNormal);
    vTexCoord = aTexCoord;

    // Day/Night lighting calculation
    float diffuse = max(dot(vNormal, uSunDirection), 0.0);
    float ambient = 0.2; // Starlight ambient
    vLightIntensity = diffuse + ambient;

    gl_Position = uProjection * uView * vec4(vFragPos, 1.0);
}
EOF

cat << 'EOF' > app/src/main/assets/shaders/pencil_frag.glsl
#version 300 es
precision highp float;

in vec3 vFragPos;
in vec3 vNormal;
in vec2 vTexCoord;
in float vLightIntensity;

out vec4 FragColor;

uniform sampler2D uHatch1; // Light shading
uniform sampler2D uHatch2; // Medium shading
uniform sampler2D uHatch3; // Heavy shading
uniform sampler2D uHatch4; // Densest shading
uniform vec3 uSkyColor;

void main() {
    // Procedural Pencil Hatching Logic based on Light Intensity
    vec3 hatchColor = vec3(1.0); // Paper white background
    vec2 scaledUV = vTexCoord * 10.0; // Scale for detail

    if (vLightIntensity < 0.25) {
        hatchColor = texture(uHatch4, scaledUV).rgb;
    } else if (vLightIntensity < 0.5) {
        hatchColor = texture(uHatch3, scaledUV).rgb;
    } else if (vLightIntensity < 0.75) {
        hatchColor = texture(uHatch2, scaledUV).rgb;
    } else if (vLightIntensity < 0.95) {
        hatchColor = texture(uHatch1, scaledUV).rgb;
    }

    // Blend the hatching with the underlying material color (grayscale for pencil)
    vec3 finalColor = hatchColor * vLightIntensity;
    
    // Add distance fog to blend with the sky (fixes horizon clipping perception)
    float distance = length(vFragPos);
    float fogFactor = clamp((distance - 50.0) / 100.0, 0.0, 1.0);
    
    FragColor = vec4(mix(finalColor, uSkyColor, fogFactor), 1.0);
}
EOF
chmod +x app/src/main/assets/shaders/*
echo "Pencil shaders successfully generated."
