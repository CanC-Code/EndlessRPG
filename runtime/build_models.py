import bpy
import bmesh
import random
from math import radians

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def export_model(name, r, g, b, build_func):
    clean()
    build_func()
    obj = bpy.context.object
    
    # Finalize Mesh: Triangulate for OpenGL compatibility
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)
    
    verts = []
    mesh = obj.data
    mesh.calc_loop_triangles()
    
    # Calculate bounds for ground-based AO
    min_z = min((v.co.z for v in mesh.vertices), default=0)
    max_z = max((v.co.z for v in mesh.vertices), default=1)
    height = max_z - min_z

    for tri in mesh.loop_triangles:
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            
            # 1. Position: Convert Blender Z-up to OpenGL Y-up
            verts.extend([v.co.x, v.co.z, -v.co.y])
            
            # 2. Advanced Shading: Combined Normal-based Lum and Ground AO
            # Normals provide directional light; Height provides fake Ambient Occlusion
            norm_lum = 0.6 + (v.normal.z * 0.3) + (v.normal.x * 0.1)
            ground_ao = 0.5 + (0.5 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            
            # 3. Color Jitter: Small random variance for "organic" feel
            jitter = random.uniform(0.95, 1.05)
            
            final_r = max(0, min(1, r * norm_lum * ground_ao * jitter))
            final_g = max(0, min(1, g * norm_lum * ground_ao * jitter))
            final_b = max(0, min(1, b * norm_lum * ground_ao * jitter))
            
            verts.extend([final_r, final_g, final_b])
            
    return verts

# --- MODULAR ASSET DEFINITIONS ---

def build_body():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=0.8, location=(0,0,0.8))

def build_head():
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.25, location=(0,0,1.5))

def build_cape():
    # Beveled Cube for a thicker, high-quality cape
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0,-0.2,0.9))
    obj = bpy.context.object
    obj.scale = (0.3, 0.05, 0.6)
    obj.rotation_euler = (radians(-15), 0, 0)
    bpy.ops.object.modifier_add(type='BEVEL')
    obj.modifiers["Bevel"].width = 0.02

def build_sword():
    # Multi-part Sword (Blade + Crossguard)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=1.0, location=(0.4, 0.4, 1.1))
    bpy.context.object.rotation_euler = (radians(90), 0, 0)
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=(0.4, 0.15, 1.1))
    bpy.context.object.scale = (1.5, 0.2, 0.5)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()

def build_shield():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.1, location=(-0.4, 0.3, 0.9))
    bpy.context.object.rotation_euler = (radians(90), radians(90), 0)

def build_tree():
    # Organic Low-poly Tree
    bpy.ops.mesh.primitive_cylinder_add(radius=0.15, depth=1.0, location=(0,0,0.5))
    trunk = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(radius1=0.8, depth=1.5, location=(0,0,1.8))
    foliage1 = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(radius1=0.6, depth=1.2, location=(0,0,2.5))
    foliage2 = bpy.context.object
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()

def build_rock():
    # Randomized Rock Geometry
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.4, location=(0,0,0.2))
    obj = bpy.context.object
    # Apply non-uniform scale for rock variation
    obj.scale = (random.uniform(0.8, 1.2), random.uniform(0.8, 1.2), random.uniform(0.5, 0.8))
    # Displace vertices slightly for "jagged" look
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for v in bm.verts:
        v.co += v.normal * random.uniform(-0.1, 0.1)
    bm.to_mesh(obj.data)
    bm.free()

def build_bush():
    # Clustered Sphere Bush
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.4, location=(0,0,0.3))
    main = bpy.context.object
    for i in range(3):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.3, 
            location=(random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), 0.2))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()

# --- EXPORT PIPELINE ---

models_to_build = [
    ("BODY", 0.15, 0.35, 0.8, build_body),   # Tunic Blue
    ("HEAD", 0.9, 0.75, 0.65, build_head),   # Skin Tone
    ("CAPE", 0.7, 0.1, 0.1, build_cape),     # Crimson
    ("SWORD", 0.7, 0.7, 0.8, build_sword),   # Steel
    ("SHIELD", 0.4, 0.25, 0.15, build_shield),# Wood
    ("TREE", 0.1, 0.4, 0.1, build_tree),     # Forest Green
    ("ROCK", 0.4, 0.4, 0.45, build_rock),    # Stone Gray
    ("BUSH", 0.2, 0.5, 0.1, build_bush)      # Bright Leaf Green
]

with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n\n")
    for name, r, g, b, func in models_to_build:
        data = export_model(name, r, g, b, func)
        f.write(f"const float M_{name}[] = {{ {', '.join(f'{v:.4f}f' for v in data)} }};\n")
        f.write(f"const int N_{name} = {len(data)//6};\n\n")

print("High-Fidelity Models successfully exported to app/src/main/cpp/GeneratedModels.h")
