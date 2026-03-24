#!/bin/bash
# File: runtime/generate_shaders.sh
OUT="app/src/main/cpp/shaders/Shaders.h"
cat <<'EOF' > $OUT
#ifndef SHADERS_H
#define SHADERS_H

const char* WORLD_VS = R"(#version 300 es
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aCol;
layout(location = 2) in vec3 aNorm;
uniform mat4 uMVP, uModel;
out vec3 vCol; out vec3 vNorm; out vec3 vFragPos;
void main() {
    vFragPos = vec3(uModel * vec4(aPos, 1.0));
    vNorm = mat3(transpose(inverse(uModel))) * aNorm;
    vCol = aCol;
    gl_Position = uMVP * vec4(aPos, 1.0);
})";

const char* WORLD_FS = R"(#version 300 es
precision mediump float;
in vec3 vCol; in vec3 vNorm; in vec3 vFragPos;
uniform vec3 uSunDir, uViewPos;
out vec4 fragColor;
void main() {
    // Blinn-Phong Realism
    vec3 norm = normalize(vNorm);
    vec3 lightDir = normalize(uSunDir);
    float diff = max(dot(norm, lightDir), 0.0);
    
    vec3 viewDir = normalize(uViewPos - vFragPos);
    vec3 halfDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(norm, halfDir), 0.0), 32.0) * 0.4;

    vec3 result = (0.3 + diff + spec) * vCol;

    // Atmospheric Fog
    float dist = length(uViewPos - vFragPos);
    float fog = clamp(exp(-dist * 0.04), 0.0, 1.0);
    vec3 skyColor = vec3(0.7, 0.85, 0.95);
    fragColor = vec4(mix(skyColor, result, fog), 1.0);
})";
#endif
EOF
