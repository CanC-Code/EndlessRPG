# File: runtime/models/character.py
# Modular character body part builders for EndlessRPG.
# Each function clears the scene, builds one part, and returns the active object.
# Called by runtime/build_models.py

import bpy
import bmesh

def _apply_subsurf(obj, levels=1):
    sub = obj.modifiers.new("Sub", 'SUBSURF')
    sub.levels = levels
    sub.render_levels = levels

def build_torso():
    """Broad armoured torso, front-to-back flattened."""
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.30, depth=0.74, location=(0, 0, 0.37))
    obj = bpy.context.object
    obj.scale = (1.0, 0.74, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    _apply_subsurf(obj, 2)
    return obj

def build_head():
    """Slightly elongated skull."""
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=0.22, location=(0, 0, 0))
    obj = bpy.context.object
    obj.scale = (1.00, 0.87, 1.13)
    bpy.ops.object.transform_apply(scale=True)
    _apply_subsurf(obj, 2)
    return obj

def build_upper_limb():
    """Upper arm or thigh — tapered cylinder."""
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.088, depth=0.38, location=(0, 0, -0.19))
    obj = bpy.context.object
    _apply_subsurf(obj, 1)
    return obj

def build_lower_limb():
    """Forearm or shin — slightly slimmer."""
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.072, depth=0.36, location=(0, 0, -0.18))
    obj = bpy.context.object
    _apply_subsurf(obj, 1)
    return obj

def build_foot():
    """Boot/shoe — squarish rounded block."""
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.05, 0, -0.07))
    obj = bpy.context.object
    obj.scale = (0.145, 0.082, 0.072)
    bpy.ops.object.transform_apply(scale=True)
    _apply_subsurf(obj, 1)
    return obj

def build_rock():
    """Weathered field rock — perturbed icosphere."""
    import random; random.seed(7)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.45, location=(0, 0, 0))
    obj = bpy.context.object
    obj.scale = (random.uniform(0.9, 1.3), random.uniform(0.7, 1.1), random.uniform(0.38, 0.58))
    bpy.ops.object.transform_apply(scale=True)
    for v in obj.data.vertices:
        v.co.x += random.uniform(-0.04, 0.04)
        v.co.y += random.uniform(-0.04, 0.04)
        v.co.z += random.uniform(-0.02, 0.02)
    return obj
