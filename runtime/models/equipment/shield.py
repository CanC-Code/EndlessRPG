# File: runtime/models/equipment/shield.py
# Kite shield: vertically-elongated body with raised central boss and rim detail.
# Coordinate convention (Blender Z-up, exported to OpenGL Y-up by build_models.py):
#   • The shield FACE points in +Y (forward, toward the enemy).
#   • The long axis is vertical along +Z (top) / -Z (bottom/point).
#   • Origin is at the grip centre so the arm attach point in native-lib.cpp
#     needs only a simple forward offset.
#
# In build_models.py the Blender→GL remap is:  GL(x,y,z) = Blender(x, z, -y)
# So a Blender +Y face becomes GL -Z (into the scene) — exactly what we want for
# a shield held in front of the character's left arm.

import bpy

def build_shield():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()

    # ── Main disc ───────────────────────────────────────────────────
    # primitive_cylinder_add: depth along Z, circular cross-section in XY.
    # We want the shield FACE to point in +Y, so we need the depth (thin axis)
    # along Y.  Do that by adding with depth on Z then rotating 90° around X
    # BEFORE applying so the mesh is authored correctly.
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32, radius=0.44, depth=0.030,
        location=(0, 0, 0))
    shield = bpy.context.object
    # Rotate so the flat face points +Y
    import math
    shield.rotation_euler = (math.radians(90), 0, 0)
    # Kite shape: taller than wide
    shield.scale = (1.0, 1.0, 1.38)   # after rotation: X=width, Y=depth, Z=height
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Taper the bottom into a point (kite/heater shape)
    for v in shield.data.vertices:
        if v.co.z < -0.18:                      # lower third
            taper = 1.0 - ((-v.co.z - 0.18) / 0.42) * 0.72
            v.co.x *= max(taper, 0.0)

    # Slight forward curve on the face (+Y side)
    for v in shield.data.vertices:
        if v.co.y > 0.005:
            r = (v.co.x**2 + v.co.z**2) ** 0.5
            v.co.y += max(0.0, 0.04 - r * 0.09)

    sub = shield.modifiers.new("Sub", 'SUBSURF'); sub.levels = 1
    bpy.ops.object.convert(target='MESH')

    # ── Central boss (dome on face) ─────────────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=8, radius=0.075,
        location=(0, 0.046, 0))               # sits on the +Y face

    # ── Rim detail (thin torus, face-pointing) ──────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.43, minor_radius=0.012,
        major_segments=32, minor_segments=6,
        location=(0, 0.018, 0))
    rim = bpy.context.object
    rim.rotation_euler = (math.radians(90), 0, 0)
    rim.scale = (1.0, 1.0, 1.38)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # ── Join all parts ──────────────────────────────────────────────
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object
