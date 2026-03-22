#!/bin/bash
# File: runtime/generate_assets.sh
# Purpose: Modular, high-fidelity asset pipeline with absolute transform logic.

mkdir -p runtime/python
mkdir -p app/src/main/cpp/models

# --- MODULE 1: EXPORT UTILITIES ---
cat << 'EOF' > runtime/python/exporter.py
import bpy, bmesh, math

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def bake_and_export(name, r, g, b, build_func, outfile, is_terrain=False):
    clean()
    build_func()
    
    # Ensure hard-voxel styling
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            for poly in obj.data.polygons: poly.use_smooth = False
            
    bpy.ops.object.select_all(action='SELECT')
    if not bpy.context.selected_objects: return
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    
    # CRITICAL FIX: Apply all scale/rotation before export to prevent engine deformation
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    
    obj = bpy.context.object
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    
    verts = []
    min_z = min((v.co.z for v in mesh.vertices), default=0)
    height = max((v.co.z for v in mesh.vertices), default=1) - min_z
    mesh.calc_loop_triangles()
    
    for tri in mesh.loop_triangles:
        lum = 0.6 + (tri.normal.z * 0.4)
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            ao = 0.4 + (0.6 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            verts.extend([v.co.x, v.co.z, -v.co.y, r*lum*ao, g*lum*ao, b*lum*ao, v.co.x*0.5, v.co.y*0.5])
            
    with open(outfile, "a") as f:
        f.write(f"const float M_{name}[] = {{ {', '.join(map(str, verts))} }};\n")
        f.write(f"const int N_{name} = {len(verts)//8};\n")
EOF

# --- MODULE 2: CHARACTER BUILDER ---
cat << 'EOF' > runtime/python/builder_char.py
import bpy

def build_body():
    # Voxel-style contiguous geometry mapping
    bpy.ops.mesh.primitive_cube_add(scale=(0.3, 0.2, 0.4), location=(0,0,0.4)) # Torso
    bpy.ops.mesh.primitive_cube_add(scale=(0.1, 0.1, 0.1), location=(0,0,0.85)) # Neck
    bpy.ops.mesh.primitive_cube_add(scale=(0.15, 0.15, 0.15), location=(0.35,0,0.65)) # L-Shoulder
    bpy.ops.mesh.primitive_cube_add(scale=(0.15, 0.15, 0.15), location=(-0.35,0,0.65)) # R-Shoulder

def build_head():
    bpy.ops.mesh.primitive_cube_add(scale=(0.22, 0.22, 0.22), location=(0,0,0.1))

def build_up_limb():
    bpy.ops.mesh.primitive_cube_add(scale=(0.1, 0.1, 0.25), location=(0,0,-0.25))

def build_low_limb():
    bpy.ops.mesh.primitive_cube_add(scale=(0.08, 0.08, 0.25), location=(0,0,-0.25))
    bpy.ops.mesh.primitive_cube_add(scale=(0.12, 0.15, 0.12), location=(0,0,-0.5)) # Hand/Foot block
EOF

# --- MODULE 3: ENVIRONMENT & WEAPONS BUILDER ---
cat << 'EOF' > runtime/python/builder_env.py
import bpy, math

def build_sword():
    bpy.ops.mesh.primitive_cube_add(scale=(0.04, 0.04, 0.8), location=(0,0,0.8)) # Blade
    bpy.ops.mesh.primitive_cube_add(scale=(0.2, 0.06, 0.05), location=(0,0,0.1)) # Guard

def build_shield():
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.45, depth=0.08)
    bpy.ops.mesh.primitive_cube_add(scale=(0.15, 0.15, 0.06), location=(0,0,0.06))

def build_terrain():
    # Optimized to 16 subdivisions to prevent NDK memory crashing
    bpy.ops.mesh.primitive_grid_add(size=16, x_subdivisions=16, y_subdivisions=16)

def build_tree():
    def branch(loc, angle_x, angle_y, level, scale):
        if level == 0:
            bpy.ops.mesh.primitive_cube_add(scale=(0.6*scale, 0.6*scale, 0.6*scale), location=loc)
            return
        bpy.ops.mesh.primitive_cube_add(scale=(0.1*scale, 0.1*scale, 1.0*scale), location=loc)
        b = bpy.context.object
        b.rotation_euler = (angle_x, angle_y, 0)
        next_loc = (loc[0]+math.sin(angle_y)*scale*2, loc[1]-math.sin(angle_x)*scale*2, loc[2]+math.cos(angle_x)*scale*2)
        branch(next_loc, angle_x+0.5, angle_y+0.4, level-1, scale*0.7)
        branch(next_loc, angle_x-0.4, angle_y-0.5, level-1, scale*0.7)
    branch((0,0,1.0), 0, 0, 3, 1.0)
EOF

# --- MODULE 4: MAIN EXECUTION ---
cat << 'EOF' > runtime/python/main_bake.py
import sys
sys.path.append('runtime/python')
from exporter import bake_and_export
from builder_char import *
from builder_env import *

with open("app/src/main/cpp/models/AllModels.h", "w") as f: 
    f.write("#pragma once\n")

bake_and_export("TORSO", 0.6, 0.65, 0.7, build_body, "app/src/main/cpp/models/AllModels.h")
bake_and_export("HEAD", 0.85, 0.7, 0.6, build_head, "app/src/main/cpp/models/AllModels.h")
bake_and_export("UP_LIMB", 0.45, 0.45, 0.5, build_up_limb, "app/src/main/cpp/models/AllModels.h")
bake_and_export("LOW_LIMB", 0.45, 0.45, 0.5, build_low_limb, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SWORD", 0.8, 0.8, 0.9, build_sword, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SHIELD", 0.3, 0.2, 0.15, build_shield, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TREE", 0.15, 0.35, 0.1, build_tree, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TERRAIN", 0.2, 0.6, 0.2, build_terrain, "app/src/main/cpp/models/AllModels.h", True)
EOF

blender --background --python runtime/python/main_bake.py
