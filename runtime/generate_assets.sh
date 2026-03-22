#!/bin/bash
# File: runtime/generate_assets.sh
# Purpose: HD Asset generation with Smooth Normals and fixed origin points.

mkdir -p runtime/python
mkdir -p app/src/main/cpp/models

cat << 'EOF' > runtime/python/exporter.py
import bpy, bmesh

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def bake_and_export(name, r, g, b, build_func, outfile):
    clean()
    build_func()
    
    # Enable Smooth Shading for HD realism
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            for poly in obj.data.polygons: poly.use_smooth = True
            
    bpy.ops.object.select_all(action='SELECT')
    objs = bpy.context.selected_objects
    if not objs: return
        
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    
    # Absolute zeroing of origins to prevent engine rotation drift
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    
    obj = bpy.context.object; mesh = obj.data
    bm = bmesh.new(); bm.from_mesh(mesh); bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(mesh); bm.free()
    
    verts = []
    mesh.calc_loop_triangles()
    mesh.calc_normals_split() # Calculate smooth high-res normals
    
    for tri in mesh.loop_triangles:
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            n = v.normal # Extract the smooth normal
            
            # Format: X, Y, Z,   NX, NY, NZ,   R, G, B,   U, V (11 Floats = 44 bytes stride)
            verts.extend([
                v.co.x, v.co.z, -v.co.y, 
                n.x, n.z, -n.y, 
                r, g, b, 
                v.co.x * 0.5, v.co.y * 0.5
            ])
            
    with open(outfile, "a") as f:
        f.write(f"const float M_{name}[] = {{ {', '.join(map(str, verts))} }};\n")
        f.write(f"const int N_{name} = {len(verts)//11};\n")
EOF

cat << 'EOF' > runtime/python/builder_char.py
import bpy
def build_body():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.6, location=(0,0,0.3))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.15, location=(0,0,0.65))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(0.32,0,0.55)) 
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(-0.32,0,0.55)) 
def build_head(): bpy.ops.mesh.primitive_uv_sphere_add(radius=0.2, location=(0,0,0.1))
def build_up_limb(): 
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.35, location=(0,0,-0.175))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(0,0,-0.35))
def build_low_limb():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=0.35, location=(0,0,-0.175))
    bpy.ops.mesh.primitive_cube_add(scale=(0.1, 0.12, 0.08), location=(0,0,-0.35))
EOF

cat << 'EOF' > runtime/python/builder_env.py
import bpy, math, random

def build_sword():
    # Build entirely on the positive Z axis so origin (0,0,0) is exactly at the grip
    bpy.ops.mesh.primitive_cylinder_add(radius=0.02, depth=0.2, location=(0,0,-0.1))
    bpy.ops.mesh.primitive_cube_add(scale=(0.2, 0.04, 0.04), location=(0,0,0.05))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=1.0, location=(0,0,0.55))

def build_shield():
    # Build facing positive Y, strapped perfectly
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.45, depth=0.05, location=(0,0,0))
    bpy.ops.transform.rotate(value=1.5708, orient_axis='X')
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(0,0.05,0)) 

def build_rock():
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.4)
    bpy.context.object.scale = (random.uniform(0.8, 1.2), random.uniform(0.6, 1.0), random.uniform(0.4, 0.8))

def build_grass():
    for i in range(4):
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.03, depth=0.6, location=(0,0,0.3))
        bpy.ops.transform.rotate(value=random.uniform(-0.4, 0.4), orient_axis='X')
        bpy.ops.transform.rotate(value=random.uniform(-0.4, 0.4), orient_axis='Y')
        bpy.ops.transform.rotate(value=i * 1.57, orient_axis='Z')

def build_wheat():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.015, depth=1.0, location=(0,0,0.5))
    for i in range(6):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.04, location=(0, 0, 0.7 + (i*0.05)))
        bpy.context.object.scale = (1.0, 1.0, 1.5)

def build_terrain(): bpy.ops.mesh.primitive_grid_add(size=16, x_subdivisions=24, y_subdivisions=24)

def build_tree():
    random.seed(42)
    def branch(loc, angle_x, angle_y, level, scale):
        if level == 0:
            bpy.ops.mesh.primitive_ico_sphere_add(radius=1.2*scale, subdivisions=2, location=loc)
            return
        bpy.ops.mesh.primitive_cone_add(radius1=0.15*scale, radius2=0.08*scale, depth=2.0*scale, location=loc)
        b = bpy.context.object; b.rotation_euler = (angle_x, angle_y, 0)
        next_loc = (loc[0]+math.sin(angle_y)*scale*1.8, loc[1]-math.sin(angle_x)*scale*1.8, loc[2]+math.cos(angle_x)*math.cos(angle_y)*scale*1.8)
        branch(next_loc, angle_x + random.uniform(0.2, 0.6), angle_y + random.uniform(0.2, 0.5), level-1, scale*0.7)
        branch(next_loc, angle_x - random.uniform(0.2, 0.6), angle_y - random.uniform(0.2, 0.5), level-1, scale*0.7)
    branch((0,0,1.0), 0, 0, 4, 1.0) 
EOF

cat << 'EOF' > runtime/python/main_bake.py
import sys
sys.path.append('runtime/python')
from exporter import bake_and_export
from builder_char import *
from builder_env import *

with open("app/src/main/cpp/models/AllModels.h", "w") as f: f.write("#pragma once\n")

bake_and_export("TORSO", 0.7, 0.7, 0.75, build_body, "app/src/main/cpp/models/AllModels.h")
bake_and_export("HEAD", 0.9, 0.8, 0.7, build_head, "app/src/main/cpp/models/AllModels.h")
bake_and_export("UP_LIMB", 0.5, 0.5, 0.55, build_up_limb, "app/src/main/cpp/models/AllModels.h")
bake_and_export("LOW_LIMB", 0.5, 0.5, 0.55, build_low_limb, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SWORD", 0.8, 0.85, 0.9, build_sword, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SHIELD", 0.4, 0.3, 0.2, build_shield, "app/src/main/cpp/models/AllModels.h")
bake_and_export("ROCK", 0.55, 0.55, 0.6, build_rock, "app/src/main/cpp/models/AllModels.h")
bake_and_export("GRASS", 0.2, 0.6, 0.2, build_grass, "app/src/main/cpp/models/AllModels.h")
bake_and_export("WHEAT", 0.8, 0.7, 0.3, build_wheat, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TREE", 0.15, 0.4, 0.15, build_tree, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TERRAIN", 0.25, 0.55, 0.25, build_terrain, "app/src/main/cpp/models/AllModels.h")
EOF

blender --background --python runtime/python/main_bake.py
