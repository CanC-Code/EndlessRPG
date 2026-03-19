#!/bin/bash
echo "Generating Modular Voxel Assets..."
mkdir -p runtime/python
mkdir -p app/src/main/cpp/models

# 1. Base Exporter Utility
cat << 'EOF' > runtime/python/export_utils.py
import bpy

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def bake_and_export(name, r, g, b, build_func, outfile):
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
        lum = 0.6 + (tri.normal.z * 0.3) + (tri.normal.x * 0.1)
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            verts.extend([v.co.x, v.co.z, -v.co.y])
            ao = 0.4 + (0.6 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            verts.extend([r*lum*ao, g*lum*ao, b*lum*ao])
            
    with open(outfile, "a") as f:
        f.write(f"const float M_{name}[] = {{ {', '.join(map(str, verts))} }};\n")
        f.write(f"const int N_{name} = {len(verts)//6};\n")
EOF

# 2. Hero Generator
cat << 'EOF' > runtime/python/gen_hero.py
import bpy, sys
sys.path.append('runtime/python')
from export_utils import bake_and_export

def build_knight():
    bpy.ops.mesh.primitive_cube_add(size=0.6, location=(0,0,0.7))
    bpy.ops.mesh.primitive_cube_add(size=0.45, location=(0,0,1.3))
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=(0.4,0,0.9))
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=(-0.4,0,0.9))

with open("app/src/main/cpp/models/Hero.h", "w") as f: f.write("#pragma once\n")
bake_and_export("HERO", 0.7, 0.7, 0.8, build_knight, "app/src/main/cpp/models/Hero.h")
EOF

# 3. Items Generator
cat << 'EOF' > runtime/python/gen_items.py
import bpy, sys
sys.path.append('runtime/python')
from export_utils import bake_and_export

def build_sword():
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0.4,0.4,0.8))
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(0.4,0.4,1.0))
    bpy.ops.mesh.primitive_cube_add(size=0.15, location=(0.4,0.4,1.4))
    bpy.context.object.scale = (0.5, 0.2, 4.0)

def build_shield():
    bpy.ops.mesh.primitive_cube_add(size=0.7, location=(-0.4,0.3,0.9))
    bpy.context.object.scale = (1, 0.1, 1.2)

with open("app/src/main/cpp/models/Items.h", "w") as f: f.write("#pragma once\n")
bake_and_export("SWORD", 0.5, 0.8, 1.0, build_sword, "app/src/main/cpp/models/Items.h")
bake_and_export("SHIELD", 0.4, 0.2, 0.1, build_shield, "app/src/main/cpp/models/Items.h")
EOF

# 4. World Generator
cat << 'EOF' > runtime/python/gen_world.py
import bpy, sys
sys.path.append('runtime/python')
from export_utils import bake_and_export

def build_tree():
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(0,0,0.5))
    bpy.context.object.scale = (1,1,3)
    bpy.ops.mesh.primitive_cube_add(size=1.2, location=(0,0,1.8))
    bpy.ops.mesh.primitive_cube_add(size=0.8, location=(0,0,2.5))

with open("app/src/main/cpp/models/World.h", "w") as f: f.write("#pragma once\n")
bake_and_export("TREE", 0.1, 0.5, 0.1, build_tree, "app/src/main/cpp/models/World.h")
EOF

# Execute modules
blender --background --python runtime/python/gen_hero.py
blender --background --python runtime/python/gen_items.py
blender --background --python runtime/python/gen_world.py
