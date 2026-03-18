#!/bin/bash
echo "Initializing High-Fidelity Procedural Asset Pipeline..."

# 1. CREATE THE BLENDER PYTHON SCRIPT
cat << 'EOF' > runtime/build_models.py
import bpy
import bmesh

# Clear default scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# Procedurally generate a Stylized Hero Model
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.4, depth=1.2, location=(0, 0, 0.6))
body = bpy.context.object

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.35, location=(0, 0, 1.5))
head = bpy.context.object

# Join meshes
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()

# Apply modifiers safely for Blender 4.0+
bpy.ops.object.modifier_add(type='BEVEL')
bpy.context.object.modifiers["Bevel"].width = 0.05
bpy.ops.object.modifier_add(type='TRIANGULATE')
bpy.ops.object.modifier_apply(modifier=bpy.context.object.modifiers[-1].name)

# Extract vertex data for C++ Engine
mesh = body.data
mesh.calc_loop_triangles()

vertices = []
colors = []

for tri in mesh.loop_triangles:
    for loop_index in tri.loops:
        loop = mesh.loops[loop_index]
        vertex = mesh.vertices[loop.vertex_index]
        
        # Scale and swap axes for OpenGL (Y up, Z depth)
        vertices.extend([vertex.co.x, vertex.co.z, -vertex.co.y])
        
        # Generate basic fake shading based on normals
        shade = 0.5 + (vertex.normal.z * 0.5)
        colors.extend([shade, shade, shade, 1.0])

# Write out the C++ Header
with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    f.write(f"const int HERO_VERTEX_COUNT = {len(vertices)//3};\n")
    f.write("const float HERO_VERTICES[] = {\n")
    f.write(", ".join(f"{v:.4f}f" for v in vertices))
    f.write("\n};\n")
    f.write("const float HERO_COLORS[] = {\n")
    f.write(", ".join(f"{c:.4f}f" for c in colors))
    f.write("\n};\n")

print("Procedural Models Exported to C++ Header.")
EOF

# 2. RUN HEADLESS BLENDER TO GENERATE ASSETS
echo "Running Headless Blender..."
blender --background --python runtime/build_models.py

# 3. INJECT C++ ENGINE

cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <vector>
#include <cmath>
#include "GeneratedModels.h"

const char* vShader = "#version 300 es\n"
    "layout(location = 0) in vec3 vPosition;\n"
    "layout(location = 1) in vec4 vColor;\n"
    "uniform mat4 uMatrix;\n"
    "out vec4 fColor;\n"
    "void main() { gl_Position = uMatrix * vec4(vPosition, 1.0); fColor = vColor; }";

const char* fShader = "#version 300 es\n"
    "precision mediump float;\n"
    "in vec4 fColor;\n"
    "out vec4 fragColor;\n"
    "void main() { fragColor = fColor; }";

GLuint program, heroVAO;
float playerX = 0.0f, playerZ = 0.0f;

// Setup GPU Memory buffers to prevent Android driver crashes
void setupHardwareBuffers() {
    GLuint vbo[2];
    glGenVertexArrays(1, &heroVAO);
    glGenBuffers(2, vbo);

    glBindVertexArray(heroVAO);

    // Vertex Buffer
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, HERO_VERTEX_COUNT * 3 * sizeof(float), HERO_VERTICES, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, nullptr);
    glEnableVertexAttribArray(0);

    // Color Buffer
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, HERO_VERTEX_COUNT * 4 * sizeof(float), HERO_COLORS, GL_STATIC_DRAW);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 0, nullptr);
    glEnableVertexAttribArray(1);

    glBindVertexArray(0);
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
    GLuint vs = glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs, 1, &vShader, nullptr); glCompileShader(vs);
    GLuint fs = glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs, 1, &fShader, nullptr); glCompileShader(fs);
    program = glCreateProgram();
    glAttachShader(program, vs); glAttachShader(program, fs);
    glLinkProgram(program); glUseProgram(program);
    
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    
    setupHardwareBuffers();
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) {
    glViewport(0, 0, w, h);
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat inputX, jfloat inputY) {
    playerX += inputX * 0.15f;
    playerZ -= inputY * 0.15f;

    glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    GLint mLoc = glGetUniformLocation(program, "uMatrix");

    // Matrix with w=4.0f to provide native perspective division
    float matrix[16] = {
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.3f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        -playerX, -1.0f, -playerZ - 10.0f, 4.0f 
    };
    
    glUniformMatrix4fv(mLoc, 1, GL_FALSE, matrix);
    
    glBindVertexArray(heroVAO);
    glDrawArrays(GL_TRIANGLES, 0, HERO_VERTEX_COUNT);
    glBindVertexArray(0);
}
EOF

echo "Asset Pipeline and Engine updated successfully."
