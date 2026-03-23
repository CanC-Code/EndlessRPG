# File: runtime/models/character.py
# EndlessRPG v5 — Knight character with proper proportions.
# Knight proportions: wide armoured torso, broad shoulders, thick limbs,
# visored helmet, sabatons (armoured boots).
#
# Joint chain (all origins at proximal joint):
#   Torso   : origin at hip bottom, top at Z=+0.76
#   Neck    : origin at Z=0.76 (torso top)
#   Head    : origin at Z=0.94 (chin)
#   Shoulder: X=±0.36, Z=0.70
#   Limb    : extends -Z from origin, tip at Z=-length
#   Wrist   : at Z=-0.40 from elbow
#   Ankle   : at Z=-0.40 from knee

import bpy, bmesh, math


def _clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def _apply(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def _sub(obj, levels=1):
    s = obj.modifiers.new("Sub", 'SUBSURF')
    s.levels = s.render_levels = levels

def clamp01(v): return max(0.0, min(1.0, v))


# ── TORSO ────────────────────────────────────────────────────────
# Origin: hip bottom. Height: 0.76. Broad armoured plate.
def build_torso():
    _clear()
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.32, depth=0.76,
                                         location=(0, 0, 0.38))
    obj = bpy.context.object
    obj.scale = (1.0, 0.68, 1.0)   # front-back flatten
    _apply(obj)
    # Waist taper
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        if 0.20 < v.co.z < 0.46:
            t = 1.0 - abs(v.co.z - 0.33) / 0.13
            v.co.x *= (1.0 - t * 0.16)
            v.co.y *= (1.0 - t * 0.16)
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    # Shoulder shelf
    for v in obj.data.vertices:
        if v.co.z > 0.58:
            sh = (v.co.z - 0.58) / 0.18
            v.co.x *= (1.0 + sh * 0.24)
    # Armour plate ridge on chest front
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.23, 0.52))
    plate = bpy.context.object
    plate.scale = (0.22, 0.010, 0.18)
    _apply(plate)
    _sub(plate, 1)
    # Pauldron hints (shoulder caps)
    for sx in [-0.36, 0.36]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6,
                                              radius=0.095, location=(sx, 0, 0.72))
        p = bpy.context.object; p.scale=(1,0.7,0.7); _apply(p)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active=bpy.context.selected_objects[0]
    bpy.ops.object.join()
    _sub(bpy.context.active_object, 1)
    return bpy.context.active_object


# ── NECK ────────────────────────────────────────────────────────
def build_neck():
    _clear()
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.088, depth=0.18,
                                         location=(0, 0, 0.09))
    obj = bpy.context.object
    obj.scale = (1.0, 0.82, 1.0)
    _apply(obj)
    _sub(obj, 1)
    return obj


# ── HEAD (Visored Knight Helmet) ─────────────────────────────────
# Origin at chin. Skull at Z=0..0.46, visor/nasal extends forward.
def build_head():
    _clear()
    # Helmet skull
    bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=12,
                                          radius=0.24, location=(0, 0, 0.24))
    skull = bpy.context.object
    skull.scale = (1.02, 0.88, 1.12)
    _apply(skull)
    _sub(skull, 2)
    # Cheek guards — flat side plates
    for sx in [-0.20, 0.20]:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(sx, -0.06, 0.14))
        cg = bpy.context.object; cg.scale = (0.048, 0.035, 0.14); _apply(cg); _sub(cg, 1)
    # Nasal bar / visor slit
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.25, 0.28))
    nasal = bpy.context.object; nasal.scale = (0.035, 0.020, 0.10); _apply(nasal)
    # Visor brim
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.22, 0.24))
    brim = bpy.context.object; brim.scale = (0.22, 0.012, 0.018); _apply(brim)
    # Aventail (chain-coif hint at base)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.19, depth=0.06,
                                         location=(0, 0, 0.04))
    av = bpy.context.object; av.scale = (1, 0.90, 1); _apply(av); _sub(av, 1)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object


