#!/bin/bash
# File: runtime/generate_shaders.sh
# EndlessRPG v6 - Atmospheric Shader Pipeline
set -e

OUT="app/src/main/cpp/shaders/Shaders.h"
mkdir -p app/src/main/cpp/shaders

echo "// EndlessRPG Generated Shaders - v6" > $OUT
echo "#ifndef SHADERS_H" >> $OUT
echo "#define SHADERS_H" >> $OUT

# --- Vertex Shader ---
# Handles Normals and Passes Fragment Position for Fog/Light calculations
VS_SRC=$(cat <<'VEOF'
#version 300 es
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aCol;
layout(location = 2) in vec3 aNorm;

uniform mat4 uMVP;
uniform mat4 uModel;

out vec3 vCol;
out vec3 vNorm;
out vec3 vFragPos;

void main() {
    vFragPos = vec3(uModel * vec4(aPos, 1.0));
    // Normal matrix to handle non-uniform scaling/rotation
    vNorm = mat3(transpose(inverse(uModel))) * aNorm;
    vCol = aCol;
    gl_Position = uMVP * vec4(aPos, 1.0);
}
VEOF
)

# --- Fragment Shader ---
# Implements Phong Lighting + Exponential Squared Fog
FS_SRC=$(cat <<'VEOF'
#version 300 es
precision mediump float;

in vec3 vCol;
in vec3 vNorm;
in vec3 vFragPos;

uniform vec3 uSunDir;
uniform vec3 uViewPos;
uniform vec3 uFogColor;

out vec4 fragColor;

void main() {
    // 1. Lighting Calculations
    float ambient = 0.35;
    vec3 norm = normalize(vNorm);
    vec3 lightDir = normalize(uSunDir);
    float diff = max(dot(norm, lightDir), 0.0);
    
    // Specular (Gloss)
    vec3 viewDir = normalize(uViewPos - vFragPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 16.0) * 0.2;

    vec3 baseResult = (ambient + diff + spec) * vCol;

    // 2. Atmospheric Fog Calculation
    float dist = length(uViewPos - vFragPos);
    float fogDensity = 0.045; // Adjust this to match your skyline distance
    float fogFactor = 1.0 / exp(pow(dist * fogDensity, 2.0));
    fogFactor = clamp(fogFactor, 0.0, 1.0);

    // Blend the object color with the skyline/fog color
    // This makes distant objects fade into the horizon
    vec3 finalColor = mix(uFogColor, baseResult, fogFactor);

    fragColor = vec4(finalColor, 1.0);
}
VEOF
)

echo "const char* WORLD_VS = R\"($VS_SRC)\";" >> $OUT
echo "const char* WORLD_FS = R\"($FS_SRC)\";" >> $OUT
echo "#endif" >> $OUT

echo "[generate_shaders.sh] Success: Shaders.h generated with Atmospheric Fog."
