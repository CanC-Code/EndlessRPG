#version 310 es
precision highp float;

in vec3 v_WorldPos;
out vec4 FragColor;

uniform vec3 u_CameraPos;

void main() {
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    vec3 grassColor = vec3(0.2, 0.45, 0.1); // Rich, realistic dark green

    // Atmospheric Fog
    float dist = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.0035, 2.0));

    FragColor = vec4(mix(skyColor, grassColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
