#!/bin/bash
echo "Generating 3D Scene and Logic..."

# 1. Blender Modeler
cat << 'EOF' > runtime/build_models.py
import bpy

def export_part(name, create_func):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    create_func()
    obj = bpy.context.object
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=obj.modifiers[0].name)
    v = []
    for face in obj.data.polygons:
        for vi in face.vertices:
            p = obj.data.vertices[vi].co
            v.extend([p.x, p.z, -p.y])
    return v

# Body, Arm, Shield
b = export_part("BODY", lambda: bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=1.0, location=(0,0,0.5)))
a = export_part("ARM", lambda: bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.6, 0, 0.8)))
s = export_part("SHIELD", lambda: bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.6, 0.2, 0.7)))

with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    for n, d in [("BODY", b), ("ARM", a), ("SHIELD", s)]:
        f.write(f"const float M_{n}[] = {{ {', '.join(map(str, d))} }};\n")
        f.write(f"const int C_{n} = {len(d)//3};\n")
EOF

blender --background --python runtime/build_models.py

# 2. CMakeLists.txt (Generation)
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
find_library(log-lib log)
find_library(gles3-lib GLESv3)
target_link_libraries(procedural_engine ${log-lib} ${gles3-lib})
EOF

# 3. C++ Action Engine
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include "GeneratedModels.h"

const char* vS = "#version 300 es\nlayout(location=0) in vec3 p; uniform mat4 m; void main(){gl_Position=m*vec4(p,1.0);}";
const char* fS = "#version 300 es\nprecision mediump float; out vec4 o; uniform vec4 c; void main(){o=c;}";

GLuint prog;
float px=0, pz=0, anim=0;
bool slash=false, block=false;

void draw(GLint mL, GLint cL, const float* v, int n, float x, float y, float z, float r, float g, float b, float ry=0) {
    float s = sin(ry), c = cos(ry);
    // Perspective Camera Matrix
    float mat[16] = { c,0,s,0, 0,1.5f,0,0, -s,0,c,0, x-px, y-1.5f, z-pz-10.0f, 5.0f };
    glUniformMatrix4fv(mL, 1, GL_FALSE, mat);
    glUniform4f(cL, r, g, b, 1.0f);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, v);
    glEnableVertexAttribArray(0);
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
        if(!block) { px += ix*0.15f; pz -= iy*0.15f; }
        if(slash) { anim += 0.2f; if(anim > 3.14f){ slash=false; anim=0; } }
        glClearColor(0.4f, 0.7f, 1.0f, 1.0f); glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        GLint mL = glGetUniformLocation(prog, "m"), cL = glGetUniformLocation(prog, "c");
        float grd[] = {-100,0,-100, 100,0,-100, -100,0,100, 100,0,-100, 100,0,100, -100,0,100};
        draw(mL, cL, grd, 6, 0, 0, 0, 0.2f, 0.5f, 0.2f);
        draw(mL, cL, M_BODY, C_BODY, px, 0, pz, 0.8f, 0.1f, 0.1f);
        draw(mL, cL, M_ARM, C_ARM, px+0.5f, 0.2f, pz, 0.7f, 0.7f, 0.7f, slash ? -sin(anim)*2.0f : 0);
        draw(mL, cL, M_SHIELD, C_SHIELD, block ? px : px-0.6f, 0.3f, pz+0.4f, 0.3f, 0.3f, 0.6f);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) slash=true; else if(id==2) block=true; else block=false;
    }
}
EOF
