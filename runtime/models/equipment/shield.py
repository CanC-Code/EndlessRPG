# File: runtime/models/equipment/shield.py
# Kite shield: a vertically-elongated disc with a raised central boss
# and a slight forward curve baked into the mesh.

import bpy

def build_shield():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()

    # Main disc (kite shape via scale)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32, radius=0.44, depth=0.030, location=(0, 0, 0))
    shield = bpy.context.object
    shield.scale = (1.0, 1.38, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    sub = shield.modifiers.new("Sub", 'SUBSURF'); sub.levels = 1

    # Slight forward curve — push front-face verts outward
    bpy.ops.object.convert(target='MESH')
    for v in shield.data.vertices:
        if v.co.z > 0.01:
            # Curve: push centre forward, edge less so
            r = (v.co.x**2 + v.co.y**2) ** 0.5
            v.co.z += max(0.0, 0.04 - r * 0.09)

    # Central boss (dome)
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=8, radius=0.075, location=(0, 0, 0.042))

    # Rim edge detail — thin torus
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.43, minor_radius=0.012,
        major_segments=32, minor_segments=6,
        location=(0, 0, 0.016))
    rim = bpy.context.object; rim.scale = (1.0, 1.38, 1.0)
    bpy.ops.object.transform_apply(scale=True)

    # Join
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object
