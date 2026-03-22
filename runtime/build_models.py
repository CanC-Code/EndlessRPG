# File: runtime/build_models.py
import bpy
from math import radians

def create_character():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Create organic body with Subdivision Surface
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 1))
    body = bpy.context.active_object
    mod = body.modifiers.new(name="Subdiv", type='SUBSURF')
    mod.levels = 2

    # Procedural Rigging (Simplified for 5 fingers)
    bpy.ops.object.armature_add(location=(0, 0, 0))
    arm = bpy.context.active_object
    bpy.ops.object.mode_set(mode='EDIT')
    
    # Bone structure for realistic movement
    eb = arm.data.edit_bones
    root = eb["Bone"]
    root.name = "Spine"
    root.tail = (0, 0, 1.5)
    
    # Add Right Arm and Fingers
    r_arm = eb.new("UpperArm.R")
    r_arm.head, r_arm.tail = (0, 0, 1.3), (-0.5, 0, 1.3)
    r_arm.parent = root
    
    for i in range(5):
        f = eb.new(f"Finger.{i}.R")
        f.head = (-1.0, (i*0.05)-0.1, 1.3)
        f.tail = (-1.1, (i*0.05)-0.1, 1.3)
        f.parent = r_arm

    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.wm.obj_export(filepath="app/src/main/assets/models/player.obj")

if __name__ == "__main__":
    create_character()
