#version 310 es
precision highp float;
in vec3 Normal;
in vec3 FragPos;
out vec4 FragColor;
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
    float patch = fbm(FragPos.xz * 0.10);
    float mid   = fbm(FragPos.xz * 0.50);
    float fine  = noise(FragPos.xz * 3.0);
    float slope = 1.0 - clamp(normalize(Normal).y, 0.0, 1.0);
    FragColor = vec4(patch, mid, fine, 1.0);
    // R = patch (large scale), G = mid (medium), B = fine (small)
    // If all three are black or all white: noise broken
    // If R shows large patches: patch works
    // If slope matters: uncomment below and use FragColor = vec4(vec3(slope), 1.0);
}
