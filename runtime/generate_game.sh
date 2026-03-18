#!/bin/bash
echo "Generating 3D Assets and Hardware-Safe Engine..."

# 1. Blender Modeler
cat << 'EOF' > runtime/build_models.py
import bpy
from math import radians
def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
def export_part(name, build_func):
    clean()
    build_func()
    obj = bpy.context.object
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)
    v, c = [], []
    mesh = obj.data
    mesh.calc_loop_triangles()
    for tri in mesh.loop_triangles:
        for loop_idx in tri.loops:
            vert = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            v.extend([vert.co.x, vert.co.z, -vert.co.y])
            lum = 0.5 + (vert.normal.z * 0.4)
            c.extend([lum, lum, lum, 1.0])
    return v, c

def build_hero():
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0,0,1))
    bpy.context.object.scale = (0.3, 0.2, 0.5)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.25, location=(0,0,1.8))
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0,-0.2,1.2))
    bpy.context.object.scale = (0.3, 0.05, 0.6)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()

def build_arm():
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0.5, 0, 1.2))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=1.2, location=(0.5, 0.2, 1.2))
    bpy.context.object.rotation_euler = (radians(90), 0, 0)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()

v_hero, c_hero = export_part("HERO", build_hero)
v_arm, c_arm = export_part("ARM", build_arm)

with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    f.write(f"const float M_HERO[] = {{ {', '.join(map(str, v_hero))} }};\n")
    f.write(f"const float C_HERO[] = {{ {', '.join(map(str, c_hero))} }};\n")
    f.write(f"const int N_HERO = {len(v_hero)//3};\n")
    f.write(f"const float M_ARM[] = {{ {', '.join(map(str, v_arm))} }};\n")
    f.write(f"const float C_ARM[] = {{ {', '.join(map(str, c_arm))} }};\n")
    f.write(f"const int N_ARM = {len(v_arm)//3};\n")
EOF
blender --background --python runtime/build_models.py

# 2. CMakeLists.txt
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
find_library(log-lib log)
find_library(gles3-lib GLESv3)
target_link_libraries(procedural_engine ${log-lib} ${gles3-lib})
EOF

# 3. C++ Engine (Math fault safety)
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include "GeneratedModels.h"

const char* vS = "#version 300 es\nlayout(location=0) in vec3 p; layout(location=1) in vec4 ca; uniform mat4 m; uniform vec4 bc; out vec4 vCol; void main(){ gl_Position=m*vec4(p,1.0); vCol=bc*ca; }";
const char* fS = "#version 300 es\nprecision mediump float; in vec4 vCol; out vec4 o; void main(){ o=vCol; }";

GLuint prog, heroVAO, armVAO, groundVAO;
float px=0, pz=0, anim=0, walk=0, lastFace=0;
// Volatile to prevent tearing crashes across UI and GL threads
volatile bool slash=false, block=false;

float noise(float x, float z) { return (sin(x * 0.2f) * cos(z * 0.2f)) * 0.5f; }

GLuint setupVAO(const float* v, const float* c, int n) {
    GLuint vao, vbo[2];
    glGenVertexArrays(1, &vao);
    glGenBuffers(2, vbo);
    glBindVertexArray(vao);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, n * 12, v, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(0);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, n * 16, c, GL_STATIC_DRAW);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(1);
    
    glBindVertexArray(0);
    return vao;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        GLuint vs=glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs,1,&vS,0); glCompileShader(vs);
        GLuint fs=glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs,1,&fS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog);
        glUseProgram(prog); 
        glEnable(GL_DEPTH_TEST);
        
        heroVAO = setupVAO(M_HERO, C_HERO, N_HERO);
        armVAO = setupVAO(M_ARM, C_ARM, N_ARM);
        
        float g[] = { -100,0,-100, 100,0,-100, -100,0,100, 100,0,-100, 100,0,100, -100,0,100 };
        float gc[] = { 1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1 };
        groundVAO = setupVAO(g, gc, 6);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) { glViewport(0,0,w,h); }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy) {
        bool moving = (fabs(ix) > 0.05f || fabs(iy) > 0.05f);
        if(!block && moving) { px += ix*0.15f; pz -= iy*0.15f; walk += 0.2f; }
        if(slash) { anim += 0.3f; if(anim > 3.14f){ slash=false; anim=0; } }

        glClearColor(0.5f, 0.8f, 1.0f, 1.0f); glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        GLint mL = glGetUniformLocation(prog, "m"), cL = glGetUniformLocation(prog, "bc");

        float matG[16] = { 1,0,0,0, 0,1,0,0, 0,0,1,0, -px, -1.0f, -pz-12.0f, 5.0f };
        glUniformMatrix4fv(mL, 1, GL_FALSE, matG); glUniform4f(cL, 0.2f, 0.5f, 0.2f, 1.0f);
        glBindVertexArray(groundVAO); glDrawArrays(GL_TRIANGLES, 0, 6);

        // Safely calculate rotation only when moving to avoid divide-by-zero crashes
        if(moving) lastFace = atan2(-ix, -iy);
        float s = sin(lastFace), c = cos(lastFace);
        
        float matH[16] = { c,0,s,0, 0,1,0,0, -s,0,c,0, 0, sin(walk)*0.1f, -12.0f, 5.0f };
        glUniformMatrix4fv(mL, 1, GL_FALSE, matH); glUniform4f(cL, 0.1f, 0.3f, 0.8f, 1.0f);
        glBindVertexArray(heroVAO); glDrawArrays(GL_TRIANGLES, 0, N_HERO);

        float matA[16] = { c,0,s,0, 0,1,0,0, -s,0,c,0, 0, sin(walk)*0.1f + (slash?-sin(anim)*0.5f:0), -12.0f, 5.0f };
        glUniformMatrix4fv(mL, 1, GL_FALSE, matA); glUniform4f(cL, 0.7f, 0.7f, 0.7f, 1.0f);
        glBindVertexArray(armVAO); glDrawArrays(GL_TRIANGLES, 0, N_ARM);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) slash=true; else if(id==2) block=true; else block=false;
    }
}
EOF
