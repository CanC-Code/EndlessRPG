#!/bin/bash
# File: runtime/generate_assets.sh
# Purpose: High-fidelity assets with fixed anatomy and branching trees.

cat << 'EOF' > runtime/python/export_utils.py
import bpy, bmesh, math

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def bake_and_export(name, r, g, b, build_func, outfile, is_terrain=False):
    clean()
    build_func()
    bpy.ops.object.select_all(action='SELECT')
    if not bpy.context.selected_objects: return
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    
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
        lum = 0.5 + (tri.normal.z * 0.4)
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            ao = 0.4 + (0.6 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            # Formatted exactly to engine expectations: X, Y, Z, R, G, B, U, V
            verts.extend([v.co.x, v.co.z, -v.co.y, r*lum*ao, g*lum*ao, b*lum*ao, v.co.x*0.5, v.co.y*0.5])
            
    with open(outfile, "a") as f:
        f.write(f"const float M_{name}[] = {{ {', '.join(map(str, verts))} }};\n")
        f.write(f"const int N_{name} = {len(verts)//8};\n")
EOF

cat << 'EOF' > runtime/python/gen_models.py
import bpy, sys, math
sys.path.append('runtime/python')
from export_utils import bake_and_export

def build_body():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.28, depth=0.7, location=(0,0,0.35))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.2, location=(0,0,0.75)) # Neck attached seamlessly
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, location=(0.35,0,0.6)) # L-Shoulder joint
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, location=(-0.35,0,0.6)) # R-Shoulder joint

def build_tree():
    def branch(loc, angle_x, angle_y, level, scale):
        if level == 0:
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.8*scale, location=loc)
            return
        bpy.ops.mesh.primitive_cylinder_add(radius=0.12*scale, depth=2.0*scale, location=loc)
        next_loc = (loc[0]+math.sin(angle_y)*scale, loc[1]-math.sin(angle_x)*scale, loc[2]+math.cos(angle_x)*scale)
        branch(next_loc, angle_x+0.6, angle_y+0.4, level-1, scale*0.7)
        branch(next_loc, angle_x-0.4, angle_y-0.6, level-1, scale*0.7)
    branch((0,0,1.0), 0, 0, 3, 1.0)

with open("app/src/main/cpp/models/AllModels.h", "w") as f: f.write("#pragma once\n")
bake_and_export("TORSO", 0.7, 0.7, 0.8, build_body, "app/src/main/cpp/models/AllModels.h")
bake_and_export("HEAD", 0.9, 0.7, 0.6, lambda: bpy.ops.mesh.primitive_uv_sphere_add(radius=0.22, location=(0,0,0.1)), "app/src/main/cpp/models/AllModels.h")
bake_and_export("UP_LIMB", 0.5, 0.5, 0.6, lambda: bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.45, location=(0,0,-0.225)), "app/src/main/cpp/models/AllModels.h")
bake_and_export("LOW_LIMB", 0.5, 0.5, 0.6, lambda: bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.45, location=(0,0,-0.225)), "app/src/main/cpp/models/AllModels.h")
bake_and_export("SWORD", 0.8, 0.8, 0.9, lambda: bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=1.6, location=(0,0,0.8)), "app/src/main/cpp/models/AllModels.h")
bake_and_export("SHIELD", 0.4, 0.3, 0.2, lambda: bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=0.05), "app/src/main/cpp/models/AllModels.h")
bake_and_export("TREE", 0.1, 0.4, 0.1, build_tree, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TERRAIN", 0.2, 0.5, 0.2, lambda: bpy.ops.mesh.primitive_grid_add(size=16, x_subdivisions=64, y_subdivisions=64), "app/src/main/cpp/models/AllModels.h")
EOF
blender --background --python runtime/python/gen_models.py
