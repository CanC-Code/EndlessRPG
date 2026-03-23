# File: runtime/models/equipment/sword.py
# Longsword: leather-wrapped grip, spherical pommel,
# flat cross-guard, and a gently tapered steel blade.

import bpy

def build_sword():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()

    # Grip — octagonal cylinder
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=0.018, depth=0.22, location=(0, 0, -0.11))
    grip = bpy.context.object
    grip.scale = (1.0, 1.0, 1.0)

    # Pommel — sphere
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=8, ring_count=6, radius=0.034, location=(0, 0, -0.245))

    # Cross-guard — flat box
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.012))
    guard = bpy.context.object; guard.scale = (0.175, 0.022, 0.038)
    bpy.ops.object.transform_apply(scale=True)

    # Blade — tapered flat box (wider at base, pointed at tip)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.62))
    blade = bpy.context.object; blade.scale = (0.019, 0.006, 0.62)
    bpy.ops.object.transform_apply(scale=True)
    # Taper tip using vertex manipulation
    mesh = blade.data
    for v in mesh.vertices:
        if v.co.z > 0.55:
            taper = 1.0 - (v.co.z - 0.55) / 0.07
            v.co.x *= max(taper, 0.0)
            v.co.y *= max(taper, 0.0)

    # Join
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object
