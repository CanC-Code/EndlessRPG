#version 310 es
precision mediump float;

// These MUST match the 'out' variables from terrain.vert
in vec2 TexCoord;
in vec3 Normal;
in vec3 FragPos;

out vec4 FragColor;

// A default directional light source
const vec3 lightDir = normalize(vec3(0.5, 1.0, 0.3));
const vec3 lightColor = vec3(1.0, 0.95, 0.9);

void main() {
    // Base green ground color
    vec3 objectColor = vec3(0.15, 0.45, 0.15); 
    
    // Ambient light
    float ambientStrength = 0.4;
    vec3 ambient = ambientStrength * lightColor;
    
    // Diffuse light
    vec3 norm = normalize(Normal);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * lightColor;
    
    vec3 result = (ambient + diffuse) * objectColor;
    FragColor = vec4(result, 1.0);
}
