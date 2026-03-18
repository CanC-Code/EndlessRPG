#!/bin/bash
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

cat << 'EOF' > runtime/build_models.py
import bpy
import bmesh
from math import radians

def clean_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def triangulate_and_export(obj, name, apply_bevel=False):
    bpy.context.view_layer.objects.active = obj
    if apply_bevel:
        bpy.ops.object.modifier_add(type='BEVEL')
        obj.modifiers["Bevel"].width = 0.05
        obj.modifiers["Bevel"].segments = 2
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier="TRIANGULATE")
    
    verts = []
    colors = []
    
    mesh = obj.data
    mesh.calc_loop_triangles()
    
    for tri in mesh.loop_triangles:
        for loop_index in tri.loops:
            loop = mesh.loops[loop_index]
            v = mesh.vertices[loop.vertex_index]
            # Convert to OpenGL coordinate system (X, Z, -Y)
            verts.extend([v.co.x, v.co.z, -v.y])
            
            # Simple directional lighting bake based on normals
            intensity = 0.4 + (v.normal.z * 0.4) + (v.normal.x * 0.2)
            intensity = max(0.2, min(1.0, intensity))
            colors.extend([intensity, intensity, intensity, 1.0])
            
    return verts, colors

clean_scene()

# --- HERO CORE (Head, Torso, Legs, Cape) ---
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.2))
torso = bpy.context.object
torso.scale = (0.35, 0.2, 0.5)
bpy.ops.object.transform_apply(scale=True)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.95))
head = bpy.context.object
head.scale = (0.25, 0.25, 0.25)
bpy.ops.object.transform_apply(scale=True)

bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.8, location=(-0.15, 0, 0.4))
leg_l = bpy.context.object
bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.8, location=(0.15, 0, 0.4))
leg_r = bpy.context.object

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.25, 1.2))
cape = bpy.context.object
cape.scale = (0.3, 0.05, 0.6)
cape.rotation_euler[0] = radians(-15)
bpy.ops.object.transform_apply(scale=True)

# Join Hero Core
bpy.ops.object.select_all(action='DESELECT')
for obj in [torso, head, leg_l, leg_r, cape]:
    obj.select_set(True)
bpy.context.view_layer.objects.active = torso
bpy.ops.object.join()
body_v, body_c = triangulate_and_export(torso, "BODY", True)

clean_scene()

# --- HERO SWORD ARM ---
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.3))
arm = bpy.context.object
arm.scale = (0.1, 0.1, 0.3)
bpy.ops.object.transform_apply(scale=True)

bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=1.2, location=(0, 0.3, -0.4))
blade = bpy.context.object
blade.rotation_euler[0] = radians(90)
bpy.ops.object.transform_apply(rotation=True)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.05, -0.4))
guard = bpy.context.object
guard.scale = (0.3, 0.05, 0.05)
bpy.ops.object.transform_apply(scale=True)

bpy.ops.object.select_all(action='DESELECT')
for obj in [arm, blade, guard]:
    obj.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.join()
# Offset arm to pivot at shoulder
arm.location = (0.45, 0, 1.5) 
arm_v, arm_c = triangulate_and_export(arm, "ARM", False)

clean_scene()

# --- HERO SHIELD ARM ---
bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=0.1, location=(0, 0, 0))
shield = bpy.context.object
shield.rotation_euler[1] = radians(90)
bpy.ops.object.transform_apply(rotation=True)
shield.location = (-0.45, 0.2, 1.2)
shield_v, shield_c = triangulate_and_export(shield, "SHIELD", True)

clean_scene()

# --- ENVIRONMENT SCATTER OBJECTS ---
bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=1.5, location=(0, 0, 0.75))
trunk = bpy.context.object
trunk_v, trunk_c = triangulate_and_export(trunk, "TRUNK")

clean_scene()
bpy.ops.mesh.primitive_cone_add(radius1=1.2, depth=2.5, location=(0, 0, 2.0))
leaves = bpy.context.object
leaves_v, leaves_c = triangulate_and_export(leaves, "LEAVES")

clean_scene()
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.6, location=(0, 0, 0.2))
rock = bpy.context.object
rock.scale = (1.0, 0.8, 0.5)
bpy.ops.object.transform_apply(scale=True)
rock_v, rock_c = triangulate_and_export(rock, "ROCK", True)

# --- EXPORT TO C++ HEADER ---
with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    models = [
        ("BODY", body_v, body_c), 
        ("ARM", arm_v, arm_c), 
        ("SHIELD", shield_v, shield_c),
        ("TRUNK", trunk_v, trunk_c),
        ("LEAVES", leaves_v, leaves_c),
        ("ROCK", rock_v, rock_c)
    ]
    for name, v, c in models:
        f.write(f"const float M_{name}[] = {{ {', '.join(map(lambda x: f'{x:.4f}f', v))} }};\n")
        f.write(f"const float C_{name}[] = {{ {', '.join(map(lambda x: f'{x:.4f}f', c))} }};\n")
        f.write(f"const int COUNT_{name} = {len(v)//3};\n")
EOF

blender --background --python runtime/build_models.py

cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <vector>
#include <map>
#include "GeneratedModels.h"



