#!/bin/bash
echo "Generating Infinite World and Skeletal Character Engine..."

# 1. High-Fidelity Blender Modeler (Modular Humanoid & Props)
cat << 'EOF' > runtime/build_models.py
import bpy

def export(name, build_func):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    build_func()
    obj = bpy.context.object
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    for mod in obj.modifiers:
        if mod.type == 'TRIANGULATE': bpy.ops.object.modifier_apply(modifier=mod.name)
    v = []
    for face in obj.data.polygons:
        for vi in face.vertices:
            pt = obj.data.vertices[vi].co
            v.extend([pt.x, pt.z, -pt.y]) # Swap axes for OpenGL
    return v

# Humanoid Anatomy
m_head = export("HEAD", lambda: bpy.ops.mesh.primitive_ico_sphere_add(radius=0.25, subdivisions=2, location=(0,0,1.4)))
m_torso = export("TORSO", lambda: bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0,0,0.8)))
bpy.context.object.scale = (0.4, 0.25, 0.6) # Tapered chest
m_limb = export("LIMB", lambda: bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0,0,-0.3)))
bpy.context.object.scale = (0.15, 0.15, 0.4) # Pivot at shoulder/hip

# Weapons & Props
m_sword = export("SWORD", lambda: bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0,0,0.5)))
bpy.context.object.scale = (0.05, 0.1, 0.8)
m_shield = export("SHIELD", lambda: bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=0.1, location=(0,0,0)))
m_trunk = export("TRUNK", lambda: bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=1.0, location=(0,0,0.5)))
m_leaves = export("LEAVES", lambda: bpy.ops.mesh.primitive_cone_add(radius1=1.2, depth=2.5, location=(0,0,1.5)))

with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    for n, d in [("HEAD", m_head), ("TORSO", m_torso), ("LIMB", m_limb), 
                 ("SWORD", m_sword), ("SHIELD", m_shield), 
                 ("TRUNK", m_trunk), ("LEAVES", m_leaves)]:
        f.write(f"const float M_{n}[] = {{ {', '.join(map(str, d))} }};\n")
        f.write(f"const int C_{n} = {len(d)//3};\n")
EOF

blender --background --python runtime/build_models.py

# 2. Advanced C++ Engine (Procedural Terrain Shader & Animation)
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <vector>
#include "GeneratedModels.h"

// Vertex Shader: Dynamically generates hills based on absolute world coordinates
const char* vS = "#version 300 es\n"
"layout(location=0) in vec3 p;\n"
"uniform mat4 uM;\n"
"uniform vec3 uPos;\n"
"uniform int isTerrain;\n"
"out float vHeight;\n"
"void main() {\n"
"  vec3 worldPos = p + uPos;\n"
"  if(isTerrain == 1) {\n"
"    // Procedural Noise function for hills/valleys\n"
"    worldPos.y += sin(worldPos.x * 0.3) * cos(worldPos.z * 0.3) * 1.5;\n"
"    vHeight = worldPos.y;\n"
"  } else { vHeight = 0.0; }\n"
"  gl_Position = uM * vec4(worldPos, 1.0);\n"
"}";

const char* fS = "#version 300 es\n"
"precision mediump float; in float vHeight; out vec4 o; uniform vec4 c; uniform int isTerrain;\n"
"void main() {\n"
"  if(isTerrain == 1) o = vec4(c.r, c.g + (vHeight * 0.15), c.b, 1.0); // Highlight peaks\n"
"  else o = c;\n"
"}";

GLuint prog;
float px=0, pz=0, animSlash=0, animWalk=0;
bool slash=false, block=false, moving=false;

std::vector<float> grid; // The infinite terrain treadmill

void drawPart(GLint mL, GLint pL, GLint cL, GLint tL, const float* v, int n, float x, float y, float z, float r, float g, float b, float rx=0, float ry=0, int isTerrain=0) {
    float sx = sin(rx), cx = cos(rx), sy = sin(ry), cy = cos(ry);
    // Combined Rotation & Perspective Math
    float mat[16] = {
        cy, sx*sy, cx*sy, 0,
        0, cx*1.4f, -sx*1.4f, 0, // 1.4f stretches Y slightly for FOV
        -sy, sx*cy, cx*cy, 0,
        0, -1.0f, -8.0f, 4.0f   // W=4.0 creates the 3D depth perspective
    };
    glUniformMatrix4fv(mL, 1, GL_FALSE, mat);
    glUniform3f(pL, x - px, y, z - pz);
    glUniform4f(cL, r, g, b, 1.0f);
    glUniform1i(tL, isTerrain);
    
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, v);
    glEnableVertexAttribArray(0);
    glDrawArrays(GL_TRIANGLES, 0, n);
}

