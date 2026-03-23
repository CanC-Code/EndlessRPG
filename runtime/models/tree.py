# File: runtime/models/tree.py
# EndlessRPG v5 — Realistic deciduous tree with branch structure.
# - Root flare + three trunk segments with taper
# - Four primary branches radiating outward at mid-trunk height
# - Secondary branch stubs
# - Thirteen canopy lobes with interior depth variation
# - Bark geometry: subtle ridge loops on trunk

import bpy, bmesh, math, random


def build_tree(seed: int = 42):
    random.seed(seed)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # ── Root flare ──────────────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.28, depth=0.55,
                                         location=(0, 0, 0.275))
    base = bpy.context.object
    for v in base.data.vertices:
        if v.co.z < 0.12:
            flare = 1.0 + (0.12 - v.co.z) / 0.12 * 0.42
            v.co.x *= flare; v.co.y *= flare
    sub = base.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Lower trunk ─────────────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.20, depth=0.90,
                                         location=(0, 0, 0.98))
    lower = bpy.context.object
    # Lean
    lx = random.uniform(-0.05, 0.05); ly = random.uniform(-0.05, 0.05)
    for v in lower.data.vertices:
        t = (v.co.z - 0.53) / 0.90
        v.co.x += lx * t; v.co.y += ly * t
    sub = lower.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # Bark ridge loops on lower trunk
    for rz in [0.65, 0.90, 1.15, 1.38]:
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.21, minor_radius=0.010,
            major_segments=12, minor_segments=4,
            location=(lx*(rz-0.53)/0.9, ly*(rz-0.53)/0.9, rz))

    # ── Mid trunk ────────────────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.14, depth=0.80,
                                         location=(lx*0.5, ly*0.5, 1.88))
    mid = bpy.context.object
    sub = mid.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Upper crown stem ────────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.09, depth=0.60,
                                         location=(lx*0.6, ly*0.6, 2.68))
    upper = bpy.context.object
    sub = upper.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Primary branches (4) ─────────────────────────────────────
    for i in range(4):
        ang = i * math.pi / 2 + random.uniform(-0.25, 0.25)
        # Start at lower-mid trunk junction (~Z=1.5)
        bx = math.cos(ang) * 0.15; by = math.sin(ang) * 0.15
        # End out and up
        ex = math.cos(ang) * 0.85; ey = math.sin(ang) * 0.85
        length = 0.92 + random.uniform(-0.12, 0.12)
        cx = (bx + ex) / 2; cy = (by + ey) / 2
        cz = 1.5 + 0.32  # centre of branch
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8, radius=0.055, depth=length,
            location=(cx, cy, cz))
        br = bpy.context.object
        # Tilt branch outward and upward
        tilt = 0.52 + random.uniform(-0.12, 0.12)   # radians from horizontal
        br.rotation_euler = (tilt, 0, ang + math.pi / 2)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        sub = br.modifiers.new("S", 'SUBSURF'); sub.levels = 1

        # Secondary stub off each primary
        ang2 = ang + random.uniform(-0.6, 0.6)
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.032, depth=0.45,
            location=(ex * 0.7 + math.cos(ang2) * 0.15,
                       ey * 0.7 + math.sin(ang2) * 0.15,
                       cz + 0.30))
        sec = bpy.context.object
        sec.rotation_euler = (0.70, 0, ang2 + math.pi / 2)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    # ── Root buttresses ─────────────────────────────────────────
    for i in range(4):
        ang = i * math.pi / 2 + random.uniform(-0.18, 0.18)
        bx = math.cos(ang) * 0.24; by = math.sin(ang) * 0.24
        bpy.ops.mesh.primitive_cube_add(size=1, location=(bx, by, 0.14))
        butt = bpy.context.object
        butt.scale = (0.060, 0.022, 0.16)
        butt.rotation_euler = (0, 0, ang)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        sub = butt.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Canopy — 15 lobes, varied sizes ─────────────────────────
    canopy = [
        ( 0.00,  0.00, 3.20, 1.08),
        ( 0.62,  0.28, 2.92, 0.82),
        (-0.58,  0.40, 2.98, 0.78),
        ( 0.28, -0.60, 2.88, 0.76),
        (-0.44, -0.30, 3.28, 0.70),
        ( 0.64, -0.18, 3.42, 0.60),
        (-0.54,  0.12, 3.46, 0.58),
        ( 0.00,  0.62, 3.55, 0.54),
        ( 0.00,  0.00, 3.88, 0.62),
        ( 0.38,  0.50, 3.72, 0.48),
        (-0.32, -0.52, 3.68, 0.46),
        ( 0.58,  0.02, 3.80, 0.44),
        (-0.50,  0.28, 3.82, 0.42),
        ( 0.20, -0.40, 3.94, 0.38),
        ( 0.00,  0.20, 4.10, 0.36),
    ]
    for cx, cy, cz, cr in canopy:
        cx += random.uniform(-0.10, 0.10)
        cy += random.uniform(-0.10, 0.10)
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=10, ring_count=7,
            radius=cr, location=(cx, cy, cz))
        sub = bpy.context.object.modifiers.new("S", 'SUBSURF'); sub.levels = 1

    # ── Join ─────────────────────────────────────────────────────
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object
