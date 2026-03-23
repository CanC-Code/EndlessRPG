# File: runtime/models/equipment/sword.py
# Longsword — leather-wrapped grip, spherical pommel, flat cross-guard,
# fullergrooved blade with ricasso, tapered tip.
#
# Blender coordinate layout (Z-up):
#   Z=0        : pommel base — held in the hand (origin)
#   Z=0.00–0.22: grip
#   Z=0.22     : cross-guard
#   Z=0.25     : blade base (ricasso)
#   Z=0.25–1.52: blade (length ≈ 1.27 units)
#
# After GL remap (x, z, -y): blade points in +Y (up). The arm's swRot
# X-rotation sweeps it forward in a correct cutting arc.

import bpy
import math


def build_sword():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # ── Pommel — flattened sphere ────────────────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=10, ring_count=7, radius=0.036,
        location=(0, 0, -0.036))
    pommel = bpy.context.object
    pommel.scale = (1.0, 0.75, 1.0)   # slightly flattened
    bpy.ops.object.transform_apply(scale=True)

    # ── Grip — octagonal cylinder ────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=0.020, depth=0.22,
        location=(0, 0, 0.11))
    grip = bpy.context.object

    # ── Grip wrap ridges (leather binding) ──────────────────────────
    for zw in [0.04, 0.09, 0.14, 0.19]:
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.022, minor_radius=0.004,
            major_segments=8, minor_segments=4,
            location=(0, 0, zw))

    # ── Cross-guard — wider flat box ─────────────────────────────────
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.232))
    guard = bpy.context.object
    guard.scale = (0.190, 0.024, 0.040)
    bpy.ops.object.transform_apply(scale=True)
    # Guard quillons curve slightly downward
    for v in guard.data.vertices:
        taper = abs(v.co.x) / 0.190
        v.co.z -= taper * taper * 0.012

    # ── Ricasso (unsharpened blade base) ────────────────────────────
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.296))
    ricasso = bpy.context.object
    ricasso.scale = (0.022, 0.007, 0.050)
    bpy.ops.object.transform_apply(scale=True)

    # ── Blade — flat tapered box with fuller groove ──────────────────
    blade_base = 0.350
    blade_len  = 0.585     # half-depth; full length = 1.17
    bpy.ops.mesh.primitive_cube_add(size=1,
        location=(0, 0, blade_base + blade_len))
    blade = bpy.context.object
    blade.scale = (0.020, 0.0055, blade_len)
    bpy.ops.object.transform_apply(scale=True)

    # Taper to point at tip
    tip_start = blade_base + blade_len * 2 - 0.18
    for v in blade.data.vertices:
        if v.co.z > tip_start:
            t = (v.co.z - tip_start) / 0.18
            v.co.x *= max(0.0, 1.0 - t)
            v.co.y *= max(0.0, 1.0 - t)

    # Fuller groove — thin raised strip along the centre of each face
    # (simulated with a very thin box recessed slightly)
    for side_y in [-0.0030, 0.0030]:
        bpy.ops.mesh.primitive_cube_add(size=1,
            location=(0, side_y, blade_base + blade_len * 0.55))
        fuller = bpy.context.object
        fuller.scale = (0.005, 0.0008, blade_len * 0.62)
        bpy.ops.object.transform_apply(scale=True)

    # ── Join ─────────────────────────────────────────────────────────
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object
