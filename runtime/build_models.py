import bpy
import random
from math import radians

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def export_voxel_model(name, r, g, b, build_func):
    clean()
    build_func()
    
    # Ensure all objects are flat-shaded for the pixel art look
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            for poly in obj.data.polygons:
                poly.use_smooth = False

    bpy.ops.object.select_all(action='SELECT')
    if len(bpy.context.selected_objects) > 1:
        bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
        bpy.ops.object.join()
        
    obj = bpy.context.object
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)
    
    verts = []
    mesh = obj.data
    min_z = min((v.co.z for v in mesh.vertices), default=0)
    height = max((v.co.z for v in mesh.vertices), default=1) - min_z
    mesh.calc_loop_triangles()

    for tri in mesh.loop_triangles:
        # Use FACE normal for flat voxel shading, not vertex normal
        face_norm = tri.normal
        lum = 0.5 + (face_norm.z * 0.4) + (face_norm.x * 0.1)
        
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            
            # Y-up conversion
            verts.extend([v.co.x, v.co.z, -v.co.y])
            
            # Ground Ambient Occlusion (darker at the bottom)
            ao = 0.4 + (0.6 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            
            # Apply slight color jitter per face for pixel-art texture
            jitter = random.uniform(0.95, 1.05)
            final_r = max(0, min(1, r * lum * ao * jitter))
            final_g = max(0, min(1, g * lum * ao * jitter))
            final_b = max(0, min(1, b * lum * ao * jitter))
            
            verts.extend([final_r, final_g, final_b])
            
    return verts

# --- VOXEL / PIXEL-ART MODULES ---

def build_hero_armour():
    # Iron Blocky Body
    bpy.ops.mesh.primitive_cube_add(size=0.6, location=(0, 0, 0.7))
    # Silver Shoulder Pads
    bpy.ops.mesh.primitive_cube_add(size=0.25, location=(0.35, 0, 0.9))
    bpy.ops.mesh.primitive_cube_add(size=0.25, location=(-0.35, 0, 0.9))
    # Blocky Helmet with Visor slit
    bpy.ops.mesh.primitive_cube_add(size=0.45, location=(0, 0, 1.3))

def build_enemy():
    # Orc/Goblin Blocky Body
    bpy.ops.mesh.primitive_cube_add(size=0.6, location=(0, 0, 0.6))
    bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0, 0, 1.1))

def build_pixel_sword():
    # Hilt
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0.4, 0.4, 0.9))
    # Crossguard
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(0.4, 0.4, 1.0))
    bpy.context.object.scale = (1.0, 0.2, 0.2)
    # Blocky Blade
    bpy.ops.mesh.primitive_cube_add(size=0.15, location=(0.4, 0.4, 1.3))
    bpy.context.object.scale = (0.5, 0.2, 3.0)
    bpy.context.object.rotation_euler = (radians(90), 0, 0)

def build_pixel_shield():
    # Heater shield made of intersecting cubes
    bpy.ops.mesh.primitive_cube_add(size=0.6, location=(-0.4, 0.3, 0.9))
    bpy.context.object.scale = (1.0, 0.1, 1.2)
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=(-0.4, 0.35, 0.9)) # Iron boss
    bpy.context.object.scale = (1.0, 0.2, 1.0)
    
def build_voxel_tree():
    # Square Trunk
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(0, 0, 0.5))
    bpy.context.object.scale = (1.0, 1.0, 3.0)
    # Staggered Leaf Blocks (Minecraft style)
    bpy.ops.mesh.primitive_cube_add(size=1.2, location=(0, 0, 1.8))
    bpy.ops.mesh.primitive_cube_add(size=0.8, location=(0, 0, 2.4))

def build_voxel_rock():
    bpy.ops.mesh.primitive_cube_add(size=0.6, location=(0, 0, 0.3))
    bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0.2, 0.2, 0.2))

# --- EXPORT PIPELINE ---
models = [
    ("HERO", 0.8, 0.8, 0.85, build_hero_armour),   # Silver Armour
    ("ENEMY", 0.3, 0.6, 0.2, build_enemy),         # Green Skin
    ("SWORD", 0.6, 0.9, 0.9, build_pixel_sword),   # Diamond/Steel Blue
    ("SHIELD", 0.4, 0.2, 0.1, build_pixel_shield), # Wood Brown
    ("TREE", 0.2, 0.7, 0.2, build_voxel_tree),     # Vibrant Green
    ("ROCK", 0.5, 0.5, 0.5, build_voxel_rock)      # Gray
]

with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    for name, r, g, b, func in models:
        data = export_voxel_model(name, r, g, b, func)
        f.write(f"const float M_{name}[] = {{ {', '.join(f'{v:.4f}f' for v in data)} }};\n")
        f.write(f"const int N_{name} = {len(data)//6};\n")
