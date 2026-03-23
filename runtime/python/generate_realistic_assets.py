# File: runtime/python/generate_realistic_assets.py
import bpy
import random

def export_to_cpp_header(obj, filepath, array_name):
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = obj.evaluated_get(dg).to_mesh()
    
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
                n = poly.normal
                f.write(f"{v.x*0.5}f, {v.z*0.5}f, {-v.y*0.5}f, {n.x}f, {n.z}f, {-n.y}f,\n")
                count += 1
        f.write("};\n")
        f.write(f"const int {array_name}_count = {count};\n")

def build_tree():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    
    bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=3, location=(0,0,1.5))
    for i in range(12):
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=random.uniform(0.6, 1.2), 
            location=(random.uniform(-0.8, 0.8), random.uniform(-0.8, 0.8), random.uniform(2.0, 3.5))
        )
    
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()
    export_to_cpp_header(bpy.context.active_object, "app/src/main/cpp/tree_model.h", "tree")

if __name__ == "__main__":
    build_tree()
