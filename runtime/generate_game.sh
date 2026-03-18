#!/bin/bash
echo "Generating Animated 3D Assets..."

# 1. Native UI Assets
cat << 'EOF' > app/src/main/res/drawable/thumbstick_base.xml
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="#44FFFFFF"/><stroke android:width="2dp" android:color="#FFFFFFFF"/>
</shape>
EOF
cat << 'EOF' > app/src/main/res/drawable/action_btn.xml
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="#88000000"/><stroke android:width="2dp" android:color="#CCCCCC"/>
</shape>
EOF

# 2. Blender Procedural Modeler
cat << 'EOF' > runtime/build_models.py
import bpy

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def export_to_header(obj_list, filename):
    with open(filename, "w") as f:
        f.write("#pragma once\n")
        for name, obj in obj_list.items():
            mesh = obj.data
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_add(type='TRIANGULATE')
            bpy.ops.object.modifier_apply(modifier="TRIANGULATE")
            
            verts = []
            for face in mesh.polygons:
                for v_idx in face.vertices:
                    v = mesh.vertices[v_idx].co
                    verts.extend([v.x, v.z, -v.y])
            
            f.write(f"const float MESH_{name}[] = {"{ " + ", ".join(map(lambda x: f"{x:.4f}f", verts)) + " };"}\n")
            f.write(f"const int COUNT_{name} = {len(verts)//3};\n")

clear_scene()

# Create Hero Torso
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.4, depth=1.0, location=(0,0,0.5))
torso = bpy.context.object

# Create Sword Arm (Pivot at shoulder)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.6, 0, 0.8))
arm = bpy.context.object
arm.scale = (0.15, 0.15, 0.6)

export_to_header({"TORSO": torso, "ARM": arm}, "app/src/main/cpp/GeneratedModels.h")
EOF

blender --background --python runtime/build_models.py

# 3. C++ Engine with Animation Logic
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include "GeneratedModels.h"

const char* vS = "#version 300 es\nlayout(location=0) in vec3 p; uniform mat4 m; void main(){gl_Position=m*vec4(p,1.0);}";
const char* fS = "#version 300 es\nprecision mediump float; out vec4 o; uniform vec4 c; void main(){o=c;}";

GLuint prog;
float pX=0, pZ=0, anim=0;
bool slashing=false;

void draw(GLint mLoc, GLint cLoc, const float* v, int n, float x, float y, float z, float r, float g, float b, float rot=0) {
    float s = sin(rot), c = cos(rot);
    float mat[16] = {c,0,s,0, 0,1,0,0, -s,0,c,0, x-pX,y,z-pZ-10.0f,1};
    glUniformMatrix4fv(mLoc, 1, GL_FALSE, mat);
    glUniform4f(cLoc, r, g, b, 1.0f);
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
        pX += ix*0.1f; pZ -= iy*0.1f;
        if(slashing) { anim += 0.2f; if(anim > 3.14f){ slashing=false; anim=0; } }
        glClearColor(0.2f, 0.2f, 0.3f, 1.0f); glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        GLint mL = glGetUniformLocation(prog, "m"), cL = glGetUniformLocation(prog, "c");
        
        // Draw Hero
        draw(mL, cL, MESH_TORSO, COUNT_TORSO, pX, 0, pZ, 0.8f, 0.2f, 0.2f);
        float armRot = slashing ? sin(anim) * 1.5f : 0;
        draw(mL, cL, MESH_ARM, COUNT_ARM, pX+0.5f, 0.2f, pZ, 0.7f, 0.7f, 0.9f, armRot);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id == 1) slashing = true;
    }
}
EOF