# ── UPPER LIMB (upper arm / thigh) ─────────────────────────────
# Origin at proximal joint (Z=0). Extends to Z=-0.42.
def build_upper_limb():
    _clear()
    depth = 0.42
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.100,
                                         depth=depth, location=(0, 0, -depth/2))
    obj = bpy.context.object; _apply(obj)
    for v in obj.data.vertices:
        t = clamp01((-v.co.z) / depth)
        v.co.x *= (1.0 - t * 0.22)
        v.co.y *= (1.0 - t * 0.22)
    _sub(obj, 1)
    return obj


# ── LOWER LIMB (forearm / shin) ────────────────────────────────
# Origin at joint (Z=0). Extends to Z=-0.40.
def build_lower_limb():
    _clear()
    depth = 0.40
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.082,
                                         depth=depth, location=(0, 0, -depth/2))
    obj = bpy.context.object; _apply(obj)
    for v in obj.data.vertices:
        t = clamp01((-v.co.z) / depth)
        v.co.x *= (1.0 - t * 0.18)
        v.co.y *= (1.0 - t * 0.18)
    _sub(obj, 1)
    return obj


# ── HAND (Gauntlet) ──────────────────────────────────────────────
# Origin at wrist (Z=0). Gauntlet cuff + knuckle plates.
def build_hand():
    _clear()
    # Cuff
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -0.048))
    cuff = bpy.context.object; cuff.scale = (0.10, 0.046, 0.058); _apply(cuff); _sub(cuff, 1)
    # Knuckle plate
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.014, -0.105))
    knuck = bpy.context.object; knuck.scale = (0.092, 0.018, 0.038); _apply(knuck)
    # Four finger segments
    for fx in [-0.033, -0.011, 0.011, 0.033]:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(fx, -0.014, -0.140))
        fg = bpy.context.object; fg.scale = (0.018, 0.014, 0.030); _apply(fg)
    # Thumb
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.058, -0.006, -0.076))
    th = bpy.context.object; th.scale = (0.020, 0.014, 0.028)
    th.rotation_euler = (0, math.radians(28), 0)
    _apply(th)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object


# ── FOOT (Sabaton — armoured boot) ──────────────────────────────
# Origin at ankle (Z=0). Sole at Z=-0.08, toe extends in -Y.
def build_foot():
    _clear()
    # Ankle guard
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.028, -0.040))
    ank = bpy.context.object; ank.scale = (0.098, 0.070, 0.050); _apply(ank); _sub(ank, 1)
    # Foot plate
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.095, -0.062))
    fp = bpy.context.object; fp.scale = (0.090, 0.068, 0.034); _apply(fp); _sub(fp, 1)
    # Toe cap (rounded)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6,
                                          radius=0.038, location=(0, -0.152, -0.060))
    tc = bpy.context.object; tc.scale = (1, 0.8, 0.55); _apply(tc)
    # Heel
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.040, -0.060))
    hl = bpy.context.object; hl.scale = (0.075, 0.036, 0.030); _apply(hl)
    # Plate ridges
    for py in [-0.048, -0.085, -0.118]:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, py, -0.050))
        rg = bpy.context.object; rg.scale = (0.092, 0.008, 0.012); _apply(rg)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bpy.context.active_object


# ── ROCK ────────────────────────────────────────────────────────
def build_rock():
    import random; random.seed(7)
    _clear()
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.45, location=(0,0,0))
    obj = bpy.context.object
    obj.scale = (random.uniform(0.9,1.3),random.uniform(0.7,1.1),random.uniform(0.38,0.58))
    _apply(obj)
    for v in obj.data.vertices:
        v.co.x+=random.uniform(-0.07,0.07)
        v.co.y+=random.uniform(-0.07,0.07)
        v.co.z+=random.uniform(-0.03,0.03)
    for v in obj.data.vertices:
        if v.co.z<-0.08: v.co.z=-0.08
    _sub(obj, 1)
    return obj
