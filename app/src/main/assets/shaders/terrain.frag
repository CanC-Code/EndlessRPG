#version 310 es
precision highp float;
in vec3 vWorldPos;
in vec3 vNormal;
uniform vec3 u_CameraPos;
out vec4 FragColor;

void main() {
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.2));
    float diff = max(dot(vNormal, lightDir), 0.15);
    
    vec3 color = mix(vec3(0.1, 0.08, 0.05), vec3(0.15, 0.2, 0.05), vNormal.y);
    color *= diff;

    // Atmospheric Fog
    float dist = length(vWorldPos - u_CameraPos);
    float fog = exp(-pow(dist * 0.005, 2.0));
    FragColor = vec4(mix(vec4(0.5, 0.6, 0.7, 1.0).rgb, color, fog), 1.0);
}
