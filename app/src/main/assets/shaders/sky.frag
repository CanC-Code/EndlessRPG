#version 310 es
precision highp float;
in vec2 vUV;
out vec4 FragColor;
uniform vec3 uCamForward, uCamRight, uCamUp, uCamPos;
uniform float uTanHalfFovY, uAspect, uTime;

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
    for (int i = 0; i < 5; ++i) { v += a*noise(p); p *= 2.05; a *= 0.5; }
    return v;
}

void main() {
    vec2 ndc = vUV * 2.0 - 1.0;
    vec3 ray = normalize(uCamForward
                       + uCamRight * (ndc.x * uTanHalfFovY * uAspect)
                       + uCamUp    * (ndc.y * uTanHalfFovY));

    float h = clamp(ray.y, -1.0, 1.0);
    vec3 zenith  = vec3(0.28, 0.50, 0.85);
    vec3 horizon = vec3(0.72, 0.82, 0.92);
    vec3 sky = mix(horizon, zenith, pow(max(h, 0.0), 0.55));

    // Sun glow
    vec3 sunDir = normalize(vec3(0.5, 0.6, 0.3));
    float sunAmt = max(dot(ray, sunDir), 0.0);
    sky += vec3(1.0, 0.95, 0.75) * pow(sunAmt, 64.0) * 1.2;
    sky += vec3(1.0, 0.90, 0.65) * pow(sunAmt, 8.0) * 0.15;

    // Clouds projected on a virtual plane above the camera
    if (h > 0.02) {
        vec2 cp = ray.xz / max(ray.y, 0.02) * 0.35 + vec2(uTime*0.003, uTime*0.0015);
        float c = fbm(cp);
        float cover = smoothstep(0.48, 0.72, c);
        cover *= smoothstep(0.02, 0.35, ray.y);
        float light = smoothstep(0.45, 0.85, c);
        vec3 cloudCol = mix(vec3(0.72,0.75,0.80), vec3(0.98,0.98,0.99), light);
        sky = mix(sky, cloudCol, cover * 0.85);
    }
    FragColor = vec4(sky, 1.0);
}