const char* vS = R"glsl(
#version 300 es
layout(location=0) in vec3 p;
layout(location=1) in vec4 colAttr;
uniform mat4 uMatrix;
uniform vec4 uBaseColor;
out vec4 vColor;
void main() {
    gl_Position = uMatrix * vec4(p, 1.0);
    // Combine base color with the baked directional light intensity
    vColor = uBaseColor * colAttr; 
}
)glsl";

const char* fS = R"glsl(
#version 300 es
precision mediump float; 
in vec4 vColor;
out vec4 fragColor; 
void main() { 
    fragColor = vColor; 
}
)glsl";

GLuint prog;
float px = 0.0f, pz = 0.0f, anim = 0.0f, walkAnim = 0.0f;
bool isSlash = false, isBlock = false;

// Procedural Noise function for infinite terrain height mapping
float hash(float n) {
    return fract(sin(n) * 43758.5453123f);
}

float noise(vec2 x) {
    vec2 p = vec2(floor(x.x), floor(x.y));
    vec2 f = vec2(fract(x.x), fract(x.y));
    f = vec2(f.x*f.x*(3.0f-2.0f*f.x), f.y*f.y*(3.0f-2.0f*f.y));
    float n = p.x + p.y * 57.0f;
    return mix(mix(hash(n+0.0f), hash(n+1.0f), f.x),
               mix(hash(n+57.0f), hash(n+58.0f), f.x), f.y);
}

float getTerrainHeight(float x, float z) {
    vec2 pos = vec2(x * 0.1f, z * 0.1f);
    float h = noise(pos) * 2.0f;
    h += noise(vec2(pos.x * 2.0f, pos.y * 2.0f)) * 0.5f;
    return h;
}

struct Chunk {
    int cx, cz;
    std::vector<float> verts;
    std::vector<float> colors;
    std::vector<vec3> trees;
    std::vector<vec3> rocks;
};

std::map<std::pair<int, int>, Chunk> chunkCache;
const int CHUNK_SIZE = 16;
const int RENDER_DIST = 2;

struct vec3 { float x, y, z; };

void generateChunk(int cx, int cz) {
    Chunk chunk;
    chunk.cx = cx; chunk.cz = cz;
    
    float startX = cx * CHUNK_SIZE;
    float startZ = cz * CHUNK_SIZE;
    
    for (int z = 0; z < CHUNK_SIZE; z++) {
        for (int x = 0; x < CHUNK_SIZE; x++) {
            float wx = startX + x;
            float wz = startZ + z;
            
            float hBL = getTerrainHeight(wx, wz);
            float hBR = getTerrainHeight(wx + 1, wz);
            float hTL = getTerrainHeight(wx, wz + 1);
            float hTR = getTerrainHeight(wx + 1, wz + 1);
            
            // T1
            chunk.verts.insert(chunk.verts.end(), {wx, hBL, wz, wx+1, hBR, wz, wx, hTL, wz+1});
            // T2
            chunk.verts.insert(chunk.verts.end(), {wx+1, hBR, wz, wx+1, hTR, wz+1, wx, hTL, wz+1});
            
            // Procedural terrain coloring based on height
            for (int i = 0; i < 6; i++) {
                float h = (i < 3) ? ((i==0)?hBL:(i==1)?hBR:hTL) : ((i==0)?hBR:(i==1)?hTR:hTL);
                float r=0.2f, g=0.5f, b=0.2f; // Grass
                if (h > 1.8f) { r=0.5f; g=0.5f; b=0.5f; } // Rock
                if (h > 2.2f) { r=0.9f; g=0.9f; b=0.9f; } // Snow
                if (h < 0.2f) { r=0.8f; g=0.7f; b=0.4f; } // Sand
                
                // Add fake AO / shading
                float shade = 0.7f + (hash(wx * 10.0f + wz) * 0.3f);
                chunk.colors.insert(chunk.colors.end(), {r*shade, g*shade, b*shade, 1.0f});
            }
            
            // Scatter decorators
            float rnd = hash(wx * 7.0f + wz * 13.0f);
            if (h > 0.3f && h < 1.7f) {
                if (rnd > 0.95f) chunk.trees.push_back({wx, hBL, wz});
                else if (rnd < 0.02f) chunk.rocks.push_back({wx, hBL, wz});
            }
        }
    }
    chunkCache[{cx, cz}] = chunk;
}



void drawMesh(GLint mL, GLint cL, const float* v, const float* c, int n, float x, float y, float z, float r, float g, float b, float rotY=0, float rotX=0) {
    float sy = sin(rotY), cy = cos(rotY);
    float sx = sin(rotX), cx = cos(rotX);
    
    // Y Rotation
    float mRotY[16] = { cy,0,sy,0, 0,1,0,0, -sy,0,cy,0, 0,0,0,1 };
    // X Rotation
    float mRotX[16] = { 1,0,0,0, 0,cx,-sx,0, 0,sx,cx,0, 0,0,0,1 };
    
    // Perspective Camera setup tracking player
    float mat[16] = { 1,0,0,0, 0,1.3f,0,0, 0,0,1,0, x-px, y-1.5f - getTerrainHeight(px, pz), z-pz-12.0f, 4.0f };
    
    // Combine matrices (simplified manual mul for transformation)
    float finalMat[16];
    for(int i=0; i<4; i++) {
        for(int j=0; j<4; j++) {
            finalMat[i*4+j] = 0;
            for(int k=0; k<4; k++) finalMat[i*4+j] += mat[k*4+j] * mRotY[i*4+k];
        }
    }
    
    glUniformMatrix4fv(mL, 1, GL_FALSE, finalMat);
    glUniform4f(cL, r, g, b, 1.0f);
    
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, v);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 0, c);
    glEnableVertexAttribArray(1);
    glDrawArrays(GL_TRIANGLES, 0, n);
}

