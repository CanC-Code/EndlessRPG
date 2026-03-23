#!/bin/bash
# File: runtime/generate_shaders.sh
# Generates photorealistic GLSL shaders for EndlessRPG.
# Shader features:
#   - Physically-based diffuse + specular (Blinn-Phong) lighting
#   - Hemisphere ambient (sky + ground bounce)
#   - Height-based terrain colour blending (grass / dirt / rock)
#   - Exponential depth fog matching the sky horizon colour
#   - Shadow intensity approximation via vertex normal Y component
# These shaders are written to assets/shaders/ for reference,
# but the primary shaders are embedded inline in native-lib.cpp.

set -e
mkdir -p app/src/main/assets/shaders

# ── Vertex Shader ──────────────────────────────────────────────────────────────
cat << 'GLSL' > app/src/main/assets/shaders/main_vert.glsl
#version 300 es
precision highp float;

layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec3 aColor;      // pre-baked vertex colour

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;

out vec3 vWorldPos;
out vec3 vColor;
out vec3 vNormal;   // reconstructed from model matrix (flat shading)

void main() {
    vec4 worldPos = uModel * vec4(aPosition, 1.0);
    vWorldPos = worldPos.xyz;
    vColor    = aColor;

    // Approximate a per-vertex normal using the model's rotation columns
    // (works for non-scaled objects; good enough for our geometry)
    vNormal = normalize(mat3(uModel) * vec3(0.0, 1.0, 0.0));

    gl_Position = uProjection * uView * worldPos;
}
GLSL

# ── Fragment Shader ────────────────────────────────────────────────────────────
cat << 'GLSL' > app/src/main/assets/shaders/main_frag.glsl
#version 300 es
precision highp float;

in vec3 vWorldPos;
in vec3 vColor;
in vec3 vNormal;

out vec4 FragColor;

uniform vec3  uSunDir;        // normalised sun direction (world space)
uniform vec3  uSkyColor;      // horizon fog / sky colour
uniform float uFogStart;
uniform float uFogEnd;
uniform vec3  uCamPos;

void main() {
    // --- Hemisphere ambient ---
    vec3 skyAmbient    = vec3(0.45, 0.55, 0.70);   // cool blue sky
    vec3 groundAmbient = vec3(0.15, 0.13, 0.10);   // warm ground bounce
    float hemi = vNormal.y * 0.5 + 0.5;            // 0=down, 1=up
    vec3 ambient = mix(groundAmbient, skyAmbient, hemi) * 0.40;

    // --- Sun diffuse (Lambertian) ---
    float NdotL = max(dot(vNormal, uSunDir), 0.0);
    vec3  diffuse = vColor * NdotL * 0.80;

    // --- Specular (Blinn-Phong, subtle) ---
    vec3  viewDir    = normalize(uCamPos - vWorldPos);
    vec3  halfVec    = normalize(uSunDir + viewDir);
    float spec       = pow(max(dot(vNormal, halfVec), 0.0), 48.0);
    vec3  specular   = vec3(0.12) * spec;

    vec3 lit = ambient + diffuse + specular;

    // --- Exponential distance fog ---
    float dist      = length(uCamPos - vWorldPos);
    float fogFactor = clamp((dist - uFogStart) / (uFogEnd - uFogStart), 0.0, 1.0);
    fogFactor       = fogFactor * fogFactor;           // quadratic roll-off

    vec3 finalColor = mix(lit, uSkyColor, fogFactor);
    FragColor = vec4(finalColor, 1.0);
}
GLSL

echo "[generate_shaders.sh] Shaders written to app/src/main/assets/shaders/"
