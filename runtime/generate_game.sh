#!/bin/bash
echo "Generating High-Fidelity 3D Content & Overworld Engine..."

# 1. FIX BLENDER SCRIPT: Real Character Model & Fixed Attribute Error
cat << 'EOF' > runtime/build_models.py
import bpy
from math import radians

def clean_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def export_mesh(obj, name, apply_bevel=False):
    bpy.context.view_layer.objects.active = obj
    if apply_bevel:
        bpy.ops.object.modifier_add(type='BEVEL')
        obj.modifiers["Bevel"].width = 0.05
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)
    
    verts = []
    colors = []
    mesh = obj.data
    mesh.calc_loop_triangles()
    
    for tri in mesh.loop_triangles:
        for loop_index in tri.loops:
            loop = mesh.loops[loop_index]
            v = mesh.vertices[loop.vertex_index]
            # FIXED: Corrected v.y to v.co.y
            verts.extend([v.co.x, v.co.z, -v.co.y])
            # Directional shading bake
            lum = 0.5 + (v.normal.z * 0.4) + (v.normal.x * 0.1)
            colors.extend([lum, lum, lum, 1.0])
    return verts, colors

clean_scene()

# --- MODEL: HERO CORE (Body, Head, Cape) ---
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.2))
torso = bpy.context.object
torso.scale = (0.3, 0.2, 0.5)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.9))
head = bpy.context.object
head.scale = (0.25, 0.25, 0.25)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.25, 1.2))
cape = bpy.context.object
cape.scale = (0.28, 0.05, 0.6)
cape.rotation_euler[0] = radians(-10)

bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = torso
bpy.ops.object.join()
body_v, body_c = export_mesh(torso, "BODY", True)

clean_scene()
# --- MODEL: HERO SWORD ---
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.3))
arm = bpy.context.object
arm.scale = (0.1, 0.1, 0.4)
bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=1.2, location=(0, 0.2, 0.2))
blade = bpy.context.object
blade.rotation_euler[0] = radians(90)

bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = arm
bpy.ops.object.join()
arm_v, arm_c = export_mesh(arm, "ARM")

clean_scene()
# --- MODEL: WORLD OBJECTS (Trees/Rocks) ---
bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=1.5, location=(0, 0, 0.75))
trunk = bpy.context.object
trunk_v, trunk_c = export_mesh(trunk, "TRUNK")
clean_scene()
bpy.ops.mesh.primitive_cone_add(radius1=1.2, depth=2.5, location=(0, 0, 2.0))
leaves = bpy.context.object
leaves_v, leaves_c = export_mesh(leaves, "LEAVES")
clean_scene()
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.6, location=(0, 0, 0.3))
rock = bpy.context.object
rock_v, rock_c = export_mesh(rock, "ROCK", True)

# EXPORT TO HEADER
with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    data = [("BODY", body_v, body_c), ("ARM", arm_v, arm_c), ("TRUNK", trunk_v, trunk_c), ("LEAVES", leaves_v, leaves_c), ("ROCK", rock_v, rock_c)]
    for n, v, c in data:
        f.write(f"const float M_{n}[] = {{ {', '.join(map(str, v))} }};\n")
        f.write(f"const float C_{n}[] = {{ {', '.join(map(str, c))} }};\n")
        f.write(f"const int N_{n} = {len(v)//3};\n")
EOF

# Run Blender
blender --background --python runtime/build_models.py

# 2. FIX CMAKE: Ensure the file exists for the compiler
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
find_library(log-lib log)
find_library(gles3-lib GLESv3)
target_link_libraries(procedural_engine ${log-lib} ${gles3-lib})
EOF

# 3. ENHANCED ENGINE: Procedural World Implementation
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <vector>
#include <map>
#include "GeneratedModels.h"

const char* vS = "#version 300 es\nlayout(location=0) in vec3 p; layout(location=1) in vec4 ca; uniform mat4 m; uniform vec4 bc; out vec4 vCol; void main(){ gl_Position=m*vec4(p,1.0); vCol=bc*ca; }";
const char* fS = "#version 300 es\nprecision mediump float; in vec4 vCol; out vec4 o; void main(){ o=vCol; }";

GLuint prog;
float px=0, pz=0, anim=0, walk=0;
bool slash=false, block=false;

// Simple Noise for Infinite Terrain
float noise(float x, float z) {
    return (sin(x * 0.2f) * cos(z * 0.2f)) + (sin(x * 0.5f) * 0.5f);
}

void draw(GLint mL, GLint cL, const float* v, const float* c, int n, float x, float y, float z, float r, float g, float b, float ry=0, float rx=0) {
    float sy = sin(ry), cy = cos(ry), sx = sin(rx), cx = cos(rx);
    float mat[16] = { cy, sx*sy, cx*sy, 0,  0, cx, -sx, 0,  -sy, sx*cy, cx*cy, 0,  x-px, y-1.5f-noise(px,pz), z-pz-12.0f, 5.0f };
    glUniformMatrix4fv(mL, 1, GL_FALSE, mat);
    glUniform4f(cL, r, g, b, 1.0f);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, v);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 0, c);
    glEnableVertexAttribArray(1);
    glDrawArrays(GL_TRIANGLES, 0, n);
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        GLuint vs=glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs,1,&vS,0); glCompileShader(vs);
        GLuint fs=glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs,1,&fS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog);
        glUseProgram(prog); glEnable(GL_DEPTH_TEST);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) { glViewport(0,0,w,h); }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy) {
        if(!block) { px += ix*0.18f; pz -= iy*0.18f; walk += 0.2f; }
        if(slash) { anim += 0.3f; if(anim > 3.14f){ slash=false; anim=0; } }

        glClearColor(0.5f, 0.8f, 1.0f, 1.0f); glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        GLint mL = glGetUniformLocation(prog, "m"), cL = glGetUniformLocation(prog, "bc");

        // --- DRAW PROCEDURAL WORLD ---
        for(int i=-2; i<=2; i++) {
            for(int j=-2; j<=2; j++) {
                float wx = floor(px/10.0f)*10.0f + i*10.0f;
                float wz = floor(pz/10.0f)*10.0f + j*10.0f;
                float h = noise(wx, wz);
                
                // Ground Grid
                float g[] = { wx,h,wz, wx+10,h,wz, wx,h,wz+10, wx+10,h,wz, wx+10,h,wz+10, wx,h,wz+10 };
                float col[] = {1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1};
                draw(mL, cL, g, col, 6, 0, 0, 0, 0.2f, 0.6f, 0.2f);

                // Scatter Props
                if(fmod(wx*1.2f + wz*0.7f, 5.0f) > 4.0f) {
                    draw(mL, cL, M_TRUNK, C_TRUNK, N_TRUNK, wx, h, wz, 0.4f, 0.2f, 0.1f);
                    draw(mL, cL, M_LEAVES, C_LEAVES, N_LEAVES, wx, h, wz, 0.1f, 0.5f, 0.1f);
                }
            }
        }

        // --- DRAW HERO ---
        float bob = sin(walk)*0.05f;
        float face = atan2(-ix, -iy);
        draw(mL, cL, M_BODY, C_BODY, N_BODY, px, noise(px,pz)+bob, pz, 0.2f, 0.4f, 0.9f, face);
        draw(mL, cL, M_ARM, C_ARM, N_ARM, px, noise(px,pz)+bob, pz, 0.8f, 0.8f, 0.8f, face, slash?-sin(anim)*2.5f:0);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) slash=true; else if(id==2) block=true; else block=false;
    }
}
EOF
