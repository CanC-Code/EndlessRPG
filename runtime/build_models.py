# File: runtime/build_models.py
# Blender Python script.
# Generates realistic character body parts and environment models,
# exports them as C++ vertex-color header arrays (pos + color, 6 floats/vertex).
# Coordinate system: Blender Z-up → OpenGL Y-up (swap Y/Z, negate original Y).

import bpy
import bmesh
from math import radians, sqrt


# ──────────────────────────────────────────────
# Core export utility
# ──────────────────────────────────────────────
def export_model(name: str, r: float, g: float, b: float, build_func, out_handle):
    """Build a mesh via build_func, triangulate, bake vertex colours with ambient
    occlusion approximation, and write a C array to out_handle."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    build_func()

    # Join all objects into one
    bpy.ops.object.select_all(action='SELECT')
    if len(bpy.context.selected_objects) > 1:
        bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
        bpy.ops.object.join()

    obj = bpy.context.active_object
    if obj is None or obj.type != 'MESH':
        return

    # Apply all modifiers so we export the final shape
    bpy.ops.object.convert(target='MESH')

    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    # Bounding box for AO approximation
    zs = [v.co.z for v in mesh.vertices]
    min_z = min(zs) if zs else 0.0
    height = max(zs) - min_z if zs else 1.0

    verts = []
    mesh.calc_loop_triangles()
    mesh.calc_normals_split()

    for tri in mesh.loop_triangles:
        for li in tri.loops:
            v  = mesh.vertices[mesh.loops[li].vertex_index]
            sn = mesh.loops[li].normal      # smooth normal

            # Diffuse shading from an overhead light direction (0.3,1,0.5 normalised)
            lx, ly, lz = 0.2357, 0.9428, 0.2357
            diff = max(sn.x * lx + sn.z * ly + (-sn.y) * lz, 0.0)
            shade = 0.35 + 0.65 * diff

            # AO: darken base of geometry
            ao = 0.55 + 0.45 * ((v.co.z - min_z) / height) if height > 0.001 else 1.0

            factor = shade * ao

            # Blender Z-up → OpenGL Y-up
            verts += [v.co.x, v.co.z, -v.co.y,
                      r * factor, g * factor, b * factor]

    count = len(verts) // 6
    out_handle.write(f"const float M_{name}[] = {{ {', '.join(f'{x:.5f}f' for x in verts)} }};\n")
    out_handle.write(f"const int   N_{name} = {count};\n\n")
    print(f"  Exported {name}: {count} triangles.")


# ──────────────────────────────────────────────
# Character body parts
# ──────────────────────────────────────────────
def build_torso():
    """Broad, slightly tapered torso with shoulder stumps."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=16, radius=0.30, depth=0.72, location=(0, 0, 0.36))
    torso = bpy.context.object
    torso.scale = (1.0, 0.75, 1.0)          # slightly flattened front-to-back
    bpy.ops.object.transform_apply(scale=True)
    sub = torso.modifiers.new("Sub", 'SUBSURF')
    sub.levels = 2; sub.render_levels = 2

def build_head():
    """Slightly oblate skull."""
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16, ring_count=12, radius=0.22, location=(0, 0, 0))
    h = bpy.context.object
    h.scale = (1.0, 0.88, 1.12)
    bpy.ops.object.transform_apply(scale=True)
    sub = h.modifiers.new("Sub", 'SUBSURF')
    sub.levels = 2

def build_upper_limb():
    """Upper arm / thigh — tapered cylinder with rounded ends."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.09, depth=0.38, location=(0, 0, -0.19))
    c = bpy.context.object
    sub = c.modifiers.new("Sub", 'SUBSURF')
    sub.levels = 1

def build_lower_limb():
    """Forearm / shin — slightly thinner than upper limb."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.075, depth=0.36, location=(0, 0, -0.18))
    c = bpy.context.object
    sub = c.modifiers.new("Sub", 'SUBSURF')
    sub.levels = 1

