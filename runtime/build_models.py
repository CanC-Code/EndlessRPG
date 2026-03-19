import bpy
from math import radians

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def export_model(name, r, g, b, build_func):
    clean()
    build_func()
    obj = bpy.context.object
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)
    
    verts = []
    mesh = obj.data
    min_z = min((v.co.z for v in mesh.vertices), default=0)
    height = max((v.co.z for v in mesh.vertices), default=1) - min_z
    mesh.calc_loop_triangles()

    for tri in mesh.loop_triangles:
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            # Convert Blender Z-up to OpenGL Y-up
            verts.extend([v.co.x, v.co.z, -v.co.y])
            # Bake Directional Light and Ambient Occlusion
            lum = 0.6 + (v.normal.z * 0.3)
            ao = 0.5 + (0.5 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            verts.extend([r*lum*ao, g*lum*ao, b*lum*ao])
    return verts

# Individualized Asset Logic
def build_hero():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=0.8, location=(0,0,0.8))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.25, location=(0,0,1.5))
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0,-0.2,1.2))
    bpy.context.object.scale = (0.3, 0.05, 0.6)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.join()

def build_sword():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=1.2, location=(0.4, 0.4, 1.1))
    bpy.context.object.rotation_euler = (radians(90),0,0)

def build_shield():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.1, location=(-0.4, 0.3, 0.9))
    bpy.context.object.rotation_euler = (radians(90),radians(90),0)

def build_tree():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.15, depth=1.0, location=(0,0,0.5))
    bpy.ops.mesh.primitive_cone_add(radius1=0.8, depth=2.0, location=(0,0,2.0))
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.join()

# Pipeline Execution
models = [("BODY", 0.1, 0.3, 0.8, build_hero), ("SWORD", 0.7, 0.7, 0.7, build_sword), 
          ("SHIELD", 0.4, 0.2, 0.1, build_shield), ("TREE", 0.1, 0.5, 0.1, build_tree)]

with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    for name, r, g, b, func in models:
        data = export_model(name, r, g, b, func)
        f.write(f"const float M_{name}[] = {{ {', '.join(map(str, data))} }};\n")
        f.write(f"const int N_{name} = {len(data)//6};\n")
