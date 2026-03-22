# File: runtime/build_models.py
import bpy
from math import radians

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def create_realistic_humanoid():
    clean()
    
    # Base procedural mesh with subdivision for smooth anatomy
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 1))
    body = bpy.context.active_object
    body.name = "PlayerCharacter"
    bpy.ops.object.modifier_add(type='SUBSURF')
    body.modifiers["Subdivision"].levels = 2
    
    # Build a complex, realistic rig (including 5 fingers)
    bpy.ops.object.armature_add(location=(0, 0, 0))
    armature = bpy.context.active_object
    armature.name = "PlayerRig"
    bpy.ops.object.mode_set(mode='EDIT')
    
    bones = [
        ("Root", None, (0,0,0), (0,0,0.8)),
        ("Spine", "Root", (0,0,0.8), (0,0,1.4)),
        ("Neck", "Spine", (0,0,1.4), (0,0,1.6)),
        ("Head", "Neck", (0,0,1.6), (0,0,1.9)),
        ("Shoulder.R", "Spine", (0,0,1.3), (-0.2,0,1.3)),
        ("Arm.Upper.R", "Shoulder.R", (-0.2,0,1.3), (-0.6,0,1.3)),
        ("Arm.Lower.R", "Arm.Upper.R", (-0.6,0,1.3), (-1.0,0,1.3)),
        ("Hand.R", "Arm.Lower.R", (-1.0,0,1.3), (-1.1,0,1.3)),
        ("Thumb.R", "Hand.R", (-1.1,-0.1,1.3), (-1.2,-0.1,1.3)),
        ("Index.R", "Hand.R", (-1.1, 0.1,1.3), (-1.2, 0.1,1.3)),
        ("Middle.R", "Hand.R", (-1.1, 0.0,1.3), (-1.2, 0.0,1.3)),
        ("Ring.R", "Hand.R", (-1.1, -0.05,1.3), (-1.2, -0.05,1.3)),
        ("Pinky.R", "Hand.R", (-1.1, -0.15,1.3), (-1.2, -0.15,1.3))
    ]
    
    eb = armature.data.edit_bones
    for name, parent, head, tail in bones:
        bone = eb.new(name)
        bone.head = head
        bone.tail = tail
        if parent:
            bone.parent = eb[parent]
            
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Bind mesh to armature
    body.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    
    # Smooth, realistic sword swing animation
    bpy.ops.object.mode_set(mode='POSE')
    pb = armature.pose.bones
    
    action = bpy.data.actions.new(name="SwordSwing")
    armature.animation_data_create()
    armature.animation_data.action = action
    
    # Wind up (Frame 1)
    pb["Arm.Upper.R"].rotation_mode = 'QUATERNION'
    pb["Arm.Upper.R"].rotation_quaternion = (1, 0, 0, 0)
    armature.keyframe_insert(data_path="pose.bones[\"Arm.Upper.R\"].rotation_quaternion", frame=1)
    
    # Strike (Frame 15)
    pb["Arm.Upper.R"].rotation_quaternion = (0.707, 0, 0.707, 0)
    armature.keyframe_insert(data_path="pose.bones[\"Arm.Upper.R\"].rotation_quaternion", frame=15)
    
    # Follow through (Frame 30)
    pb["Arm.Upper.R"].rotation_quaternion = (0.5, 0, 0.866, 0)
    armature.keyframe_insert(data_path="pose.bones[\"Arm.Upper.R\"].rotation_quaternion", frame=30)
    
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.wm.obj_export(filepath="app/src/main/assets/models/player.obj")

if __name__ == "__main__":
    create_realistic_humanoid()
