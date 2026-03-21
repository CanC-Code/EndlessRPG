#!/bin/bash
echo "Generating Realistic 3D Models..."

cat << 'EOF' > runtime/python/export_utils.py
import bpy

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def bake_and_export(name, r, g, b, build_func, outfile, is_terrain=False):
    clean()
    build_func()
    
    # REALISTIC AESTHETIC: Use Smooth Shading everywhere
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
            
            # Use Vertex Normals for smooth lighting transitions
            norm = v.normal
            lum = 0.5 + (norm.z * 0.4) + (norm.x * 0.1)
            ao = 0.5 + (0.5 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            
            # Subtle variation for terrain
            if is_terrain and v.co.z > 0.05:
                verts.extend([0.4*lum*ao, 0.4*lum*ao, 0.4*lum*ao]) # Rock
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

def build_hero():
    # Capsule Body
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.3, depth=1.0, location=(0,0,0.8))
    # Spherical Head
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=16, radius=0.25, location=(0,0,1.5))
    # Shoulders
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, radius=0.15, location=(0.35,0,1.1))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, radius=0.15, location=(-0.35,0,1.1))

def build_sword():
    # Pommel
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, radius=0.08, location=(0.4,0.4,0.7))
    # Grip
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.04, depth=0.4, location=(0.4,0.4,0.9))
    # Crossguard
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0.4,0.4,1.1))
    bpy.context.object.scale = (3.0, 0.5, 0.5)
    # Tapered Blade
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.1, radius2=0.01, depth=1.2, location=(0.4,0.4,1.7))
    bpy.context.object.scale = (1.0, 0.2, 1.0)
    bpy.context.object.rotation_euler = (0, 0, 0.785) # Diamond shape

def build_tree():
    # Smooth Trunk
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.2, depth=1.5, location=(0,0,0.75))
    # Organic layered foliage
    bpy.ops.mesh.primitive_icosphere_add(subdivisions=2, radius=1.2, location=(0,0,2.0))
    bpy.ops.mesh.primitive_icosphere_add(subdivisions=2, radius=0.9, location=(0,0,2.8))
    bpy.ops.mesh.primitive_icosphere_add(subdivisions=2, radius=0.6, location=(0,0,3.4))

def build_terrain():
    # Detailed grid for vertex displacement in C++
    bpy.ops.mesh.primitive_grid_add(size=8, x_subdivisions=16, y_subdivisions=16)

with open("app/src/main/cpp/models/AllModels.h", "w") as f: f.write("#pragma once\n")
bake_and_export("HERO", 0.2, 0.3, 0.8, build_hero, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SWORD", 0.8, 0.8, 0.9, build_sword, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TREE", 0.1, 0.4, 0.1, build_tree, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TERRAIN", 0.3, 0.6, 0.2, build_terrain, "app/src/main/cpp/models/AllModels.h", True)
EOF

blender --background --python runtime/python/gen_models.py