// Pseudo-random hash for scattering trees
float hash(float x, float z) { return fract(sin(x * 12.9898f + z * 78.233f) * 43758.5453123f); }

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        GLuint vs=glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs,1,&vS,0); glCompileShader(vs);
        GLuint fs=glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs,1,&fS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog);
        glUseProgram(prog); glEnable(GL_DEPTH_TEST); glEnable(GL_CULL_FACE);

        // Build the Terrain Grid (Treadmill around player)
        for(int z=-15; z<15; z++) {
            for(int x=-15; x<15; x++) {
                grid.insert(grid.end(), {(float)x,0,(float)z, (float)x+1,0,(float)z, (float)x,0,(float)z+1});
                grid.insert(grid.end(), {(float)x+1,0,(float)z, (float)x+1,0,(float)z+1, (float)x,0,(float)z+1});
            }
        }
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) { glViewport(0,0,w,h); }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy) {
        moving = (!block && (ix != 0 || iy != 0));
        if(moving) { px += ix*0.1f; pz -= iy*0.1f; animWalk += 0.2f; } else { animWalk = 0; }
        if(slash) { animSlash += 0.3f; if(animSlash > 3.14f){ slash=false; animSlash=0; } }

        glClearColor(0.4f, 0.7f, 1.0f, 1.0f); glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        GLint mL = glGetUniformLocation(prog, "uM"), pL = glGetUniformLocation(prog, "uPos");
        GLint cL = glGetUniformLocation(prog, "c"), tL = glGetUniformLocation(prog, "isTerrain");

        // 1. Render Infinite Terrain (Snaps to integers to hide grid movement)
        drawPart(mL, pL, cL, tL, grid.data(), grid.size()/3, floor(px), 0, floor(pz), 0.2f, 0.5f, 0.2f, 0, 0, 1);

        // 2. Render Environment (Scattered via Hash)
        int chunkX = floor(px/10.0f) * 10, chunkZ = floor(pz/10.0f) * 10;
        for(int z=-20; z<=20; z+=10) {
            for(int x=-20; x<=20; x+=10) {
                if(hash(chunkX+x, chunkZ+z) > 0.5f) { // 50% chance to spawn tree
                    float tx = chunkX+x + 5.0f, tz = chunkZ+z + 5.0f;
                    float ty = sin(tx*0.3)*cos(tz*0.3)*1.5; // Match terrain height
                    drawPart(mL, pL, cL, tL, M_TRUNK, C_TRUNK, tx, ty, tz, 0.4f, 0.2f, 0.1f);
                    drawPart(mL, pL, cL, tL, M_LEAVES, C_LEAVES, tx, ty+1.0f, tz, 0.1f, 0.4f, 0.1f);
                }
            }
        }

        // 3. Render Skeletal Humanoid Player
        float pY = sin(px*0.3)*cos(pz*0.3)*1.5; // Player stands ON the terrain
        float wR = sin(animWalk)*0.5f;          // Walk Rotation (Legs/Arms)
        float faceRot = atan2(-ix, -iy);        // Player rotation based on thumbstick
        
        // Head & Torso
        drawPart(mL, pL, cL, tL, M_HEAD, C_HEAD, px, pY, pz, 0.9f, 0.7f, 0.6f, 0, faceRot);
        drawPart(mL, pL, cL, tL, M_TORSO, C_TORSO, px, pY, pz, 0.2f, 0.3f, 0.8f, 0, faceRot);
        
        // Legs (Walking animation)
        drawPart(mL, pL, cL, tL, M_LIMB, C_LIMB, px-0.2f, pY+0.6f, pz, 0.3f, 0.3f, 0.3f, wR, faceRot); // L Leg
        drawPart(mL, pL, cL, tL, M_LIMB, C_LIMB, px+0.2f, pY+0.6f, pz, 0.3f, 0.3f, 0.3f, -wR, faceRot); // R Leg
        
        // Shield Arm (Left)
        float sX = px - 0.4f, sZ = pz;
        if(block) { sX = px; sZ = pz-0.4f; } // Move shield forward
        drawPart(mL, pL, cL, tL, M_LIMB, C_LIMB, px-0.4f, pY+1.1f, pz, 0.7f, 0.7f, 0.7f, -wR, faceRot);
        drawPart(mL, pL, cL, tL, M_SHIELD, C_SHIELD, sX, pY+0.6f, sZ, 0.4f, 0.4f, 0.8f, block ? -0.5f : 0, faceRot);

        // Sword Arm (Right)
        float aR = slash ? -sin(animSlash)*2.0f : wR; // Slash overrides walk
        drawPart(mL, pL, cL, tL, M_LIMB, C_LIMB, px+0.4f, pY+1.1f, pz, 0.7f, 0.7f, 0.7f, aR, faceRot);
        drawPart(mL, pL, cL, tL, M_SWORD, C_SWORD, px+0.4f, pY+0.5f, pz-0.4f, 0.8f, 0.8f, 0.9f, aR, faceRot);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1 && !block) slash=true; else if(id==2) block=true; else block=false;
    }
}
EOF
