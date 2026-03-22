#!/bin/bash
# File: runtime/generate_assets.sh
# Purpose: Exact Anatomical Pivots, High-Fidelity Geometry, and Noise-Textured Terrain.

echo "Generating High-Fidelity Skeletal Models and Terrain Textures..."

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
            
            norm = v.normal
            lum = 0.5 + (norm.z * 0.4) + (norm.x * 0.1)
            ao = 0.6 + (0.4 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            
            # Procedural Terrain Texture Variance
            if is_terrain:
                # Use sine waves to simulate distinct dirt and grass patches on the vertex level
                noise = math.sin(v.co.x * 2.0) * math.cos(v.co.y * 2.0)
                if noise > 0.3: # Dirt patches
                    verts.extend([0.45*lum*ao, 0.35*lum*ao, 0.2*lum*ao])
                elif noise < -0.3: # Lush grass
                    verts.extend([0.2*lum*ao, 0.6*lum*ao, 0.2*lum*ao])
                else: # Base ground
                    verts.extend([r*lum*ao, g*lum*ao, b*lum*ao])
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

# CORRECTED PIVOTS: Limbs extend deeply downwards from (0,0,0) to swing naturally
def build_torso():
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.25, depth=0.7, location=(0,0,0.35))
    # Add belt details
    bpy.ops.mesh.primitive_torus_add(major_radius=0.26, minor_radius=0.03, location=(0,0,0.1))

def build_head():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=24, radius=0.2, location=(0,0,0.15))

def build_upper_limb(): # Pivots at top, ends at elbow/knee
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.1, depth=0.4, location=(0,0,-0.2))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.12, location=(0,0,0)) # Shoulder Joint

def build_lower_limb(): # Pivots at elbow/knee, ends at hand/foot
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.08, depth=0.4, location=(0,0,-0.2))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.1, location=(0,0,0)) # Elbow Joint
    # Foot/Hand bulge
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, radius=0.11, location=(0,0,-0.4)) 

def build_sword():
    # Pommel
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.07, location=(0,0,-0.15))
    # Grip
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.03, depth=0.3, location=(0,0,0))
    # Elegant Crossguard
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.04, depth=0.4, location=(0,0,0.15))
    bpy.context.object.rotation_euler = (0, 1.57, 0)
    # Long Tapered Blade
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.08, radius2=0.01, depth=1.6, location=(0,0,0.95))
    bpy.context.object.scale = (1.0, 0.2, 1.0)
    bpy.context.object.rotation_euler = (0, 0, 0.785)

def build_shield():
    # Kite Shield (Detailed)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.4, depth=0.08, location=(0,0,0))
    bpy.context.object.scale = (1.0, 1.5, 1.0)
    # Iron Boss in center
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.15, location=(0,0,0.04))
    bpy.context.object.scale = (1.0, 1.0, 0.5)

def build_tree():
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.2, depth=2.0, location=(0,0,1.0))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.4, location=(0,0,2.5))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0, location=(0,0,3.5))

def build_terrain():
    # Massive 16x16 grid for high-fidelity terrain bending in C++
    bpy.ops.mesh.primitive_grid_add(size=16, x_subdivisions=32, y_subdivisions=32)

with open("app/src/main/cpp/models/AllModels.h", "w") as f: f.write("#pragma once\n")
bake_and_export("TORSO", 0.7, 0.75, 0.8, build_torso, "app/src/main/cpp/models/AllModels.h") # Silver Plate
bake_and_export("HEAD", 0.9, 0.7, 0.6, build_head, "app/src/main/cpp/models/AllModels.h") # Skin Tone
bake_and_export("UP_LIMB", 0.6, 0.65, 0.7, build_upper_limb, "app/src/main/cpp/models/AllModels.h") # Darker Mail
bake_and_export("LOW_LIMB", 0.6, 0.65, 0.7, build_lower_limb, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SWORD", 0.9, 0.95, 1.0, build_sword, "app/src/main/cpp/models/AllModels.h") # Steel
bake_and_export("SHIELD", 0.3, 0.2, 0.1, build_shield, "app/src/main/cpp/models/AllModels.h") # Wood
bake_and_export("TREE", 0.15, 0.45, 0.15, build_tree, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TERRAIN", 0.25, 0.5, 0.2, build_terrain, "app/src/main/cpp/models/AllModels.h", True)
EOF

blender --background --python runtime/python/gen_models.py
