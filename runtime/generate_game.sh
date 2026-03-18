#!/bin/bash
echo "Generating High-Fidelity Procedural Game Content..."

# 1. GENERATE UI ASSETS (Using Native Android XML instead of ImageMagick)
mkdir -p app/src/main/res/drawable

cat << 'EOF' > app/src/main/res/drawable/thumbstick_base.xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="#80FFFFFF"/>
    <stroke android:width="2dp" android:color="#FFFFFF"/>
</shape>
EOF

cat << 'EOF' > app/src/main/res/drawable/action_btn.xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="#AA000000"/>
    <stroke android:width="2dp" android:color="#AAAAAA"/>
</shape>
EOF

# 2. CREATE AND RUN THE BLENDER PYTHON SCRIPT (Procedural 3D Assets)
cat << 'EOF' > runtime/build_models.py
import bpy
import bmesh

# Clear default scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# Procedurally generate a Stylized Hero Model
# Body (Cylinder)
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.4, depth=1.2, location=(0, 0, 0.6))
body = bpy.context.object

# Head (Low-poly stylized icosphere)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.35, location=(0, 0, 1.5))
head = bpy.context.object

# Join meshes
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()

# Apply modifiers for high-quality triangulated geometry
bpy.ops.object.modifier_add(type='BEVEL')
bpy.context.object.modifiers["Bevel"].width = 0.05
bpy.ops.object.modifier_add(type='TRIANGULATE')
bpy.ops.object.modifier_apply(modifier="TRIANGULATE")

# Extract vertex data for C++ Engine
mesh = body.data
mesh.calc_loop_triangles()

vertices = []
normals = []

for tri in mesh.loop_triangles:
    for loop_index in tri.loops:
        loop = mesh.loops[loop_index]
        vertex = mesh.vertices[loop.vertex_index]
        
        # Scale and swap axes for OpenGL (Y up, Z depth)
        vertices.extend([vertex.co.x, vertex.co.z, -vertex.co.y])
        
        # Generate basic fake shading based on normals (creates a stylized look)
        shade = 0.5 + (vertex.normal.z * 0.5)
        normals.extend([shade, shade, shade, 1.0])

# Write out the C++ Header
with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    f.write(f"const int HERO_VERTEX_COUNT = {int(len(vertices)/3)};\n")
    f.write("const float HERO_VERTICES[] = {\n")
    f.write(", ".join(f"{v:.4f}f" for v in vertices))
    f.write("\n};\n")
    f.write("const float HERO_COLORS[] = {\n")
    f.write(", ".join(f"{c:.4f}f" for c in normals))
    f.write("\n};\n")
EOF

echo "Running Headless Blender..."
blender --background --python runtime/build_models.py

# 3. INJECT C++ ENGINE (Using the Generated Blender Models)
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <vector>
#include "GeneratedModels.h"

const char* vShader = "#version 300 es\n"
    "layout(location = 0) in vec4 vPosition; layout(location = 1) in vec4 vColor;"
    "uniform mat4 uMatrix; out vec4 fColor;"
    "void main() { gl_Position = uMatrix * vPosition; fColor = vColor; }";

const char* fShader = "#version 300 es\n"
    "precision mediump float; in vec4 fColor; out vec4 fragColor;"
    "void main() { fragColor = fColor; }";

GLuint program;
float playerX = 0.0f, playerZ = 0.0f;

void drawMesh(GLint matrixLoc, const float* verts, const float* colors, int count, float x, float y, float z) {
    float matrix[16] = {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        x - playerX, y, z - playerZ - 8.0f, 1 
    };
    glUniformMatrix4fv(matrixLoc, 1, GL_FALSE, matrix);
    
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, verts);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 0, colors);
    glEnableVertexAttribArray(1);
    glDrawArrays(GL_TRIANGLES, 0, count);
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_nativeSurfaceCreated(JNIEnv*, jobject) {
    GLuint vs = glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs, 1, &vShader, nullptr); glCompileShader(vs);
    GLuint fs = glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs, 1, &fShader, nullptr); glCompileShader(fs);
    program = glCreateProgram();
    glAttachShader(program, vs); glAttachShader(program, fs);
    glLinkProgram(program); glUseProgram(program);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE); // Optimize rendering
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_nativeSurfaceChanged(JNIEnv*, jobject, jint w, jint h) {
    glViewport(0, 0, w, h);
}

extern "C" JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_nativeDrawFrame(JNIEnv*, jobject, jfloat inputX, jfloat inputY) {
    playerX += inputX * 0.15f;
    playerZ -= inputY * 0.15f;

    // Deep Sky Blue Background
    glClearColor(0.2f, 0.4f, 0.6f, 1.0f); 
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    GLint mLoc = glGetUniformLocation(program, "uMatrix");

    // Render Ground Plane (Stylized Green)
    float ground[] = { -50, 0, -50,  50, 0, -50,  -50, 0, 50,  50, 0, 50,  -50, 0, 50,  50, 0, -50 };
    float gColors[] = { 
        0.2f,0.6f,0.2f,1.0f,  0.2f,0.6f,0.2f,1.0f,  0.2f,0.6f,0.2f,1.0f,
        0.2f,0.6f,0.2f,1.0f,  0.2f,0.6f,0.2f,1.0f,  0.2f,0.6f,0.2f,1.0f 
    };
    drawMesh(mLoc, ground, gColors, 6, 0.0f, 0.0f, 0.0f);

    // Render Procedural Hero Model generated by Blender
    drawMesh(mLoc, HERO_VERTICES, HERO_COLORS, HERO_VERTEX_COUNT, playerX, 0.0f, playerZ);
}
EOF

echo "Engine Infilled and Ready."
