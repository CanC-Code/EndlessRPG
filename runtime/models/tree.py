# File: runtime/models/tree.py
import bpy, bmesh, math, random

def _apply_transforms(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def build_tree(seed=42):
    random.seed(seed)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    
    mesh = bpy.data.meshes.new("TreeTrunk")
    obj = bpy.data.objects.new("TreeTrunk", mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()

    height = 5.0
    rings = 10
    trunk_verts = []
    
    # 1. TRUNK
    for i in range(rings):
        t = i / (rings - 1)
        curr_rad = 0.4 * (1.0 - t * 0.7)
        curr_z = t * height
        off_x = math.sin(t * 3.0 + seed) * 0.15
        off_y = math.cos(t * 4.0 + seed) * 0.15
        
        ring = bmesh.ops.create_circle(
            bm, segments=12, radius=curr_rad,
            matrix=bpy.types.Matrix.Translation((off_x, off_y, curr_z))
        )['verts']
        trunk_verts.append(ring)
        
    for i in range(len(trunk_verts) - 1):
        bmesh.ops.bridge_loops(bm, edges=[e for v in trunk_verts[i] for e in v.link_edges] + 
                                         [e for v in trunk_verts[i+1] for e in v.link_edges])

    # 2. RECURSIVE BRANCHING
    for _ in range(6):
        start_t = random.uniform(0.4, 0.8)
        angle = random.uniform(0, math.pi * 2)
        b_length = random.uniform(1.0, 2.2)
        
        b_start = (math.sin(start_t * 4.0 + seed) * 0.15, math.cos(start_t * 3.0 + seed) * 0.15, start_t * height)
        b_end = (b_start[0] + math.cos(angle) * b_length, b_start[1] + math.sin(angle) * b_length, b_start[2] + random.uniform(0.5, 1.5))
        
        bmesh.ops.create_cone(
            bm, cap_ends=True, segments=6, diameter1=0.12 * (1.0 - start_t), diameter2=0.02, depth=b_length,
            matrix=bpy.types.Matrix.Translation( ((b_start[0]+b_end[0])/2, (b_start[1]+b_end[1])/2, (b_start[2]+b_end[2])/2) )
        )

    bm.to_mesh(mesh)
    bm.free()

    # 3. REALISM: CANOPY CLUSTERS
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='OBJECT')

    for _ in range(12):
        dist = random.uniform(1.0, 2.5)
        ang = random.uniform(0, 6.28)
        z_pos = height + random.uniform(-1.0, 1.0)
        
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=random.uniform(0.6, 1.2),
            location=(math.cos(ang)*dist, math.sin(ang)*dist, z_pos)
        )
        lobe = bpy.context.object
        lobe.scale = (1.2, 1.0, 0.7) 
        _apply_transforms(lobe)

    # 4. JOIN & VERTEX PAINTING (Wind Support)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    final_tree = bpy.context.active_object
    
    vg = final_tree.vertex_groups.new(name="WindWeight")
    max_z = max([v.co.z for v in final_tree.data.vertices])
    for v in final_tree.data.vertices:
        weight = max(0, v.co.z / max_z)
        vg.add([v.index], weight, 'REPLACE')

    # Final Polish: Subsurf and Smooth
    sub = final_tree.modifiers.new(name="Subdivision", type='SUBSURF')
    sub.levels = 1
    bpy.ops.object.modifier_apply(modifier="Subdivision")
    bpy.ops.object.shade_smooth()

    return final_tree

if __name__ == "__main__":
    tree = build_tree(42)
    tree.name = "RealisticTree"
