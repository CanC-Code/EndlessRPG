#!/bin/bash
echo "Generating Advanced Voxel Models and Terrain Chunks..."

cat << 'EOF' > runtime/python/build_models.py
import bpy
import bmesh
import random
from math import radians

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def export_model(name, r, g, b, build_func, is_terrain=False):
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
    mesh.calc_loop_triangles()
    min_z = min((v.co.z for v in mesh.vertices), default=0)
    height = max((v.co.z for v in mesh.vertices), default=1) - min_z

    for tri in mesh.loop_triangles:
        # Hard face normals for pixel shading
        lum = 0.5 + (tri.normal.z * 0.4) + (tri.normal.x * 0.1)
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            verts.extend([v.co.x, v.co.z, -v.co.y]) # Y-up for GL
            ao = 0.4 + (0.6 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            
            # Terrain color variance based on height
            if is_terrain:
                if v.co.z > 0.2: cr, cg, cb = 0.4, 0.4, 0.4 # Stone
                else: cr, cg, cb = r, g, b # Grass
            else: cr, cg, cb = r, g, b
            
            verts.extend([cr*lum*ao, cg*lum*ao, cb*lum*ao])
    return verts

def build_hero():
    bpy.ops.mesh.primitive_cube_add(size=0.6, location=(0,0,0.8)) # Torso
    bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0,0,1.4)) # Head
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=(0.4,0,0.8)) # Arm R
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=(-0.4,0,0.8)) # Arm L
    bpy.ops.mesh.primitive_cube_add(size=0.25, location=(0.15,0,0.25)) # Leg R
    bpy.ops.mesh.primitive_cube_add(size=0.25, location=(-0.15,0,0.25)) # Leg L

def build_sword():
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0.4,0.4,0.8))
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(0.4,0.4,1.0))
    bpy.ops.mesh.primitive_cube_add(size=0.15, location=(0.4,0.4,1.4))
    bpy.context.object.scale = (0.5, 0.2, 4.0)

def build_shield():
    bpy.ops.mesh.primitive_cube_add(size=0.7, location=(-0.4,0.3,0.9))
    bpy.context.object.scale = (1, 0.1, 1.2)

def build_tree():
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(0,0,0.5))
    bpy.context.object.scale = (1,1,3)
    bpy.ops.mesh.primitive_cube_add(size=1.4, location=(0,0,1.8))
    bpy.ops.mesh.primitive_cube_add(size=0.8, location=(0,0,2.8))

def build_terrain_chunk():
    # Real Ground: 8x8 meter physical chunk with height variance
    bpy.ops.mesh.primitive_grid_add(size=8, x_subdivisions=8, y_subdivisions=8)
    bm = bmesh.new()
    bm.from_mesh(bpy.context.object.data)
    for v in bm.verts: v.co.z = random.uniform(-0.1, 0.3)
    bm.to_mesh(bpy.context.object.data)
    bm.free()

models = [
    ("HERO", 0.8,0.8,0.9, build_hero, False),
    ("SWORD", 0.5,0.8,1.0, build_sword, False),
    ("SHIELD", 0.5,0.3,0.1, build_shield, False),
    ("TREE", 0.2,0.6,0.1, build_tree, False),
    ("TERRAIN", 0.2,0.5,0.1, build_terrain_chunk, True)
]

with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    for n, r, g, b, func, is_t in models:
        d = export_model(n, r, g, b, func, is_t)
        f.write(f"const float M_{n}[] = {{ {', '.join(map(str, d))} }};\nconst int N_{n} = {len(d)//6};\n")
EOF

blender --background --python runtime/python/build_models.py
