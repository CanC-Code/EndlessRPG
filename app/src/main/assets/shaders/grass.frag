#version 310 es
precision highp float;

in vec3 v_WorldPos;
in float v_ColorMix;
out vec4 FragColor;

uniform vec3 u_CameraPos;

void main() {
    vec3 skyColor = vec3(0.45, 0.6, 0.8);
    
    // Photographic Realism: Grass has dark roots and bright, sunlit tips
    vec3 rootColor = vec3(0.08, 0.22, 0.05);
    vec3 tipColor = vec3(0.35, 0.65, 0.15); 
    vec3 grassColor = mix(rootColor, tipColor, v_ColorMix);

    float dist = length(v_WorldPos - u_CameraPos);
    float fogFactor = exp(-pow(dist * 0.003, 2.0));

    FragColor = vec4(mix(skyColor, grassColor, clamp(fogFactor, 0.0, 1.0)), 1.0);
}
