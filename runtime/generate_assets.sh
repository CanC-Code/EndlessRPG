#!/bin/bash
# File: runtime/generate_assets.sh
# Purpose: High-fidelity model generation. Enhances terrain texturing (grass, dirt, rock layers) and details the hands/joints for perfect item attachment.

cat << 'EOF' > runtime/python/export_utils.py
import bpy
import random
import math

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def bake_and_export(name, r, g, b, build_func, outfile, is_terrain=False):
    clean()
    build_func()
    
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            for poly in obj.data.polygons: poly.use_smooth = True
            
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)
    
    verts = []
    mesh = obj.data
    mesh.calc_loop_triangles()
    min_z = min((v.co.z for v in mesh.vertices), default=0)
    height = max((v.co.z for v in mesh.vertices), default=1) - min_z

    for tri in mesh.loop_triangles:
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            verts.extend([v.co.x, v.co.z, -v.co.y])
            
            # Baked directional sun lighting
            norm = v.normal
            sun_dir = [0.5, 0.7, 0.5] # Light coming from top-right
            dot_prod = max(0.0, (norm.x*sun_dir[0] + norm.y*sun_dir[1] + norm.z*sun_dir[2]))
            lum = 0.4 + (dot_prod * 0.6)
            ao = 0.5 + (0.5 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            
            if is_terrain:
                # ENHANCED PROCEDURAL TERRAIN TEXTURES
                # Layer 1: High frequency noise for grass clumps
                noise1 = math.sin(v.co.x * 5.0) * math.cos(v.co.y * 5.0)
                # Layer 2: Low frequency noise for dirt paths
                noise2 = math.sin(v.co.x * 0.8) * math.sin(v.co.y * 1.2)
                
                if noise2 > 0.3:
                    verts.extend([0.45*lum*ao, 0.35*lum*ao, 0.2*lum*ao]) # Dirt path
                elif noise1 > 0.2:
                    verts.extend([0.25*lum*ao, 0.65*lum*ao, 0.15*lum*ao]) # Bright grass
                else:
                    verts.extend([0.15*lum*ao, 0.55*lum*ao, 0.1*lum*ao]) # Deep grass
            else:
                verts.extend([r*lum*ao, g*lum*ao, b*lum*ao])
            
    with open(outfile, "a") as f:
        f.write(f"const float M_{name}[] = {{ {', '.join(map(str, verts))} }};\n")
        f.write(f"const int N_{name} = {len(verts)//6};\n")
EOF

cat << 'EOF' > runtime/python/gen_models.py
import bpy, sys
sys.path.append('runtime/python')
from export_utils import bake_and_export

def build_torso():
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.25, depth=0.7, location=(0,0,0.35))
    # Belt and buckle
    bpy.ops.mesh.primitive_torus_add(major_radius=0.26, minor_radius=0.04, location=(0,0,0.1))
    bpy.ops.mesh.primitive_cube_add(size=0.12, location=(0,-0.25,0.1))

def build_head():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=24, radius=0.2, location=(0,0,0.15))

def build_upper_limb(): 
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.1, depth=0.4, location=(0,0,-0.2))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.13, location=(0,0,0)) # Shoulder

def build_lower_limb(): 
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.08, depth=0.4, location=(0,0,-0.2))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.11, location=(0,0,0)) # Elbow/Knee
    # Distinct Hand/Foot block attached precisely at the -0.4 tip
    bpy.ops.mesh.primitive_cube_add(size=0.16, location=(0,0,-0.42))

def build_sword():
    # Pommel
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.07, location=(0,0,-0.2))
    # Grip
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.03, depth=0.4, location=(0,0,0))
    # Guard
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0,0,0.2))
    bpy.context.object.scale = (3.5, 0.6, 0.8)
    # Blade
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.08, radius2=0.01, depth=1.6, location=(0,0,1.0))
    bpy.context.object.scale = (1.2, 0.2, 1.0)
    bpy.context.object.rotation_euler = (0, 0, 0.785)

def build_shield():
    # Thickened Kite Shield
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.45, depth=0.1, location=(0,0,0))
    bpy.context.object.scale = (1.0, 1.4, 1.0)
    # Boss
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.15, location=(0,0,0.06))
    bpy.context.object.scale = (1.0, 1.0, 0.4)
    # Metal Trim
    bpy.ops.mesh.primitive_torus_add(major_radius=0.43, minor_radius=0.03, location=(0,0,0.02))
    bpy.context.object.scale = (1.0, 1.4, 1.0)

def build_chest():
    bpy.ops.mesh.primitive_cube_add(size=0.8, location=(0,0,0.4)) 
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.4, depth=0.8, location=(0,0,0.8)) 
    bpy.context.object.rotation_euler = (0, 1.57, 0)
    bpy.ops.mesh.primitive_cube_add(size=0.15, location=(0.4,0,0.8)) # Lock

def build_cloud():
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0,0,0))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.6, location=(1.2,0.4,0))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.3, location=(2.8,-0.2,0))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.9, location=(-1.0,-0.5,0))

def build_tree():
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.25, depth=2.5, location=(0,0,1.25))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.6, location=(0,0,2.8))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.3, location=(0.5,0.5,3.8))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.1, location=(-0.5,-0.6,4.5))

def build_terrain():
    # Higher fidelity subdivision for smooth ground peaks and valleys
    bpy.ops.mesh.primitive_grid_add(size=16, x_subdivisions=64, y_subdivisions=64)

with open("app/src/main/cpp/models/AllModels.h", "w") as f: f.write("#pragma once\n")
bake_and_export("TORSO", 0.7, 0.75, 0.8, build_torso, "app/src/main/cpp/models/AllModels.h") 
bake_and_export("HEAD", 0.9, 0.7, 0.6, build_head, "app/src/main/cpp/models/AllModels.h") 
bake_and_export("UP_LIMB", 0.5, 0.55, 0.6, build_upper_limb, "app/src/main/cpp/models/AllModels.h") 
bake_and_export("LOW_LIMB", 0.5, 0.55, 0.6, build_lower_limb, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SWORD", 0.85, 0.9, 0.95, build_sword, "app/src/main/cpp/models/AllModels.h") 
bake_and_export("SHIELD", 0.4, 0.25, 0.15, build_shield, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TREE", 0.15, 0.45, 0.15, build_tree, "app/src/main/cpp/models/AllModels.h")
bake_and_export("CHEST", 0.5, 0.35, 0.15, build_chest, "app/src/main/cpp/models/AllModels.h")
bake_and_export("CLOUD", 1.0, 1.0, 1.0, build_cloud, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TERRAIN", 0.2, 0.6, 0.2, build_terrain, "app/src/main/cpp/models/AllModels.h", True)
EOF

blender --background --python runtime/python/gen_models.py
