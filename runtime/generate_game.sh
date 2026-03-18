#!/bin/bash
echo "Generating 3D Game Content & Engine..."

# 1. Native UI Assets
mkdir -p app/src/main/res/drawable
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

# 2. Blender 3D Procedural Modeler
cat << 'EOF' > runtime/build_models.py
import bpy

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def export_to_header(obj_dict, filename):
    with open(filename, "w") as f:
        f.write("#pragma once\n")
        for name, obj in obj_dict.items():
            mesh = obj.data
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_add(type='TRIANGULATE')
            bpy.ops.object.modifier_apply(modifier="TRIANGULATE")
            verts = []
            for face in mesh.polygons:
                for v_idx in face.vertices:
                    v = mesh.vertices[v_idx].co
                    verts.extend([v.x, v.z, -v.y]) # Swap axes for OpenGL
            f.write(f"const float MESH_{name}[] = {"{ " + ", ".join(map(lambda x: f"{x:.4f}f", verts)) + " };"}\n")
            f.write(f"const int COUNT_{name} = {len(verts)//3};\n")

clear_scene()

# Model 1: Hero Torso
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.4, depth=1.0, location=(0,0,0.5))
torso = bpy.context.object

# Model 2: Hero Sword Arm
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.6, 0, 0.8))
arm = bpy.context.object
arm.scale = (0.1, 0.1, 0.7)

# Model 3: Hero Shield
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.5, depth=0.1, location=(-0.5, 0.3, 0.5))
shield = bpy.context.object
shield.rotation_euler[0] = 1.57 # Stand upright

# Model 4 & 5: Environment Trees
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.8, depth=2.0, location=(0,0,1.5))
tree_top = bpy.context.object
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.2, depth=1.0, location=(0,0,0.5))
tree_trunk = bpy.context.object

export_to_header({
    "TORSO": torso, "ARM": arm, "SHIELD": shield,
    "TREE_TOP": tree_top, "TREE_TRUNK": tree_trunk
}, "app/src/main/cpp/GeneratedModels.h")
EOF

blender --background --python runtime/build_models.py

# 3. The C++ Engine (Rendering & Logic)
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <vector>
#include "GeneratedModels.h"

// Vertex Shader with built-in perspective projection
const char* vS = "#version 300 es\n"
"layout(location=0) in vec3 p;\n"
"uniform mat4 uRot;\n"
"uniform vec3 uPos;\n"
"void main() {\n"
"  vec4 pos = uRot * vec4(p, 1.0) + vec4(uPos, 0.0);\n"
"  float zDist = -pos.z;\n"
"  gl_Position = vec4(pos.x, pos.y, pos.z, zDist * 0.5);\n"
"}";

// Basic Fragment Shader
const char* fS = "#version 300 es\n"
"precision mediump float; out vec4 o; uniform vec4 c; void main(){o=c;}";

GLuint prog;
float pX=0, pZ=0, animSlash = 0;
bool isSlashing = false, isShielding = false;

// Scatter environment props
struct Prop { float x, z; };
std::vector<Prop> trees = { {5, 5}, {-8, 12}, {10, -6}, {-4, -10}, {15, 2} };

void drawMesh(GLint rL, GLint pL, GLint cL, const float* v, int count, float x, float y, float z, float r, float g, float b, float rotY=0) {
    float s = sin(rotY), c = cos(rotY);
    float rotMat[16] = { c,0,-s,0, 0,1,0,0, s,0,c,0, 0,0,0,1 };
    
    glUniformMatrix4fv(rL, 1, GL_FALSE, rotMat);
    glUniform3f(pL, x - pX, y - 1.5f, z - pZ - 12.0f); // Offset by Player position and push Camera back
    glUniform4f(cL, r, g, b, 1.0f);
    
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, v);
    glEnableVertexAttribArray(0);
    glDrawArrays(GL_TRIANGLES, 0, count);
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
        // Player Movement (Disabled while blocking)
        if(!isShielding) { pX += ix * 0.2f; pZ -= iy * 0.2f; }

        // Animation updates
        if(isSlashing) { 
            animSlash += 0.3f; 
            if(animSlash > 3.14f){ isSlashing = false; animSlash = 0; } 
        }

        glClearColor(0.4f, 0.7f, 1.0f, 1.0f); 
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        GLint rL = glGetUniformLocation(prog, "uRot"), pL = glGetUniformLocation(prog, "uPos"), cL = glGetUniformLocation(prog, "c");
        
        // 1. Scene Ground Plane
        float ground[] = { -100,0,-100, 100,0,-100, -100,0,100, 100,0,-100, 100,0,100, -100,0,100 };
        drawMesh(rL, pL, cL, ground, 6, 0, 0, 0, 0.2f, 0.6f, 0.2f); 

        // 2. Scene Environment (Trees)
        for(auto& t : trees) {
            drawMesh(rL, pL, cL, MESH_TREE_TRUNK, COUNT_TREE_TRUNK, t.x, 0, t.z, 0.4f, 0.2f, 0.1f);
            drawMesh(rL, pL, cL, MESH_TREE_TOP, COUNT_TREE_TOP, t.x, 1.0f, t.z, 0.1f, 0.5f, 0.1f);
        }

        // 3. Player Hero
        drawMesh(rL, pL, cL, MESH_TORSO, COUNT_TORSO, pX, 0, pZ, 0.8f, 0.2f, 0.2f);
        
        // Sword Arm 
        float armRot = isSlashing ? -sin(animSlash) * 2.0f : 0;
        drawMesh(rL, pL, cL, MESH_ARM, COUNT_ARM, pX, 0.2f, pZ, 0.7f, 0.7f, 0.9f, armRot);
        
        // Shield (Pulls closer to center when blocking)
        float sX = isShielding ? pX : pX - 0.5f;
        float sZ = isShielding ? pZ + 0.8f : pZ + 0.5f;
        drawMesh(rL, pL, cL, MESH_SHIELD, COUNT_SHIELD, sX, 0.2f, sZ, 0.4f, 0.4f, 0.8f);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id == 1 && !isShielding) isSlashing = true; 
        if(id == 2) isShielding = true;  
        if(id == 3) isShielding = false; 
    }
}
EOF
echo "Game Content Generated!"
