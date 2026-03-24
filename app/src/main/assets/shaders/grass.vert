#version 310 es
precision highp float;

layout(location = 0) in vec3 a_Pos;

struct Blade { 
    vec4 pos; 
    vec4 wind; 
};

layout(std430, binding = 0) buffer B { 
    Blade blades[]; 
};

uniform mat4 u_ViewProjection;

out float v_Height;
out float v_Type; // NEW: We will pass the plant species to the Fragment Shader next!

// Creates a matrix to rotate the grass blade around its vertical Y-axis
mat3 rotationY(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return mat3(
        c, 0.0, s,
        0.0, 1.0, 0.0,
        -s, 0.0, c
    );
}

void main() {
    Blade b = blades[gl_InstanceID];
    vec3 bladePos = b.pos.xyz;
    float bladeHeight = b.pos.w;
    
    vec2 windDir = b.wind.xy;
    float rotAngle = b.wind.z;
    float windStrength = b.wind.w;

    // Use the unique rotation angle as a random seed to determine the plant species
    float typeHash = fract(rotAngle * 43.123);

    vec3 localPos = a_Pos;
    
    // =======================================================
    // --- PROCEDURAL GEOMETRY MORPHING (PRAIRIE BIODIVERSITY)
    // =======================================================
    float stiffness = 1.0;

    if (typeHash < 0.15) {
        // SPECIES 1: Tall Wheat / Seed Stalks (15% of the field)
        localPos.y *= 1.7; // Grow much taller than normal grass
        if (a_Pos.y < 0.8) {
            localPos.x *= 0.2; // Pinch the base into a thin, rigid stalk
        } else {
            localPos.x *= 3.0; // Bulge the top into a heavy wheat/seed head
        }
        stiffness = 0.2; // Woody stalks resist the wind much more
    } 
    else if (typeHash < 0.30) {
        // SPECIES 2: Dead / Dry Broken Stems (15% of the field)
        localPos.y *= 0.6; // Broken off or naturally short
        localPos.x *= 0.4; // Thin and shriveled
        stiffness = 0.6; // Stiff and dry
    } 
    else {
        // SPECIES 3: Prairie Sod Grass Blades (70% of the field)
        // Standard shape, but varying slightly in width for realism
        localPos.x *= (0.8 + typeHash);
        stiffness = 1.0 + (typeHash * 0.5); // Natural flex variation
    }

    // Apply the overall procedural height scale from the compute shader
    localPos.y *= bladeHeight;
    
    // Rotate the plant locally so the field looks densely interwoven
    localPos = rotationY(rotAngle) * localPos;

    // --- ADVANCED WIND PHYSICS ---
    float heightPercent = a_Pos.y; 
    
    // The higher up the blade, the harder the wind pushes it (factoring in species stiffness)
    float bendFactor = pow(heightPercent, 2.0) * windStrength * stiffness; 
    
    localPos.x += windDir.x * bendFactor;
    localPos.z += windDir.y * bendFactor;
    
    // Structural physics: As the plant bends forward, it loses vertical height
    localPos.y -= bendFactor * 0.25;

    // Shift the calculated local geometry into its final world position
    vec3 worldPos = localPos + bladePos;

    // Pass data to the Fragment Shader
    v_Height = a_Pos.y; 
    v_Type = typeHash; // Send the species ID down the pipeline
    
    gl_Position = u_ViewProjection * vec4(worldPos, 1.0);
}
