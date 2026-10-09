#version 310 es
precision mediump float;

in vec3 Normal;
in vec3 FragPos;
out vec4 FragColor;

uniform vec3 uCameraPos;
uniform vec3 uFogColor;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453123); }
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

    float patch = fbm(FragPos.xz * 0.35);
    float fine  = noise(FragPos.xz * 3.0);

    float rockMask = smoothstep(0.35, 0.60, slope);
    float dirtMask = max(smoothstep(0.15, 0.35, slope),
                         smoothstep(0.60, 0.80, patch) * smoothstep(0.4, 0.7, fine));

    vec3 grassCol = vec3(0.10, 0.22, 0.08) * (0.75 + 0.50 * noise(FragPos.xz * 6.0));
    vec3 dirtCol  = vec3(0.30, 0.20, 0.12);
    vec3 rockCol  = vec3(0.42, 0.41, 0.38);

    vec3 col = mix(grassCol, dirtCol, dirtMask);
    col = mix(col, rockCol, rockMask);

    // directional light
    vec3 L = normalize(vec3(0.5, 1.0, 0.3));
    float diff = max(dot(n, L), 0.0);
    col *= (0.55 + diff * 0.75);

    // linear fog: nothing under 40m, complete at 260m
    float dist = length(FragPos - uCameraPos);
    float fog = clamp((dist - 40.0) / 220.0, 0.0, 1.0);
    fog = fog * fog;   // ease-in so nearby stays crisp
    col = mix(col, uFogColor, fog);

    FragColor = vec4(col, 1.0);
}
