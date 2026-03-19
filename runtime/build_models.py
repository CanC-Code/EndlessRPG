import bpy
import bmesh
from math import radians

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def export_voxel(name, r, g, b, build_func):
    clean()
    build_func()
    # Apply Flat Shading for Voxel Aesthetic
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
    for tri in mesh.loop_triangles:
        # Bake face normal for hard pixel shading
        lum = 0.6 + (tri.normal.z * 0.3) + (tri.normal.x * 0.1)
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            verts.extend([v.co.x, v.co.z, -v.co.y]) # Y-up for OpenGL
            verts.extend([r*lum, g*lum, b*lum])
    return verts

def build_plate_armour():
    bpy.ops.mesh.primitive_cube_add(size=0.6, location=(0,0,0.7)) # Chest
    bpy.ops.mesh.primitive_cube_add(size=0.45, location=(0,0,1.3)) # Helm
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=(0.35,0,0.85)) # Pad L
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=(-0.35,0,0.85)) # Pad R

def build_sword():
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0.4,0.4,0.8)) # Hilt
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(0.4,0.4,1.0)) # Guard
    bpy.context.object.scale = (1, 0.2, 0.2)
    bpy.ops.mesh.primitive_cube_add(size=0.15, location=(0.4,0.4,1.4)) # Blade
    bpy.context.object.scale = (0.4, 0.1, 4.0)

def build_shield():
    bpy.ops.mesh.primitive_cube_add(size=0.7, location=(-0.4,0.3,0.9))
    bpy.context.object.scale = (1, 0.1, 1.2)

def build_voxel_tree():
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(0,0,0.5)) # Trunk
    bpy.context.object.scale = (1,1,3)
    bpy.ops.mesh.primitive_cube_add(size=1.3, location=(0,0,1.8)) # Leaves Low
    bpy.ops.mesh.primitive_cube_add(size=0.9, location=(0,0,2.6)) # Leaves High

models = [("HERO",0.8,0.8,0.9,build_plate_armour), ("SWORD",0.6,0.9,1.0,build_sword), 
          ("SHIELD",0.5,0.3,0.1,build_shield), ("TREE",0.2,0.6,0.2,build_voxel_tree)]

with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    for n,r,g,b,func in models:
        d = export_voxel(n,r,g,b,func)
        f.write(f"const float M_{n}[] = {{ {', '.join(map(str, d))} }};\nconst int N_{n} = {len(d)//6};\n")
