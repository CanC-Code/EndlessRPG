#version 310 es
precision highp float;

in vec3 Normal;
in vec3 FragPos;
out vec4 FragColor;

uniform vec3 uCameraPos;
uniform vec3 uFogColor;

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
               mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; ++i) { v += a*noise(p); p *= 2.05; a *= 0.5; }
    return v;
}

void main() {
    vec3 n = normalize(Normal);
    float slope = 1.0 - clamp(n.y, 0.0, 1.0);

    float patch = fbm(FragPos.xz * 0.10);
    float mid   = fbm(FragPos.xz * 0.50);
    float fine  = noise(FragPos.xz * 3.0);

    float rockMask  = smoothstep(0.35, 0.65, slope + (patch - 0.5) * 0.30);
    float dirtSlope = smoothstep(0.12, 0.32, slope);
    float dirtPatch = smoothstep(0.60, 0.78, patch);
    float dirtMask  = max(dirtSlope, dirtPatch);

    vec3 richGrass = vec3(0.06, 0.16, 0.05);
    vec3 dryGrass  = vec3(0.32, 0.28, 0.12);
    vec3 dirtCol   = vec3(0.30, 0.19, 0.10);
    vec3 rockCol   = vec3(0.42, 0.41, 0.38);

    float dryBlend = smoothstep(0.45, 0.70, mid);
    vec3 grassCol = mix(richGrass, dryGrass, dryBlend);
    grassCol *= (0.85 + 0.30 * fine);

    vec3 col = grassCol;
    col = mix(col, dirtCol, dirtMask);
    col = mix(col, rockCol, rockMask);

    vec3 L = normalize(vec3(0.5, 1.0, 0.3));
    float diff = max(dot(n, L), 0.0);
    col *= (0.55 + diff * 0.75);

    float dist = length(FragPos - uCameraPos);
    float fog = clamp((dist - 60.0) / 180.0, 0.0, 1.0);
    fog = fog * fog;
    col = mix(col, uFogColor, fog);

    FragColor = vec4(col, 1.0);
}
