# File: runtime/models/equipment/sword.py
# Longsword: leather-wrapped grip, spherical pommel, flat cross-guard,
# and a gently tapered steel blade.
#
# Coordinate layout (Blender Z-up):
#   -Z = pommel (bottom of grip, held in the hand)
#    0 = cross-guard
#   +Z = blade tip
#
# The origin sits at the POMMEL END so that when native-lib.cpp attaches
# the sword at the character's hand position the grip fills the fist and
# the blade extends upward/forward.
#
# Swing: the slash animation rotates the arm around X.  With the blade
# pointing in +Z (Blender) → GL +Y (up), a negative X-rotation sweeps
# the tip forward and down in a natural cutting arc.

import bpy

def build_sword():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()

    # ── Grip — octagonal cylinder centred on grip midpoint ──────────
    # Grip length 0.22; pommel end at Z=-0.11, guard end at Z=+0.11
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=0.018, depth=0.22,
        location=(0, 0, 0.11))          # centre of grip
    grip = bpy.context.object

    # ── Pommel — sphere at the very bottom ──────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=8, ring_count=6, radius=0.034,
        location=(0, 0, -0.034))        # sits just below grip bottom

    # ── Cross-guard — flat box just above grip ──────────────────────
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.235))
    guard = bpy.context.object
    guard.scale = (0.175, 0.022, 0.038)
    bpy.ops.object.transform_apply(scale=True)

    # ── Blade — tapered flat box, base at guard, tip at +Z ──────────
    # Blade length 1.24 units; base at Z=0.27, tip at Z=1.51
    blade_len = 0.62
    blade_base_z = 0.27
    bpy.ops.mesh.primitive_cube_add(size=1,
        location=(0, 0, blade_base_z + blade_len))
    blade = bpy.context.object
    blade.scale = (0.019, 0.006, blade_len)
    bpy.ops.object.transform_apply(scale=True)
    # Taper to a point at the tip
    for v in blade.data.vertices:
        local_top = blade_base_z + blade_len * 2   # tip Z in world space
        if v.co.z > (blade_base_z + blade_len * 2 - 0.14):
            taper = 1.0 - (v.co.z - (blade_base_z + blade_len * 2 - 0.14)) / 0.14
            v.co.x *= max(taper, 0.0)
            v.co.y *= max(taper, 0.0)

    # ── Join ────────────────────────────────────────────────────────
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object
