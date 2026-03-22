#!/bin/bash
# File: runtime/generate_assets.sh
# Purpose: Modular high-fidelity asset generation with absolute transforms to prevent engine deformation.

mkdir -p runtime/python
mkdir -p app/src/main/cpp/models

# MODULE 1: The Exporter
cat << 'EOF' > runtime/python/exporter.py
import bpy, bmesh

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def bake_and_export(name, r, g, b, build_func, outfile, is_terrain=False):
    clean()
    build_func()
    
    # Smooth shading for realistic models
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            for poly in obj.data.polygons: 
                poly.use_smooth = True
            
    bpy.ops.object.select_all(action='SELECT')
    objs = bpy.context.selected_objects
    if not objs: return
        
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    
    # CRITICAL: Apply scale so the engine's animation matrices don't skew the models
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    
    obj = bpy.context.object
    mesh = obj.data
    
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    
    verts = []
    mesh.calc_loop_triangles()
    min_z = min((v.co.z for v in mesh.vertices), default=0)
    height = max((v.co.z for v in mesh.vertices), default=1) - min_z
    
    for tri in mesh.loop_triangles:
        lum = 0.5 + max(0.0, tri.normal.z * 0.5) + max(0.0, tri.normal.x * 0.2)
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            ao = 0.5 + (0.5 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            # X, Y, Z, R, G, B, U, V
            verts.extend([v.co.x, v.co.z, -v.co.y, r*lum*ao, g*lum*ao, b*lum*ao, v.co.x*0.5, v.co.y*0.5])
            
    with open(outfile, "a") as f:
        f.write(f"const float M_{name}[] = {{ {', '.join(map(str, verts))} }};\n")
        f.write(f"const int N_{name} = {len(verts)//8};\n")
EOF

# MODULE 2: The Character Builder (Realistic Anatomy)
cat << 'EOF' > runtime/python/builder_char.py
import bpy

def build_body():
    # Integrated Torso and Anatomy (No floating parts)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.6, location=(0,0,0.3))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.15, location=(0,0,0.65)) # Neck
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(0.32,0,0.55)) # L-Shoulder
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(-0.32,0,0.55)) # R-Shoulder

def build_head(): 
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.2, location=(0,0,0.1))

def build_up_limb(): 
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.35, location=(0,0,-0.175))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(0,0,-0.35)) # Elbow/Knee Joint

def build_low_limb():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=0.35, location=(0,0,-0.175))
    bpy.ops.mesh.primitive_cube_add(scale=(0.1, 0.12, 0.08), location=(0,0,-0.35)) # Hand/Foot
EOF

# MODULE 3: Environment & Realistic Trees
cat << 'EOF' > runtime/python/builder_env.py
import bpy, math

def build_sword():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=1.0, location=(0,0,0.5))
    bpy.ops.mesh.primitive_cube_add(scale=(0.2, 0.04, 0.04), location=(0,0,0.1)) # Guard

def build_shield():
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.45, depth=0.05)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(0,0,0.03)) # Shield Boss

def build_terrain():
    bpy.ops.mesh.primitive_grid_add(size=16, x_subdivisions=24, y_subdivisions=24)

def build_tree():
    def branch(loc, angle_x, angle_y, level, scale):
        if level == 0:
            # Needles / Leaves
            bpy.ops.mesh.primitive_ico_sphere_add(radius=0.8*scale, subdivisions=2, location=loc)
            return
        
        # Branch
        bpy.ops.mesh.primitive_cylinder_add(radius=0.1*scale, depth=2.0*scale, location=loc)
        b = bpy.context.object
        b.rotation_euler = (angle_x, angle_y, 0)
        
        next_loc = (loc[0]+math.sin(angle_y)*scale, loc[1]-math.sin(angle_x)*scale, loc[2]+math.cos(angle_x)*math.cos(angle_y)*scale)
        branch(next_loc, angle_x+0.5, angle_y+0.4, level-1, scale*0.7)
        branch(next_loc, angle_x-0.4, angle_y-0.5, level-1, scale*0.7)
        
    branch((0,0,1.0), 0, 0, 3, 1.0)
EOF

# MODULE 4: Main Execution
cat << 'EOF' > runtime/python/main_bake.py
import sys
sys.path.append('runtime/python')
from exporter import bake_and_export
from builder_char import *
from builder_env import *

with open("app/src/main/cpp/models/AllModels.h", "w") as f: 
    f.write("#pragma once\n")

bake_and_export("TORSO", 0.7, 0.7, 0.75, build_body, "app/src/main/cpp/models/AllModels.h")
bake_and_export("HEAD", 0.9, 0.8, 0.7, build_head, "app/src/main/cpp/models/AllModels.h")
bake_and_export("UP_LIMB", 0.5, 0.5, 0.55, build_up_limb, "app/src/main/cpp/models/AllModels.h")
bake_and_export("LOW_LIMB", 0.5, 0.5, 0.55, build_low_limb, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SWORD", 0.8, 0.85, 0.9, build_sword, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SHIELD", 0.4, 0.3, 0.2, build_shield, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TREE", 0.15, 0.4, 0.15, build_tree, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TERRAIN", 1.0, 1.0, 1.0, build_terrain, "app/src/main/cpp/models/AllModels.h", True)
EOF

blender --background --python runtime/python/main_bake.py
