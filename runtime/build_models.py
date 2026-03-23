import bpy

def build_realistic_player():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Base organic mesh structure
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 1))
    body = bpy.context.active_object
    body.modifiers.new(name="Subdiv", type='SUBSURF').levels = 2
    
    # Advanced 5-Finger Articulation Skeleton
    bpy.ops.object.armature_add(location=(0,0,0))
    armature = bpy.context.active_object
    bpy.ops.object.mode_set(mode='EDIT')
    eb = armature.data.edit_bones
    
    root = eb.new("Spine")
    root.head, root.tail = (0,0,0.8), (0,0,1.5)
    arm = eb.new("Arm.R")
    arm.head, arm.tail = (0,0,1.4), (-0.8,0,1.4)
    arm.parent = root
    
    # 5 fingers constructed programmatically
    for i in range(5):
        f = eb.new(f"Finger_{i}")
        f.head = (-0.8, (i*0.06)-0.12, 1.4)
        f.tail = (-0.95, (i*0.06)-0.12, 1.4)
        f.parent = arm
    
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.wm.obj_export(filepath="app/src/main/assets/models/player.obj")

if __name__ == "__main__":
    build_realistic_player()
