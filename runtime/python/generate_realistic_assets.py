import bpy
import random

def build_realistic_environment():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    
    # Procedural Tree Trunk
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=4, location=(0,0,2))
    
    # Realistic Dense Canopy Generation
    for i in range(15):
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=random.uniform(0.8, 1.4), 
            location=(random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(3, 5))
        )
    
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()
    bpy.ops.wm.obj_export(filepath="app/src/main/assets/models/tree.obj")

if __name__ == "__main__":
    build_realistic_environment()
