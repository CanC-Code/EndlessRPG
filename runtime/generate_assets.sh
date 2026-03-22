#!/bin/bash
echo "Generating Realistic Skeletal Anatomical Models..."

cat << 'EOF' > runtime/python/export_utils.py
import bpy

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def bake_and_export(name, r, g, b, build_func, outfile, is_terrain=False):
    clean()
    build_func()
    
    # Smooth Shading for High-Fidelity
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
            ao = 0.5 + (0.5 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            
            if is_terrain and v.co.z > 0.05:
                verts.extend([0.4*lum*ao, 0.4*lum*ao, 0.4*lum*ao])
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

# Anatomical Separation for Kinematics. Pivot points are anchored at Z=0.
def build_torso():
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.25, depth=0.6, location=(0,0,0.3))

def build_head():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=16, radius=0.2, location=(0,0,0.2))

def build_upper_limb(): # Pivots from Top
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.1, depth=0.4, location=(0,0,-0.2))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, radius=0.12, location=(0,0,0)) # Joint

def build_lower_limb(): # Pivots from Knee/Elbow
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.08, depth=0.4, location=(0,0,-0.2))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, radius=0.1, location=(0,0,0)) # Joint

def build_sword():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, radius=0.08, location=(0,0,0))
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.04, depth=0.4, location=(0,0,0.2))
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0,0,0.4))
    bpy.context.object.scale = (3.0, 0.5, 0.5)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.1, radius2=0.01, depth=1.2, location=(0,0,1.0))
    bpy.context.object.scale = (1.0, 0.2, 1.0)

def build_shield():
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.4, depth=0.1, location=(0,0,0))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, radius=0.15, location=(0,0,0.05))

def build_tree():
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.2, depth=1.5, location=(0,0,0.75))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.2, location=(0,0,2.0))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.9, location=(0,0,2.8))

def build_terrain():
    bpy.ops.mesh.primitive_grid_add(size=8, x_subdivisions=24, y_subdivisions=24) # High density for math waves

with open("app/src/main/cpp/models/AllModels.h", "w") as f: f.write("#pragma once\n")
bake_and_export("TORSO", 0.2, 0.3, 0.8, build_torso, "app/src/main/cpp/models/AllModels.h")
bake_and_export("HEAD", 0.9, 0.7, 0.6, build_head, "app/src/main/cpp/models/AllModels.h")
bake_and_export("UP_LIMB", 0.7, 0.7, 0.7, build_upper_limb, "app/src/main/cpp/models/AllModels.h")
bake_and_export("LOW_LIMB", 0.6, 0.6, 0.6, build_lower_limb, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SWORD", 0.8, 0.8, 0.9, build_sword, "app/src/main/cpp/models/AllModels.h")
bake_and_export("SHIELD", 0.4, 0.2, 0.1, build_shield, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TREE", 0.1, 0.4, 0.1, build_tree, "app/src/main/cpp/models/AllModels.h")
bake_and_export("TERRAIN", 0.3, 0.6, 0.2, build_terrain, "app/src/main/cpp/models/AllModels.h", True)
EOF

blender --background --python runtime/python/gen_models.py
