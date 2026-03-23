# File: runtime/models/character.py
# EndlessRPG v6 — Enhanced Character & Real-World Environment Models
import bpy, bmesh, math, random

# ... [Keep your existing _clear, _apply, _sub, and build_part functions] ...

# ── ENHANCED CHARACTER ASSEMBLY ──────────────────────────────────
def assemble_knight():
    """Assembles the individual parts into a single Knight mesh."""
    parts = []
    
    # 1. Build and position parts based on your joint chain logic
    torso = build_torso() # Origin at hip bottom
    parts.append(torso)

    neck = build_neck()
    neck.location = (0, 0, 0.76)
    parts.append(neck)

    head = build_head()
    head.location = (0, 0, 0.94)
    parts.append(head)

    # Limbs (L/R)
    for side in [-1, 1]: # -1 for Left, 1 for Right
        # Arms
        u_arm = build_upper_limb()
        u_arm.location = (0.36 * side, 0, 0.70)
        parts.append(u_arm)
        
        # Legs
        u_leg = build_upper_limb()
        u_leg.location = (0.18 * side, 0, 0)
        parts.append(u_leg)

    # 2. Join all objects
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = torso
    bpy.ops.object.join()
    
    # 3. Final polish
    bpy.ops.object.shade_smooth()
    return bpy.context.active_object

# ── REAL-WORLD ENVIRONMENT: PROCEDURAL TREES ─────────────────────
def build_real_tree(height=4.0, seed=42):
    """Creates a realistic, tapered tree trunk with organic displacement."""
    random.seed(seed)
    _clear()
    
    # Create trunk via BMesh for organic control
    mesh = bpy.data.meshes.new("TreeTrunk")
    obj = bpy.data.objects.new("TreeTrunk", mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    
    segments = 8
    rings = 12
    for i in range(rings):
        t = i / (rings - 1)
        radius = 0.4 * (1.0 - t * 0.8) # Tapering
        z = t * height
        
        # Add organic "wobble" to the trunk path
        off_x = math.sin(t * 3.0 + seed) * 0.2
        off_y = math.cos(t * 2.0 + seed) * 0.2
        
        bmesh.ops.create_circle(bm, segments=segments, radius=radius, 
                                matrix=bpy.types.Matrix.Translation((off_x, off_y, z)))
    
    bm.to_mesh(mesh)
    bm.free()
    
    # Bridge the rings into a solid mesh
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.bridge_edge_loops()
    bpy.ops.object.mode_set(mode='OBJECT')
    
    _sub(obj, 2)
    bpy.ops.object.shade_smooth()
    return obj

# ── REAL-WORLD ENVIRONMENT: SWAYING GRASS ────────────────────────
def build_grass_blade():
    """Generates a curved, tapered grass blade for high-fidelity scenery."""
    _clear()
    # Create a plane and extrude/taper it
    bpy.ops.mesh.primitive_plane_add(size=0.1, location=(0,0,0))
    blade = bpy.context.object
    bpy.ops.object.mode_set(mode='EDIT')
    
    bm = bmesh.from_edit_mesh(blade.data)
    # Move the base to origin and extrude upward
    for v in bm.verts: v.co.y += 0.05 
    
    # Segmented extrusion for a smooth curve
    for i in range(4):
        bpy.ops.mesh.extrude_region_move(TRANSFORM_OT_translate={"value":(0, 0, 0.15)})
        bpy.ops.transform.resize(value=(0.7, 0.7, 1)) # Taper
        bpy.ops.transform.rotate(value=0.15, orient_axis='X') # Curve
        
    bmesh.update_edit_mesh(blade.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    _apply(blade)
    return blade

# ── EXPORT LOGIC ────────────────────────────────────────────────
if __name__ == "__main__":
    # Create the Knight
    knight = assemble_knight()
    knight.name = "Knight_Hero"
    
    # Create Environment assets
    tree = build_real_tree(height=5.5, seed=123)
    tree.location = (3, 3, 0)
    
    grass = build_grass_blade()
    grass.location = (1, 1, 0)
