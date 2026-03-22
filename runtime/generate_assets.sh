#!/bin/bash
# File: runtime/generate_assets.sh
# Purpose: High-fidelity model generation with UV mapping, realistic trees, and proper anatomy.

cat << 'EOF' > runtime/python/export_utils.py
import bpy
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
    
    # Generate simple UV mapping (planar or cylindrical)
    if not mesh.uv_layers:
        mesh.uv_layers.new()
    uv_layer = mesh.uv_layers.active.data

    min_z = min((v.co.z for v in mesh.vertices), default=0)
    height = max((v.co.z for v in mesh.vertices), default=1) - min_z

    for tri in mesh.loop_triangles:
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            uv = uv_layer[loop_idx].uv
            
            # Use X/Y position for top-down UV mapping (ideal for terrain)
            u = v.co.x * 0.5
            v_coord = v.co.y * 0.5
            
            # Export format: X, Y, Z, R, G, B, U, V
            verts.extend([v.co.x, v.co.z, -v.co.y])
            
            # Lighting
            norm = v.normal
            sun_dir = [0.5, 0.7, 0.5]
            dot_prod = max(0.0, (norm.x*sun_dir[0] + norm.y*sun_dir[1] + norm.z*sun_dir[2]))
            lum = 0.4 + (dot_prod * 0.6)
            ao = 0.5 + (0.5 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            
            verts.extend([r*lum*ao, g*lum*ao, b*lum*ao, u, v_coord])
            
    with open(outfile, "a") as f:
        f.write(f"const float M_{name}[] = {{ {', '.join(map(str, verts))} }};\n")
        f.write(f"const int N_{name} = {len(verts)//8};\n")
EOF

cat << 'EOF' > runtime/python/gen_models.py
import bpy, sys, math
sys.path.append('runtime/python')
from export_utils import bake_and_export

def build_torso():
    # Core Torso
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.28, depth=0.7, location=(0,0,0.35))
    # Neck (Connecting head securely)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.1, depth=0.2, location=(0,0,0.75))
    # Shoulders joints (integrated so limbs don't float)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.15, location=(0.35,0,0.6))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.15, location=(-0.35,0,0.6))

def build_head():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=24, radius=0.22, location=(0,0,0.1))

def build_upper_limb(): 
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.1, depth=0.45, location=(0,0,-0.225))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.11, location=(0,0,-0.45)) # Elbow Joint

def build_lower_limb(): 
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.08, depth=0.45, location=(0,0,-0.225))
    # Hand/Foot integration
    bpy.ops.mesh.primitive_cube_add(size=0.14, location=(0,0,-0.48))

def build_sword():
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.03, depth=0.4, location=(0,0,0))
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0,0,0.2))
    bpy.context.object.scale = (3.5, 0.6, 0.8)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.08, radius2=0.01, depth=1.6, location=(0,0,1.0))
    bpy.context.object.scale = (1.2, 0.2, 1.0)
    bpy.context.object.rotation_euler = (0, 0, 0.785)

def build_shield():
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.45, depth=0.05, location=(0,0,0))
    bpy.context.object.scale = (1.0, 1.4, 1.0)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, radius=0.15, location=(0,0,0.06))
    bpy.context.object.scale = (1.0, 1.0, 0.4)

def build_tree():
    def branch(loc, angle_x, angle_y, level, scale):
        if level == 0:
            # Add Needles/Leaves
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.8 * scale, location=loc)
            return
        # Branch segment
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.12 * scale, depth=2.0 * scale, location=loc)
        b = bpy.context.object
        b.rotation_euler = (angle_x, angle_y, 0)
        
        offset_z = math.cos(angle_x) * math.cos(angle_y) * (1.0 * scale)
        offset_x = math.sin(angle_y) * (1.0 * scale)
        offset_y = -math.sin(angle_x) * (1.0 * scale)
        next_loc = (loc[0] + offset_x, loc[1] + offset_y, loc[2] + offset_z)

        # Recursive branching
        branch(next_loc, angle_x + 0.6, angle_y + 0.4, level - 1, scale * 0.7)
        branch(next_loc, angle_x - 0.4, angle_y - 0.6, level - 1, scale * 0.7)
        if level > 1:
            branch(next_loc, angle_x + 0.2, angle_y - 0.5, level - 1, scale * 0.7)

    branch((0,0,1.0), 0, 0, 3, 1.0)

def build_terrain():
    bpy.ops.mesh.primitive_grid_add(size=16, x_subdivisions=64, y_subdivisions=64)

with open("app/src/main/cpp/models/AllModels.h", "w") as f: f.write("#pragma once\n")
bake_and_export("TORSO", 0.7, 0.75, 0.8, build_torso, "app/src/main/cpp/models/AllModels.h") 
bake_and_export("HEAD", 0.9, 0.7, 0.6, build_head, "app/src/main/cpp/models/AllModels.h") 
bake_and_export("UP_LIMB", 0.5, 0.55, 0.6, build_upper_limb, "app/src/main/cpp/models/AllModels.h") 
bake_and_export("LOW_LIMB", 0.5, 0.55, 0.6, build_lower_limb, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SWORD", 0.85, 0.9, 0.95, build_sword, "app/src/main/cpp/models/AllModels.h") 
bake_and_export("SHIELD", 0.4, 0.25, 0.15, build_shield, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TREE", 0.15, 0.35, 0.1, build_tree, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TERRAIN", 0.2, 0.6, 0.2, build_terrain, "app/src/main/cpp/models/AllModels.h", True)
EOF

blender --background --python runtime/python/gen_models.py
