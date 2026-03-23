# File: runtime/python/generate_realistic_assets.py
# Supplementary asset generator (legacy entry point).
# The primary bake now uses runtime/build_models.py with modular models/.
# This file remains available for standalone Blender testing.

import sys, os
sys.path.insert(0, os.path.abspath("runtime"))
from models.tree import build_tree

import bpy, bmesh

def export_header(obj, path, name):
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = obj.evaluated_get(dg).to_mesh()
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(mesh); bm.free()
    mesh.calc_normals_split()
    verts = []
    for tri in mesh.loop_triangles:
        for li in tri.loops:
            v = mesh.vertices[mesh.loops[li].vertex_index]
            n = mesh.loops[li].normal
            verts += [v.co.x*.5, v.co.z*.5, -v.co.y*.5, n.x, n.z, -n.y]
    obj.evaluated_get(dg).to_mesh_clear()
    with open(path,'w') as f:
        f.write("#pragma once\n")
        f.write(f"const float {name}_verts[] = {{ {', '.join(f'{x:.5f}f' for x in verts)} }};\n")
        f.write(f"const int   {name}_count = {len(verts)//6};\n")

if __name__ == "__main__":
    tree = build_tree(42)
    export_header(tree, "app/src/main/cpp/tree_model.h", "tree")
    print("generate_realistic_assets.py complete.")
