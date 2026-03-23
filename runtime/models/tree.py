# File: runtime/models/tree.py
# Modular tree model for EndlessRPG.
# Builds a realistic deciduous tree: tapered two-part trunk + dense multi-lobe canopy.
# No floating geometry — canopy spheres are tightly grouped above the trunk crown.
# Called by runtime/build_models.py via: from models.tree import build_tree

import bpy
import bmesh
import random

def build_tree(seed: int = 42):
    """
    Realistic deciduous tree.
    - Two-cylinder trunk: wide base tapering upward.
    - Nine tightly-grouped canopy spheres at consistent heights.
    All objects joined before return.
    """
    random.seed(seed)

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # ── Trunk base (wider) ──────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.20, depth=0.80, location=(0, 0, 0.40))
    base = bpy.context.object
    sub = base.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Trunk mid (narrower) ───────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=10, radius=0.13, depth=1.80, location=(0, 0, 1.70))
    mid = bpy.context.object
    sub = mid.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Canopy ─────────────────────────────────────────────
    # All centres are strictly above trunk crown (z > 2.5)
    # and within 0.7 units horizontal so no ball floats away.
    canopy = [
        (0.00,  0.00, 3.10, 1.00),   # central top
        ( 0.55,  0.25, 2.85, 0.74),
        (-0.48,  0.38, 2.92, 0.70),
        ( 0.22, -0.52, 2.80, 0.68),
        (-0.38, -0.28, 3.25, 0.62),
        ( 0.58, -0.12, 3.38, 0.52),
        (-0.48,  0.08, 3.42, 0.50),
        ( 0.00,  0.55, 3.52, 0.47),
        ( 0.00,  0.00, 3.78, 0.52),   # top cap
    ]
    for cx, cy, cz, cr in canopy:
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=10, ring_count=7,
            radius=cr, location=(cx, cy, cz))
        sub = bpy.context.object.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Join + apply ───────────────────────────────────────
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object
