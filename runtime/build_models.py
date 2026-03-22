# File: runtime/build_models.py
import bpy

def build_realistic_player():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Create Body with smooth anatomy
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 1))
    body = bpy.context.active_object
    body.modifiers.new(name="Subdiv", type='SUBSURF').levels = 2
    
    # Rigging with 5 Fingers
    bpy.ops.object.armature_add(location=(0,0,0))
    arm = bpy.context.active_object
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    
    # Simple finger structure for 5-finger grip
    for i in range(5):
        f = eb.new(f"Finger_{i}")
        f.head = (0.2, (i*0.05)-0.1, 1.0)
        f.tail = (0.3, (i*0.05)-0.1, 1.0)
    
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.wm.obj_export(filepath="app/src/main/assets/models/player.obj")

if __name__ == "__main__":
    build_realistic_player()
