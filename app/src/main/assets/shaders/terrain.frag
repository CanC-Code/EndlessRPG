#version 310 es
precision mediump float;
in vec2 TexCoord;
in vec3 Normal;
in vec3 FragPos;
out vec4 FragColor;
uniform vec3 uCameraPos;
uniform vec3 uFogColor;
uniform float uFogDensity;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453123); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0-2.0*f);
    float a = hash(i);
    float b = hash(i+vec2(1.0,0.0));
    float c = hash(i+vec2(0.0,1.0));
    float d = hash(i+vec2(1.0,1.0));
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; ++i) { v += a*noise(p); p *= 2.05; a *= 0.5; }
    return v;
}

void main() {
    vec3 n = normalize(Normal);
    float slope = 1.0 - clamp(n.y, 0.0, 1.0);

    // Multi-scale noise for patch variation
    float patch = fbm(FragPos.xz * 0.35);
    float fine  = noise(FragPos.xz * 3.0);

    // Slope-based masks, softened with noise
    float rockMask = smoothstep(0.30, 0.55, slope + (patch - 0.5) * 0.20);
    float dirtSlope = smoothstep(0.10, 0.28, slope);
    float dirtPatch = smoothstep(0.55, 0.80, patch) * smoothstep(0.4, 0.6, fine);
    float dirtMask  = max(max(dirtSlope, dirtPatch), rockMask);

    // Material colors (dark, since blades provide the top layer)
    vec3 grassCol = vec3(0.09, 0.20, 0.07) * (0.85 + 0.30 * noise(FragPos.xz * 6.0));
    vec3 dirtCol  = vec3(0.30, 0.20, 0.12);
    vec3 rockCol  = vec3(0.42, 0.41, 0.38);

    vec3 col = mix(grassCol, dirtCol, dirtMask);
    col = mix(col, rockCol, rockMask);

    // Simple directional lighting
    vec3 lightDir = normalize(vec3(0.5, 1.0, 0.3));
    float diff = max(dot(n, lightDir), 0.0);
    col *= (0.45 + diff * 0.9);

    // Distance fog
    float dist = length(FragPos - uCameraPos);
    float fog = 1.0 - exp(-uFogDensity * uFogDensity * dist * dist);
    col = mix(col, uFogColor, fog);

    FragColor = vec4(col, 1.0);
}
