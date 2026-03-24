#version 310 es
precision mediump float;

in float v_Height;
out vec4 FragColor;

void main() {
    // Deep earthy green at the root → vivid lime-green at the tip
    vec3 colorRoot = vec3(0.03, 0.14, 0.02);
    vec3 colorMid  = vec3(0.18, 0.48, 0.08);
    vec3 colorTip  = vec3(0.45, 0.76, 0.18);

    // Two-step gradient: root→mid over lower half, mid→tip over upper half
    vec3 finalColor;
    if (v_Height < 0.5) {
        finalColor = mix(colorRoot, colorMid, v_Height * 2.0);
    } else {
        finalColor = mix(colorMid, colorTip, (v_Height - 0.5) * 2.0);
    }

    // Subtle ambient-occlusion darkening toward the base
    float ao = 0.6 + 0.4 * v_Height;
    finalColor *= ao;

    FragColor = vec4(finalColor, 1.0);
}