def build_foot():
    """Simple boot-shaped foot."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.05, 0, -0.07))
    f = bpy.context.object
    f.scale = (0.14, 0.08, 0.07)
    bpy.ops.object.transform_apply(scale=True)
    sub = f.modifiers.new("Sub", 'SUBSURF')
    sub.levels = 1


# ──────────────────────────────────────────────
# Weapons
# ──────────────────────────────────────────────
def build_sword():
    """Single-edged longsword: grip + guard + tapered blade."""
    # Grip
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.018, depth=0.22,
                                        location=(0, 0, -0.11))
    # Pommel
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.03, location=(0, 0, -0.24))
    # Cross-guard
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.01))
    g = bpy.context.object; g.scale = (0.17, 0.022, 0.036)
    bpy.ops.object.transform_apply(scale=True)
    # Blade (tapered box)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.60))
    b = bpy.context.object; b.scale = (0.018, 0.006, 0.60)
    bpy.ops.object.transform_apply(scale=True)

def build_shield():
    """Kite shield: cylinder disc with central boss."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.44, depth=0.028,
                                        location=(0, 0, 0))
    s = bpy.context.object; s.scale = (1.0, 1.35, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    sub = s.modifiers.new("Sub", 'SUBSURF'); sub.levels = 1
    # Boss
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(0, 0, 0.04))


# ──────────────────────────────────────────────
# Environment
# ──────────────────────────────────────────────
def build_tree():
    """Realistic deciduous tree: tapered trunk + layered canopy spheres."""
    import random; random.seed(42)
    # Trunk
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.16, depth=2.6,
                                        location=(0, 0, 1.3))
    t = bpy.context.object; t.scale = (1.0, 1.0, 1.0)
    sub = t.modifiers.new("S", 'SUBSURF'); sub.levels = 1
    # Canopy — 9 overlapping spheres at varied heights and offsets
    canopy_params = [
        (0.0,  0.0,  3.2, 1.10),
        ( 0.6,  0.4, 2.9, 0.78),
        (-0.5,  0.5, 3.0, 0.72),
        ( 0.3, -0.6, 2.8, 0.68),
        (-0.4, -0.3, 3.4, 0.60),
        ( 0.7, -0.2, 3.5, 0.55),
        (-0.6,  0.1, 3.6, 0.50),
        ( 0.0,  0.7, 3.7, 0.48),
        ( 0.0,  0.0, 4.0, 0.58),
    ]
    for cx, cy, cz, cr in canopy_params:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8,
                                             radius=cr, location=(cx, cy, cz))

def build_rock():
    """Weathered field rock — perturbed icosphere."""
    import random; random.seed(7)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.45,
                                         location=(0, 0, 0))
    r = bpy.context.object
    r.scale = (random.uniform(0.9, 1.3),
               random.uniform(0.7, 1.1),
               random.uniform(0.4, 0.6))
    bpy.ops.object.transform_apply(scale=True)
    # Perturb vertices
    for v in r.data.vertices:
        v.co.x += random.uniform(-0.04, 0.04)
        v.co.y += random.uniform(-0.04, 0.04)
        v.co.z += random.uniform(-0.025, 0.025)

def build_terrain_chunk():
    """Flat subdivided grid used as a single terrain tile."""
    bpy.ops.mesh.primitive_grid_add(
        x_subdivisions=24, y_subdivisions=24, size=16, location=(0, 0, 0))


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
if __name__ == "__main__":
    out_path = "app/src/main/cpp/models/AllModels.h"

    # Skin tones (warm beige) / armour (slate) / nature colours
    SKIN  = (0.82, 0.65, 0.50)
    CLOTH = (0.28, 0.32, 0.38)   # dark slate armour
    STEEL = (0.72, 0.74, 0.78)   # polished metal
    WOOD  = (0.42, 0.28, 0.14)   # shield wood
    BARK  = (0.28, 0.18, 0.09)   # tree trunk
    LEAF  = (0.15, 0.42, 0.12)   # canopy
    STONE = (0.46, 0.44, 0.42)   # rock
    EARTH = (0.30, 0.45, 0.22)   # terrain grass

    models = [
        ("TORSO",     *CLOTH,  build_torso),
        ("HEAD",      *SKIN,   build_head),
        ("UP_LIMB",   *CLOTH,  build_upper_limb),
        ("LOW_LIMB",  *CLOTH,  build_lower_limb),
        ("FOOT",      *CLOTH,  build_foot),
        ("SWORD",     *STEEL,  build_sword),
        ("SHIELD",    *WOOD,   build_shield),
        ("TREE",      *LEAF,   build_tree),    # uses mixed colours for trunk vs leaves
        ("ROCK",      *STONE,  build_rock),
        ("TERRAIN",   *EARTH,  build_terrain_chunk),
    ]

    print("EndlessRPG — Baking models…")
    with open(out_path, "w") as fh:
        fh.write("#pragma once\n// Auto-generated by runtime/build_models.py\n\n")
        for entry in models:
            name, r, g, b, func = entry[0], entry[1], entry[2], entry[3], entry[4]
            export_model(name, r, g, b, func, fh)

    print(f"\nAll models written to {out_path}")
