# File: runtime/models/character.py
# Modular character body part builders for EndlessRPG v4.
#
# Anatomy fixes:
#   - All limbs built with origin at the PROXIMAL joint (shoulder/hip)
#     so the hierarchy chain attaches correctly with no floating gaps.
#   - Limb cylinders are centred at -depth/2 on Z so joint pivot is at Z=0
#     and the distal end is at Z=-depth (ready for child attachment).
#   - Torso: proper chest width, waist taper, shoulder shelf.
#   - Head: correct skull shape with brow ridge, placed at neck top.
#   - Neck: short cylinder connecting torso to head.
#   - Hand: distinct from foot — flattened palm + short finger stub array.
#   - Foot/boot: longer forward extension, separate from hand.
#   - Upper limb tapers from shoulder radius to elbow radius.
#   - Lower limb tapers from elbow radius to wrist radius.
#   - Rock builder kept here to avoid breaking build_models.py import.

import bpy
import bmesh
import math


def _clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()


def _apply_subsurf(obj, levels=1):
    sub = obj.modifiers.new("Sub", 'SUBSURF')
    sub.levels = levels
    sub.render_levels = levels


def _apply_all(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


# ─────────────────────────────────────────────────────────────────────────────
#  TORSO
#  Origin: at hip centre (bottom of torso).
#  Chest top at Z=+0.74, hip bottom at Z=0.
#  Shoulder attachment points: X=±0.34, Z=0.68
#  Neck attachment: X=0, Z=0.74
#  Hip/leg attachment: X=±0.18, Z=0
# ─────────────────────────────────────────────────────────────────────────────
def build_torso():
    """Armoured torso with chest/waist taper. Origin at hip bottom."""
    _clear()

    # Build in edit mode for waist taper
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.30, depth=0.74,
                                        location=(0, 0, 0.37))
    obj = bpy.context.object
    # Front-to-back flatten (armour plate look)
    obj.scale = (1.0, 0.70, 1.0)
    _apply_all(obj)

    # Waist taper: narrow middle verts
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        # waist region: Z between 0.18 and 0.42
        if 0.18 < v.co.z < 0.42:
            t = 1.0 - abs(v.co.z - 0.30) / 0.12   # 0 at edges, 1 at Z=0.30
            taper = 1.0 - t * 0.18
            v.co.x *= taper
            v.co.y *= taper
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.object.mode_set(mode='OBJECT')

    # Shoulder shelf — widen chest top
    for v in obj.data.vertices:
        if v.co.z > 0.56:
            shelf = (v.co.z - 0.56) / 0.18
            v.co.x *= (1.0 + shelf * 0.20)

    _apply_subsurf(obj, 2)
    return obj


# ─────────────────────────────────────────────────────────────────────────────
#  NECK
#  Short cylinder. Origin at base (connects to torso top Z=0.74).
#  Top at Z=+0.18.
# ─────────────────────────────────────────────────────────────────────────────
def build_neck():
    """Short neck cylinder. Origin at base."""
    _clear()
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.085, depth=0.18,
                                        location=(0, 0, 0.09))
    obj = bpy.context.object
    obj.scale = (1.0, 0.80, 1.0)
    _apply_all(obj)
    _apply_subsurf(obj, 1)
    return obj


# ─────────────────────────────────────────────────────────────────────────────
#  HEAD
#  Skull with slight brow and cheekbone shape. Origin at neck attachment
#  point (bottom of head, i.e., chin level).
# ─────────────────────────────────────────────────────────────────────────────
def build_head():
    """Realistic skull shape. Origin at base (chin/neck joint)."""
    _clear()
    # UV sphere: origin will be at centre; we shift so base is at Z=0
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=14,
                                          radius=0.22, location=(0, 0, 0.22))
    obj = bpy.context.object
    # Slightly elongated vertically, narrower front-to-back
    obj.scale = (1.00, 0.84, 1.15)
    _apply_all(obj)

    # Brow ridge: push forward-upper verts
    for v in obj.data.vertices:
        if v.co.z > 0.26 and v.co.y < -0.05:   # front upper
            brow_t = min(1.0, (v.co.z - 0.26) / 0.10)
            v.co.y -= brow_t * 0.018

    # Jaw: widen lower face slightly
    for v in obj.data.vertices:
        if 0.04 < v.co.z < 0.18:
            jaw_t = 1.0 - abs(v.co.z - 0.11) / 0.07
            v.co.x *= (1.0 + jaw_t * 0.08)

    _apply_subsurf(obj, 2)
    return obj


