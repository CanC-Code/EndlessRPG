#version 310 es
precision highp float;
in vec3 vNormal;
in vec3 vWorldPos;
in float vHeightTaper;
uniform vec3 u_CameraPos;
out vec4 FragColor;

void main() {
    vec3 lightDir = normalize(vec3(0.5, 0.8, 0.2));
    vec3 viewDir = normalize(u_CameraPos - vWorldPos);
    
    // Albedo
    vec3 baseColor = mix(vec3(0.05, 0.15, 0.02), vec3(0.3, 0.5, 0.1), vHeightTaper);
    
    // Lighting
    float diff = max(dot(vNormal, lightDir), 0.2);
    
    [span_6](start_span)[span_7](start_span)// SUBSURFACE SCATTERING: Light passing through the blade[span_6](end_span)[span_7](end_span)
    float sss = pow(max(dot(viewDir, -lightDir), 0.0), 3.0) * 0.6;
    
    vec3 finalColor = baseColor * diff + (vec3(0.6, 0.8, 0.3) * sss * vHeightTaper);
    FragColor = vec4(finalColor, 1.0);
}
