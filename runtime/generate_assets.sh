#!/bin/bash
# File: runtime/generate_assets.sh
# Bakes all models via Blender using the Python generator.
set -e
mkdir -p app/src/main/cpp/models

cat << 'EOF' > runtime/build_models.py
import bpy
import bmesh

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def export_voxel_model(name, r, g, b, build_func):
    clean()
    build_func()
    
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            for poly in obj.data.polygons: poly.use_smooth = False

    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)
    
    verts = []
    mesh = obj.data
    min_z = min((v.co.z for v in mesh.vertices), default=0)
    height = max((v.co.z for v in mesh.vertices), default=1) - min_z
    mesh.calc_loop_triangles()

    for tri in mesh.loop_triangles:
        # Baked lighting based on face normals
        lum = 0.5 + (tri.normal.z * 0.4) + (tri.normal.x * 0.1)
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            # OpenGL Coordinate Swap
            verts.extend([v.co.x, v.co.z, -v.co.y])
            # Fake Ambient Occlusion: Darker at the bottom
            ao = 0.4 + (0.6 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            verts.extend([r*lum*ao, g*lum*ao, b*lum*ao])
    return verts

def build_armoured_knight():
    bpy.ops.mesh.primitive_cube_add(size=0.6, location=(0,0,0.7)) # Torso
    bpy.ops.mesh.primitive_cube_add(size=0.45, location=(0,0,1.3)) # Helm
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=(0.4,0,0.9)) # Pad L
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=(-0.4,0,0.9)) # Pad R

def build_pixel_sword():
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0.4,0.4,0.8)) # Hilt
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(0.4,0.4,1.0)) # Guard
    bpy.ops.mesh.primitive_cube_add(size=0.15, location=(0.4,0.4,1.4)) # Blade
    bpy.context.object.scale = (0.5, 0.2, 4.0)

def build_voxel_tree():
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(0,0,0.5)) # Trunk
    bpy.context.object.scale = (1,1,3)
    bpy.ops.mesh.primitive_cube_add(size=1.2, location=(0,0,1.8)) # Foliage 1
    bpy.ops.mesh.primitive_cube_add(size=0.8, location=(0,0,2.5)) # Foliage 2

models = [("HERO", 0.7,0.7,0.8, build_armoured_knight), ("SWORD", 0.5,0.8,1.0, build_pixel_sword),
          ("TREE", 0.1,0.5,0.1, build_voxel_tree)]

with open("app/src/main/cpp/models/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    for n, r, g, b, func in models:
        d = export_voxel_model(n, r, g, b, func)
        f.write(f"const float M_{n}[] = {{ {', '.join(map(str, d))} }};\nconst int N_{n} = {len(d)//6};\n")
EOF

blender --background --python runtime/build_models.py
