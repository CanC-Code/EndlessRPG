# File: runtime/models/equipment/sword.py
# EndlessRPG v5 — Longsword (unchanged from v4, kept for completeness).
# Pommel at origin (Z=0), blade extends to Z≈1.52.
# After GL remap blade points in +Y (up). Slash arc correct.

import bpy, math

def build_sword():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Pommel
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=7, radius=0.036, location=(0, 0, -0.036))
    pommel = bpy.context.object
    pommel.scale = (1.0, 0.75, 1.0)
    bpy.ops.object.transform_apply(scale=True)

    # Grip
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.020, depth=0.22, location=(0, 0, 0.11))
    grip = bpy.context.object

    # Grip wrap ridges
    ridges = []
    for zw in [0.04, 0.09, 0.14, 0.19]:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.022, minor_radius=0.004, major_segments=8, minor_segments=4, location=(0, 0, zw))
        ridges.append(bpy.context.object)

    # Cross-guard
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.232))
    guard = bpy.context.object
    guard.scale = (0.190, 0.024, 0.040)
    bpy.ops.object.transform_apply(scale=True)
    for v in guard.data.vertices:
        taper = abs(v.co.x) / 0.190
        v.co.z -= taper * taper * 0.012

    # Ricasso
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.296))
    ricasso = bpy.context.object
    ricasso.scale = (0.022, 0.007, 0.050)
    bpy.ops.object.transform_apply(scale=True)

    # Blade
    blade_base, blade_len = 0.350, 0.585
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, blade_base + blade_len))
    blade = bpy.context.object
    blade.scale = (0.020, 0.0055, blade_len)
    bpy.ops.object.transform_apply(scale=True)

    tip_start = blade_base + blade_len * 2 - 0.18
    for v in blade.data.vertices:
        if v.co.z > tip_start:
            t = (v.co.z - tip_start) / 0.18
            v.co.x *= max(0.0, 1.0 - t)
            v.co.y *= max(0.0, 1.0 - t)

    # Fuller grooves
    fullers = []
    for sy in [-0.0030, 0.0030]:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, sy, blade_base + blade_len * 0.55))
        f = bpy.context.object
        f.scale = (0.005, 0.0008, blade_len * 0.62)
        bpy.ops.object.transform_apply(scale=True)
        fullers.append(f)

    # Cut out the fullers
    for f in fullers:
        mod = blade.modifiers.new(type="BOOLEAN", name="Sub")
        mod.operation = 'DIFFERENCE'
        mod.object = f
        bpy.context.view_layer.objects.active = blade
        bpy.ops.object.modifier_apply(modifier="Sub")
        bpy.data.objects.remove(f, do_unlink=True)

    # Join 
    objects_to_join = [pommel, grip, guard, ricasso, blade] + ridges
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects_to_join:
        obj.select_set(True)
    
    bpy.context.view_layer.objects.active = blade
    bpy.ops.object.join()
    bpy.ops.object.shade_smooth()

    return bpy.context.active_object

if __name__ == "__main__":
    sword = build_sword()
    sword.name = "Longsword"