void drawDynamicMesh(GLint mL, GLint cL, const std::vector<float>& v, const std::vector<float>& c) {
    float mat[16] = { 1,0,0,0, 0,1.3f,0,0, 0,0,1,0, -px, -1.5f - getTerrainHeight(px, pz), -pz-12.0f, 4.0f };
    glUniformMatrix4fv(mL, 1, GL_FALSE, mat);
    glUniform4f(cL, 1.0f, 1.0f, 1.0f, 1.0f); // White base, uses vertex colors
    
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, v.data());
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 0, c.data());
    glEnableVertexAttribArray(1);
    glDrawArrays(GL_TRIANGLES, 0, v.size() / 3);
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        GLuint vs=glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs,1,&vS,0); glCompileShader(vs);
        GLuint fs=glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs,1,&fS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog);
        glUseProgram(prog); 
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_CULL_FACE);
        glCullFace(GL_BACK);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) { 
        glViewport(0,0,w,h); 
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy) {
        bool moving = false;
        if(!isBlock && (fabs(ix) > 0.01f || fabs(iy) > 0.01f)) { 
            px += ix*0.2f; pz -= iy*0.2f; 
            moving = true;
        }
        
        if (moving) walkAnim += 0.3f;
        else walkAnim = 0.0f;
        
        if(isSlash) { anim += 0.3f; if(anim > 3.14f){ isSlash=false; anim=0; } }

        glClearColor(0.5f, 0.75f, 1.0f, 1.0f); // Sky color
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        GLint mL = glGetUniformLocation(prog, "uMatrix"), cL = glGetUniformLocation(prog, "uBaseColor");

        // Render Chunks
        int ccx = (int)floor(px / CHUNK_SIZE);
        int ccz = (int)floor(pz / CHUNK_SIZE);
        
        for (int z = -RENDER_DIST; z <= RENDER_DIST; z++) {
            for (int x = -RENDER_DIST; x <= RENDER_DIST; x++) {
                int mapX = ccx + x;
                int mapZ = ccz + z;
                if (chunkCache.find({mapX, mapZ}) == chunkCache.end()) {
                    generateChunk(mapX, mapZ);
                }
                
                Chunk& c = chunkCache[{mapX, mapZ}];
                drawDynamicMesh(mL, cL, c.verts, c.colors);
                
                for(auto& t : c.trees) {
                    drawMesh(mL, cL, M_TRUNK, C_TRUNK, COUNT_TRUNK, t.x, t.y, t.z, 0.3f, 0.2f, 0.1f);
                    drawMesh(mL, cL, M_LEAVES, C_LEAVES, COUNT_LEAVES, t.x, t.y, t.z, 0.2f, 0.6f, 0.2f);
                }
                for(auto& r : c.rocks) {
                    drawMesh(mL, cL, M_ROCK, C_ROCK, COUNT_ROCK, r.x, r.y, r.z, 0.6f, 0.6f, 0.6f);
                }
            }
        }

        // Draw Real Character Model
        float bobbing = sin(walkAnim) * 0.1f;
        float heroY = getTerrainHeight(px, pz) + bobbing;
        
        // Character facing direction
        float facing = atan2(-ix, -iy);
        if (!moving) facing = 0.0f; // retain last facing in full engine, reset for simplicity
        
        // Body (Blue Tunic)
        drawMesh(mL, cL, M_BODY, C_BODY, COUNT_BODY, px, heroY, pz, 0.1f, 0.3f, 0.8f, facing);
        
        // Sword Arm (Steel/Flesh)
        float armRotX = isSlash ? -sin(anim)*2.5f : (sin(walkAnim)*0.5f);
        drawMesh(mL, cL, M_ARM, C_ARM, COUNT_ARM, px, heroY, pz, 0.8f, 0.8f, 0.8f, facing, armRotX);
        
        // Shield Arm (Wood/Iron)
        float shieldZ = isBlock ? pz + 0.5f : pz;
        float shieldY = isBlock ? heroY + 0.3f : heroY;
        float shieldRot = isBlock ? 0.5f : (-sin(walkAnim)*0.5f);
        drawMesh(mL, cL, M_SHIELD, C_SHIELD, COUNT_SHIELD, px, shieldY, shieldZ, 0.5f, 0.3f, 0.2f, facing, shieldRot);
    }
    
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) isSlash=true; else if(id==2) isBlock=true; else isBlock=false;
    }
}
EOF
