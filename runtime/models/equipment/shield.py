# File: runtime/models/equipment/shield.py
# Kite (heater) shield — oak wood planks, iron boss, leather rim.
#
# Blender coordinate convention (exported to GL by build_models.py):
#   GL(x, y, z) = Blender(x, z, -y)
#
# Shield face: Blender +Y  →  GL -Z  (faces forward / toward enemy).
# Long axis:   Blender +Z  →  GL +Y  (points upward).
# Bottom tip:  Blender -Z  →  GL -Y  (hangs down under gravity).
#
# Origin is at the grip centre (middle of the shield face in XZ, midpoint
# of depth in Y).  In native-lib.cpp, attach with only a forward Z offset
# so the face clears the forearm — no rotation needed.

import bpy
import math


def build_shield():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # ── Main disc body ───────────────────────────────────────────────
    # Cylinder with depth along Z; rotate 90° around X so depth is along Y
    # (face then points +Y). Scale Z to make kite taller than wide.
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32, radius=0.42, depth=0.034,
        location=(0, 0, 0))
    shield = bpy.context.object
    shield.rotation_euler = (math.radians(90), 0, 0)
    shield.scale = (1.0, 1.0, 1.42)   # taller than wide after rotation
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Taper lower portion into kite/heater point
    for v in shield.data.vertices:
        if v.co.z < -0.16:
            depth_below = -v.co.z - 0.16          # 0 at taper start
            taper = max(0.0, 1.0 - depth_below / 0.44)
            v.co.x *= taper ** 0.7                  # softer taper curve
        # Round top corners slightly
        if v.co.z > 0.44:
            corner_r = (v.co.x ** 2) ** 0.5
            if corner_r > 0.28:
                shrink = 1.0 - (corner_r - 0.28) / 0.14
                v.co.x *= max(shrink, 0.5)

    # Concave curve on face (+Y) for realism
    for v in shield.data.vertices:
        if v.co.y > 0.005:
            r2 = v.co.x ** 2 + v.co.z ** 2
            v.co.y += max(0.0, 0.055 - r2 * 0.30)

    sub = shield.modifiers.new("Sub", 'SUBSURF')
    sub.levels = 1
    bpy.ops.object.convert(target='MESH')

    # ── Wooden plank lines (shallow ridge loops along Z) ────────────
    # We simulate plank grain by adding thin raised strips on the face
    for px in [-0.18, 0.0, 0.18]:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(px, 0.026, 0.10))
        plank = bpy.context.object
        plank.scale = (0.014, 0.006, 0.52)
        bpy.ops.object.transform_apply(scale=True)

    # ── Central iron boss ────────────────────────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=14, ring_count=10, radius=0.078,
        location=(0, 0.052, 0.06))     # sits proud of the face

    # ── Iron rim (torus, face-oriented) ─────────────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.41, minor_radius=0.013,
        major_segments=32, minor_segments=6,
        location=(0, 0.020, 0))
    rim = bpy.context.object
    rim.rotation_euler = (math.radians(90), 0, 0)
    rim.scale = (1.0, 1.0, 1.42)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # ── Leather grip strap on back face ─────────────────────────────
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.030, 0.05))
    strap = bpy.context.object
    strap.scale = (0.038, 0.008, 0.28)
    bpy.ops.object.transform_apply(scale=True)

    # ── Join all ─────────────────────────────────────────────────────
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object
