#!/bin/bash
# File: runtime/generate_shaders.sh
OUT="app/src/main/cpp/shaders/Shaders.h"
echo "#ifndef SHADERS_H" > $OUT
echo "#define SHADERS_H" >> $OUT

VS="layout(location=0) in vec3 aPos; \
layout(location=1) in vec3 aCol; \
layout(location=2) in vec3 aNorm; \
uniform mat4 uMVP; uniform mat4 uModel; \
out vec3 vCol; out vec3 vNorm; out vec3 vFragPos; \
void main() { \
    vFragPos = vec3(uModel * vec4(aPos, 1.0)); \
    vNorm = mat3(transpose(inverse(uModel))) * aNorm; \
    vCol = aCol; \
    gl_Position = uMVP * vec4(aPos, 1.0); \
}"

FS="precision mediump float; \
in vec3 vCol; in vec3 vNorm; in vec3 vFragPos; \
uniform vec3 uSunDir; uniform vec3 uViewPos; \
out vec4 fragColor; \
void main() { \
    vec3 norm = normalize(vNorm); \
    vec3 lightDir = normalize(uSunDir); \
    float diff = max(dot(norm, lightDir), 0.0); \
    vec3 viewDir = normalize(uViewPos - vFragPos); \
    vec3 halfDir = normalize(lightDir + viewDir); \
    float spec = pow(max(dot(norm, halfDir), 0.0), 32.0) * 0.5; \
    vec3 lighting = (0.3 + diff + spec) * vCol; \
    float dist = length(uViewPos - vFragPos); \
    float fog = clamp(exp(-dist * 0.05), 0.0, 1.0); \
    fragColor = vec4(mix(vec3(0.7, 0.8, 0.9), lighting, fog), 1.0); \
}"

echo "const char* WORLD_VS = \"#version 300 es\n$VS\";" >> $OUT
echo "const char* WORLD_FS = \"#version 300 es\n$FS\";" >> $OUT
echo "#endif" >> $OUT
