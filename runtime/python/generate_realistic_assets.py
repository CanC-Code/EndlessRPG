# File: runtime/python/generate_realistic_assets.py
import bpy
import random

def generate_tree():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    
    # Procedural Trunk
    bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=3, location=(0,0,1.5))
    trunk = bpy.context.active_object
    
    # Procedural Canopy (Realistic leaves/branches)
    for i in range(10):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.8, location=(random.uniform(-0.5, 0.5), random.uniform(-0.5, 0.5), 3))
    
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()
    bpy.ops.wm.obj_export(filepath="app/src/main/assets/models/tree.obj")

if __name__ == "__main__":
    generate_tree()
