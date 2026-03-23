# File: runtime/build_models.py
import bpy

def export_to_cpp_header(obj, filepath, array_name):
    dg = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(dg)
    mesh = eval_obj.to_mesh()
    
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    
    with open(filepath, 'w') as f:
        f.write(f"const float {array_name}_verts[] = {{\n")
        count = 0
        for poly in mesh.polygons:
            for loop_idx in poly.loop_indices:
                v = mesh.vertices[mesh.loops[loop_idx].vertex_index].co
                n = poly.normal # Flat normals for beautiful pencil hatching
                # Convert Blender Z-Up to OpenGL Y-Up, and scale down slightly
                f.write(f"{v.x*0.4}f, {v.z*0.4}f, {-v.y*0.4}f, {n.x}f, {n.z}f, {-n.y}f,\n")
                count += 1
        f.write("};\n")
        f.write(f"const int {array_name}_count = {count};\n")
    eval_obj.to_mesh_clear()

def build_player():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Realistic Body
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 1.5))
    body = bpy.context.active_object
    body.modifiers.new(name="Subdiv", type='SUBSURF').levels = 2

    # Arm and 5 Fingers
    bpy.ops.object.armature_add(location=(0,0,0))
    arm = bpy.context.active_object
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    
    spine = eb.new("Spine")
    spine.head, spine.tail = (0,0,0.8), (0,0,1.5)
    
    arm_r = eb.new("Arm.R")
    arm_r.head, arm_r.tail = (0,0,1.4), (-0.8,0,1.4)
    arm_r.parent = spine
    
    for i in range(5):
        f = eb.new(f"Finger_{i}")
        f.head, f.tail = (-0.8, (i*0.06)-0.12, 1.4), (-0.95, (i*0.06)-0.12, 1.4)
        f.parent = arm_r
        
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Export directly to C++ source directory
    export_to_cpp_header(body, "app/src/main/cpp/player_model.h", "player")

if __name__ == "__main__":
    build_player()
