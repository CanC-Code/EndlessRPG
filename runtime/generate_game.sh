#!/bin/bash
echo "Generating Optimized 3D Assets & Overworld Engine..."

# 1. Blender Modeler (Fixed Coordinate Access)
cat << 'EOF' > runtime/build_models.py
import bpy
from math import radians

def clean_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def export_vdata(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)
    verts, colors = [], []
    mesh = obj.data
    mesh.calc_loop_triangles()
    for tri in mesh.loop_triangles:
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            # FIXED: Corrected attribute access to v.co.y
            verts.extend([v.co.x, v.co.z, -v.co.y])
            lum = 0.5 + (v.normal.z * 0.4) + (v.normal.x * 0.1)
            colors.extend([lum, lum, lum, 1.0])
    return verts, colors

clean_scene()
# Hero Model
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0,0,1.2))
torso = bpy.context.object; torso.scale = (0.3, 0.2, 0.5)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.25, location=(0,0,1.9))
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0,-0.25,1.3))
cape = bpy.context.object; cape.scale = (0.3, 0.05, 0.6); cape.rotation_euler[0] = radians(-10)
bpy.ops.object.select_all(action='SELECT'); bpy.context.view_layer.objects.active = torso; bpy.ops.object.join()
hero_v, hero_c = export_vdata(torso)

clean_scene()
# Weapon Model
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0,0,0.3))
arm = bpy.context.object; arm.scale = (0.08, 0.08, 0.4)
bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=1.1, location=(0,0.2,0.2))
bpy.ops.object.select_all(action='SELECT'); bpy.context.view_layer.objects.active = arm; bpy.ops.object.join()
arm_v, arm_c = export_vdata(arm)

with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    for n, v, c in [("HERO", hero_v, hero_c), ("ARM", arm_v, arm_c)]:
        f.write(f"const float M_{n}[] = {{ {', '.join(map(str, v))} }};\n")
        f.write(f"const float C_{n}[] = {{ {', '.join(map(str, c))} }};\n")
        f.write(f"const int N_{n} = {len(v)//3};\n")
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

# 3. Optimized C++ Engine (VBO-based rendering)
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <vector>
#include "GeneratedModels.h"

const char* vS = "#version 300 es\nlayout(location=0) in vec3 p; layout(location=1) in vec4 ca; uniform mat4 m; uniform vec4 bc; out vec4 vCol; void main(){ gl_Position=m*vec4(p,1.0); vCol=bc*ca; }";
const char* fS = "#version 300 es\nprecision mediump float; in vec4 vCol; out vec4 o; void main(){ o=vCol; }";

GLuint prog, heroVBO, heroCBO, armVBO, armCBO, groundVBO;
float px=0, pz=0, anim=0, walk=0;
bool slash=false, block=false;

float noise(float x, float z) { return (sin(x * 0.15f) * cos(z * 0.15f)) + (sin(x * 0.4f) * 0.3f); }

GLuint createVBO(const float* data, int size) {
    GLuint vbo; glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size, data, GL_STATIC_DRAW);
    return vbo;
}

void drawMesh(GLint mL, GLint cL, GLuint vbo, GLuint cbo, int n, float x, float y, float z, float r, float g, float b, float ry=0, float rx=0) {
    float sy=sin(ry), cy=cos(ry), sx=sin(rx), cx=cos(rx);
    float mat[16] = { cy, sx*sy, cx*sy, 0,  0, cx, -sx, 0,  -sy, sx*cy, cx*cy, 0,  x-px, y-1.5f-noise(px,pz), z-pz-12.0f, 5.0f };
    glUniformMatrix4fv(mL, 1, GL_FALSE, mat); glUniform4f(cL, r, g, b, 1.0f);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo); glVertexAttribPointer(0,3,GL_FLOAT,0,0,0); glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, cbo); glVertexAttribPointer(1,4,GL_FLOAT,0,0,0); glEnableVertexAttribArray(1);
    glDrawArrays(GL_TRIANGLES, 0, n);
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        GLuint vs=glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs,1,&vS,0); glCompileShader(vs);
        GLuint fs=glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs,1,&fS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog);
        glUseProgram(prog); glEnable(GL_DEPTH_TEST);
        
        heroVBO = createVBO(M_HERO, sizeof(M_HERO)); heroCBO = createVBO(C_HERO, sizeof(C_HERO));
        armVBO = createVBO(M_ARM, sizeof(M_ARM)); armCBO = createVBO(C_ARM, sizeof(C_ARM));
        
        float g[] = { -100,0,-100, 100,0,-100, -100,0,100, 100,0,-100, 100,0,100, -100,0,100 };
        groundVBO = createVBO(g, sizeof(g));
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) { glViewport(0,0,w,h); }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy) {
        if(!block) { px += ix*0.18f; pz -= iy*0.18f; if(fabs(ix)>0.01) walk += 0.2f; }
        if(slash) { anim += 0.3f; if(anim > 3.14f){ slash=false; anim=0; } }

        glClearColor(0.4f, 0.7f, 1.0f, 1.0f); glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        GLint mL = glGetUniformLocation(prog, "m"), cL = glGetUniformLocation(prog, "bc");

        // Ground (Static Green Plane for stability)
        float matG[16] = { 1,0,0,0, 0,1.5f,0,0, 0,0,1,0, -px, -1.5f-noise(px,pz), -pz-12.0f, 5.0f };
        glUniformMatrix4fv(mL, 1, GL_FALSE, matG); glUniform4f(cL, 0.2f, 0.6f, 0.2f, 1.0f);
        glBindBuffer(GL_ARRAY_BUFFER, groundVBO); glVertexAttribPointer(0,3,GL_FLOAT,0,0,0); glEnableVertexAttribArray(0);
        glDisableVertexAttribArray(1); glVertexAttrib4f(1, 1, 1, 1, 1);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        float bob = sin(walk)*0.05f, face = atan2(-ix, -iy);
        drawMesh(mL, cL, heroVBO, heroCBO, N_HERO, px, noise(px,pz)+bob, pz, 0.2f, 0.3f, 0.8f, face);
        drawMesh(mL, cL, armVBO, armCBO, N_ARM, px, noise(px,pz)+bob, pz, 0.8f, 0.8f, 0.8f, face, slash?-sin(anim)*2.5f:0);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) slash=true; else if(id==2) block=true; else block=false;
    }
}
EOF
