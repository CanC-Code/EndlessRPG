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
    mesh.calc_loop_triangles()
    
    for tri in mesh.loop_triangles:
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            # Interleaved VBO data: X, Y, Z, R, G, B
            # Convert Blender Z-up to OpenGL Y-up
            verts.extend([v.co.x, v.co.z, -v.co.y])
            
            # Simple top-down directional lighting bake
            lum = max(0.2, 0.6 + (v.normal.z * 0.4) + (v.normal.x * 0.1))
            verts.extend([r * lum, g * lum, b * lum])
            
    return verts

# --- Character Modules ---
v_body = export_model("BODY", 0.1, 0.3, 0.8, lambda: (
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=0.8, location=(0,0,0.8))
))
v_head = export_model("HEAD", 0.9, 0.7, 0.6, lambda: (
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.25, location=(0,0,1.5))
))
v_cape = export_model("CAPE", 0.8, 0.1, 0.1, lambda: (
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0,-0.2,0.9)),
    bpy.context.object.scale.update() or setattr(bpy.context.object, 'scale', (0.3, 0.05, 0.6)),
    bpy.context.object.rotation_euler.update() or setattr(bpy.context.object, 'rotation_euler', (radians(-15),0,0))
))
v_sword = export_model("SWORD", 0.7, 0.7, 0.75, lambda: (
    bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=1.2, location=(0.4, 0.4, 1.0)),
    bpy.context.object.rotation_euler.update() or setattr(bpy.context.object, 'rotation_euler', (radians(90),0,0))
))
v_shield = export_model("SHIELD", 0.4, 0.2, 0.1, lambda: (
    bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.1, location=(-0.4, 0.3, 0.9)),
    bpy.context.object.rotation_euler.update() or setattr(bpy.context.object, 'rotation_euler', (radians(90),radians(90),0))
))

# --- World Modules ---
v_tree = export_model("TREE", 0.2, 0.6, 0.2, lambda: (
    bpy.ops.mesh.primitive_cylinder_add(radius=0.15, depth=1.0, location=(0,0,0.5)),
    bpy.ops.mesh.primitive_cone_add(radius1=0.8, depth=2.0, location=(0,0,2.0)),
    bpy.ops.object.select_all(action='SELECT'),
    bpy.ops.object.join()
))

# Write Header
with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    models = [("BODY", v_body), ("HEAD", v_head), ("CAPE", v_cape), ("SWORD", v_sword), ("SHIELD", v_shield), ("TREE", v_tree)]
    for name, data in models:
        f.write(f"const float M_{name}[] = {{ {', '.join(map(str, data))} }};\n")
        f.write(f"const int N_{name} = {len(data)//6};\n")
