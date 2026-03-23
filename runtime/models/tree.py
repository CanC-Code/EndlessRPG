# File: runtime/models/tree.py
# Enhanced realistic deciduous tree for EndlessRPG v4.
# - Three-part trunk: wide root flare, mid-taper, upper crown.
# - Root buttresses at base for grounding.
# - Thirteen canopy lobes forming a full asymmetric crown.
# - All geometry sits strictly above Z=0 (no floating parts).

import bpy
import bmesh
import math
import random


def build_tree(seed: int = 42):
    random.seed(seed)

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # ── Root flare / base ───────────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=14, radius=0.26, depth=0.50,
        location=(0, 0, 0.25))
    base = bpy.context.object
    # Flare the very bottom outward
    for v in base.data.vertices:
        if v.co.z < 0.10:
            flare = 1.0 + (0.10 - v.co.z) / 0.10 * 0.35
            v.co.x *= flare
            v.co.y *= flare
    sub = base.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Mid trunk ───────────────────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.18, depth=1.20,
        location=(0, 0, 1.10))
    mid = bpy.context.object
    # Slight lean variation from seed
    lean_x = random.uniform(-0.04, 0.04)
    lean_y = random.uniform(-0.04, 0.04)
    for v in mid.data.vertices:
        t = (v.co.z - 0.50) / 1.20
        v.co.x += lean_x * t
        v.co.y += lean_y * t
    sub = mid.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Upper trunk / crown stem ────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=10, radius=0.11, depth=0.90,
        location=(0, 0, 2.15))
    upper = bpy.context.object
    sub = upper.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Root buttresses (4 small fins at base) ──────────────────────
    for i in range(4):
        ang = i * math.pi / 2 + random.uniform(-0.2, 0.2)
        bx = math.cos(ang) * 0.22
        by = math.sin(ang) * 0.22
        bpy.ops.mesh.primitive_cube_add(size=1, location=(bx, by, 0.12))
        butt = bpy.context.object
        butt.scale = (0.055, 0.020, 0.14)
        butt.rotation_euler = (0, 0, ang)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        sub = butt.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Canopy — 13 overlapping lobes ───────────────────────────────
    # All centres strictly above Z=2.4 so they attach above crown.
    canopy = [
        # (cx, cy, cz, radius)
        ( 0.00,  0.00, 3.20, 1.05),   # central dominant
        ( 0.60,  0.30, 2.95, 0.78),
        (-0.55,  0.40, 3.00, 0.74),
        ( 0.25, -0.58, 2.88, 0.72),
        (-0.42, -0.32, 3.30, 0.66),
        ( 0.62, -0.15, 3.44, 0.56),
        (-0.52,  0.10, 3.48, 0.54),
        ( 0.00,  0.60, 3.58, 0.50),
        ( 0.00,  0.00, 3.85, 0.58),   # top cap
        ( 0.35,  0.48, 3.70, 0.44),
        (-0.30, -0.50, 3.65, 0.42),
        ( 0.55,  0.00, 3.78, 0.40),
        (-0.48,  0.25, 3.80, 0.38),
    ]
    for cx, cy, cz, cr in canopy:
        # Randomise slightly per seed
        cx += random.uniform(-0.08, 0.08)
        cy += random.uniform(-0.08, 0.08)
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=10, ring_count=7,
            radius=cr, location=(cx, cy, cz))
        sub = bpy.context.object.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Join + apply ────────────────────────────────────────────────
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object
