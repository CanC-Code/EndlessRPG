# File: runtime/models/equipment/shield.py
# EndlessRPG v5 — Heater shield for knight.
#
# Coordinate convention (Blender Z-up → GL Y-up via build_models.py remap):
#   GL(x,y,z) = Blender(x, z, -y)
#   Shield face: Blender +Y  →  GL -Z  (forward toward enemy)
#   Long axis:   Blender +Z  →  GL +Y  (upright)
#   Bottom tip:  Blender -Z  →  GL -Y  (hangs down)
#
# In drawCharacter (native-lib.cpp v5), the shield is placed at the wrist
# world position and oriented by m4RY(g_facing) + m4RX(-1.5708f).
# The -1.5708 (−π/2) X-rotation makes the disc stand upright:
#   Before: Blender +Z (up) is GL +Y — disc face is horizontal
#   After:  rotated so face points into the scene (GL -Z)
#
# Therefore this mesh should have:
#   - Face/front: in Blender +Y
#   - Long axis:  in Blender +Z (taller than wide)
#   - Origin:     grip centre (for even spread around wrist position)

import bpy, math


def build_shield():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # ── Main body ───────────────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32, radius=0.40, depth=0.032,
        location=(0, 0, 0))
    shield = bpy.context.object
    # Rotate so face is +Y, depth is Y axis
    shield.rotation_euler = (math.radians(90), 0, 0)
    # Kite: taller than wide
    shield.scale = (1.0, 1.0, 1.44)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Kite taper: narrow lower portion into a point
    for v in shield.data.vertices:
        if v.co.z < -0.20:
            depth_below = -v.co.z - 0.20
            taper = max(0.0, 1.0 - depth_below / 0.40)
            v.co.x *= taper ** 0.65
        # Round top corners
        if v.co.z > 0.46:
            cx = abs(v.co.x)
            if cx > 0.26:
                shrink = 1.0 - (cx - 0.26) / 0.14
                v.co.x *= max(shrink, 0.45)

    # Gentle concave curve on face (+Y side)
    for v in shield.data.vertices:
        if v.co.y > 0.005:
            r2 = v.co.x**2 + v.co.z**2
            v.co.y += max(0.0, 0.050 - r2 * 0.28)

    sub = shield.modifiers.new("Sub", 'SUBSURF'); sub.levels = 1
    bpy.ops.object.convert(target='MESH')

    # ── Wooden plank vertical ridges ────────────────────────────
    for px in [-0.16, 0.0, 0.16]:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(px, 0.024, 0.08))
        plank = bpy.context.object
        plank.scale = (0.012, 0.005, 0.50)
        bpy.ops.object.transform_apply(scale=True)

    # ── Central iron boss ────────────────────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=8, radius=0.076,
        location=(0, 0.050, 0.06))

    # ── Iron rim ─────────────────────────────────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.39, minor_radius=0.013,
        major_segments=32, minor_segments=6,
        location=(0, 0.018, 0))
    rim = bpy.context.object
    rim.rotation_euler = (math.radians(90), 0, 0)
    rim.scale = (1.0, 1.0, 1.44)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # ── Grip strap on back ───────────────────────────────────────
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.028, 0.04))
    strap = bpy.context.object; strap.scale = (0.036, 0.008, 0.26)
    bpy.ops.object.transform_apply(scale=True)

    # ── Join ─────────────────────────────────────────────────────
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object