# ─────────────────────────────────────────────────────────────────────────────
#  UPPER LIMB (upper arm / thigh)
#  Origin at shoulder/hip pivot (Z=0). Limb extends downward to Z=-0.40.
#  Tapered: wider at origin, narrower at tip.
# ─────────────────────────────────────────────────────────────────────────────
def build_upper_limb():
    """Upper arm or thigh. Origin at proximal joint (shoulder/hip). Tip at Z=-0.40."""
    _clear()
    depth = 0.40
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.095,
                                        depth=depth,
                                        location=(0, 0, -depth / 2))
    obj = bpy.context.object
    _apply_all(obj)

    # Taper to 75% radius at distal end
    for v in obj.data.vertices:
        t = clamp01((-v.co.z) / depth)   # 0 at proximal, 1 at distal
        taper = 1.0 - t * 0.25
        v.co.x *= taper
        v.co.y *= taper

    _apply_subsurf(obj, 1)
    return obj


# ─────────────────────────────────────────────────────────────────────────────
#  LOWER LIMB (forearm / shin)
#  Origin at elbow/knee pivot (Z=0). Tip at Z=-0.38.
# ─────────────────────────────────────────────────────────────────────────────
def build_lower_limb():
    """Forearm or shin. Origin at proximal joint (elbow/knee). Tip at Z=-0.38."""
    _clear()
    depth = 0.38
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.078,
                                        depth=depth,
                                        location=(0, 0, -depth / 2))
    obj = bpy.context.object
    _apply_all(obj)

    # Slight taper toward wrist/ankle
    for v in obj.data.vertices:
        t = clamp01((-v.co.z) / depth)
        taper = 1.0 - t * 0.20
        v.co.x *= taper
        v.co.y *= taper

    _apply_subsurf(obj, 1)
    return obj


# ─────────────────────────────────────────────────────────────────────────────
#  HAND
#  Distinct from foot. Flattened palm block + four short finger stubs.
#  Origin at wrist (top, Z=0). Palm base at Z=-0.10.
# ─────────────────────────────────────────────────────────────────────────────
def build_hand():
    """Armoured gauntlet hand. Origin at wrist. Palm extends Z=-0.10."""
    _clear()

    # Palm block
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -0.055))
    palm = bpy.context.object
    palm.scale = (0.105, 0.048, 0.065)
    _apply_all(palm)
    _apply_subsurf(palm, 1)

    # Four finger stubs
    finger_xs = [-0.038, -0.013, 0.013, 0.038]
    for fx in finger_xs:
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.012,
                                             depth=0.048,
                                             location=(fx, -0.010, -0.136))
        f = bpy.context.object
        _apply_all(f)

    # Thumb stub
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.014,
                                         depth=0.040,
                                         location=(0.060, 0, -0.080))
    thumb = bpy.context.object
    thumb.rotation_euler = (0, math.radians(40), 0)
    _apply_all(thumb)

    # Join
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object


# ─────────────────────────────────────────────────────────────────────────────
#  FOOT / BOOT
#  Distinct from hand. Long forward extension.
#  Origin at ankle (top, Z=0). Sole at Z=-0.085, toe extends forward in Y.
# ─────────────────────────────────────────────────────────────────────────────
def build_foot():
    """Leather boot. Origin at ankle. Toe extends in -Y (Blender forward)."""
    _clear()

    # Ankle block
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.030, -0.042))
    ankle = bpy.context.object
    ankle.scale = (0.095, 0.072, 0.048)
    _apply_all(ankle)
    _apply_subsurf(ankle, 1)

    # Toe extension (longer in Y)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.110, -0.060))
    toe = bpy.context.object
    toe.scale = (0.085, 0.068, 0.036)
    _apply_all(toe)
    _apply_subsurf(toe, 1)

    # Heel nub
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.042, -0.060))
    heel = bpy.context.object
    heel.scale = (0.072, 0.035, 0.032)
    _apply_all(heel)

    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object


# ─────────────────────────────────────────────────────────────────────────────
#  ROCK
# ─────────────────────────────────────────────────────────────────────────────
def build_rock():
    """Weathered field rock — perturbed icosphere."""
    import random
    random.seed(7)
    _clear()
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.45,
                                           location=(0, 0, 0))
    obj = bpy.context.object
    obj.scale = (random.uniform(0.9, 1.3),
                 random.uniform(0.7, 1.1),
                 random.uniform(0.38, 0.58))
    _apply_all(obj)
    for v in obj.data.vertices:
        v.co.x += random.uniform(-0.06, 0.06)
        v.co.y += random.uniform(-0.06, 0.06)
        v.co.z += random.uniform(-0.03, 0.03)
    # Flatten bottom so rock sits on ground
    for v in obj.data.vertices:
        if v.co.z < -0.10:
            v.co.z = -0.10
    _apply_subsurf(obj, 1)
    return obj


def clamp01(v):
    return max(0.0, min(1.0, v))
