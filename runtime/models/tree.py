# File: runtime/models/tree.py
# EndlessRPG v6 — High-Fidelity Procedural Tree Generator
import bpy, bmesh, math, random

def _apply_transforms(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def build_tree(seed=42, height=4.5):
    random.seed(seed)
    # Clear scene
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Create a new mesh and object
    mesh = bpy.data.meshes.new("TreeMesh")
    obj = bpy.data.objects.new("ProceduralTree", mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()

    # ── 1. ORGANIC TRUNK GENERATION ──────────────────────────────
    segments = 10
    radius = 0.35
    trunk_verts = []
    
    # Generate a series of rings with organic offsets
    for i in range(segments):
        t = i / (segments - 1)
        curr_z = t * height
        curr_rad = radius * (1.0 - (t * 0.7)) # Taper
        
        # Organic "wobble" (The Scenery Realism)
        off_x = math.sin(t * 4.0 + seed) * 0.15
        off_y = math.cos(t * 3.0 + seed) * 0.15
        
        # Create ring
        ring = bmesh.ops.create_circle(
            bm, segments=12, radius=curr_rad, 
            matrix=bpy.types.Matrix.Translation((off_x, off_y, curr_z))
        )['verts']
        trunk_verts.append(ring)

    # Bridge the rings to create the trunk skin
    for i in range(len(trunk_verts) - 1):
        bmesh.ops.bridge_loops(bm, edges=[e for v in trunk_verts[i] for e in v.link_edges] + 
                                       [e for v in trunk_verts[i+1] for e in v.link_edges])

    # ── 2. RECURSIVE BRANCHING ───────────────────────────────────
    # We pick points on the upper half of the trunk to grow branches
    for _ in range(6):
        start_t = random.uniform(0.4, 0.8)
        angle = random.uniform(0, math.pi * 2)
        b_length = random.uniform(1.0, 2.2)
        
        # Branch start position
        b_start = (math.sin(start_t * 4.0 + seed) * 0.15, 
                   math.cos(start_t * 3.0 + seed) * 0.15, 
                   start_t * height)
        
        # Branch end position (up and out)
        b_end = (b_start[0] + math.cos(angle) * b_length,
                 b_start[1] + math.sin(angle) * b_length,
                 b_start[2] + random.uniform(0.5, 1.5))
        
        # Create a simple branch cylinder
        bmesh.ops.create_cone(
            bm, cap_ends=True, segments=6, 
            diameter1=0.12 * (1.0 - start_t), diameter2=0.02, 
            depth=b_length, matrix=bpy.types.Matrix.Translation(
                ((b_start[0]+b_end[0])/2, (b_start[1]+b_end[1])/2, (b_start[2]+b_end[2])/2)
            )
        )

    bm.to_mesh(mesh)
    bm.free()

    # ── 3. REALISM: CANOPY CLUSTERS ─────────────────────────────
    # Instead of spheres, we create clusters at branch ends
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Add canopy "clouds"
    for _ in range(12):
        dist = random.uniform(1.0, 2.5)
        ang = random.uniform(0, 6.28)
        z_pos = height + random.uniform(-1.0, 1.0)
        
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=random.uniform(0.6, 1.2),
            location=(math.cos(ang)*dist, math.sin(ang)*dist, z_pos)
        )
        lobe = bpy.context.object
        lobe.scale = (1.2, 1.0, 0.7) # Flattened for "deciduous" look
        _apply_transforms(lobe)

    # ── 4. JOIN & VERTEX PAINTING (Wind Support) ────────────────
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()
    final_tree = bpy.context.active_object
    
    # Add a Vertex Group for Wind (Weight = Height/TotalHeight)
    vg = final_tree.vertex_groups.new(name="WindWeight")
    max_z = max([v.co.z for v in final_tree.data.vertices])
    for v in final_tree.data.vertices:
        weight = v.co.z / max_z
        vg.add([v.index], weight, 'REPLACE')

    # Final Polish
    bpy.ops.object.shade_smooth()
    sub = final_tree.modifiers.new("SubDiv", 'SUBSURF')
    sub.levels = 1
    
    return final_tree

if __name__ == "__main__":
    build_tree(seed=random.randint(0, 1000))
