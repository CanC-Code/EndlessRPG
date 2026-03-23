#!/bin/bash
# File: runtime/generate_models.sh

mkdir -p app/src/main/cpp/models

cat << 'EOF' > app/src/main/cpp/models/AllModels.h
#ifndef ALL_MODELS_H
#define ALL_MODELS_H

#define BOX_VERTS(w, h, d) { \
    -w,h,d, 0,0,1, w,h,d, 0,0,1, -w,-h,d, 0,0,1, w,h,d, 0,0,1, w,-h,d, 0,0,1, -w,-h,d, 0,0,1, \
    -w,h,-d, 0,0,-1, -w,-h,-d, 0,0,-1, w,h,-d, 0,0,-1, w,h,-d, 0,0,-1, -w,-h,-d, 0,0,-1, w,-h,-d, 0,0,-1, \
    -w,h,d, -1,0,0, -w,h,-d, -1,0,0, -w,-h,d, -1,0,0, -w,h,-d, -1,0,0, -w,-h,-d, -1,0,0, -w,-h,d, -1,0,0, \
    w,h,d, 1,0,0, w,-h,d, 1,0,0, w,h,-d, 1,0,0, w,h,-d, 1,0,0, w,-h,d, 1,0,0, w,-h,-d, 1,0,0, \
    -w,h,d, 0,1,0, -w,h,-d, 0,1,0, w,h,d, 0,1,0, -w,h,-d, 0,1,0, w,h,-d, 0,1,0, w,h,d, 0,1,0, \
    -w,-h,d, 0,-1,0, w,-h,d, 0,-1,0, -w,-h,-d, 0,-1,0, w,-h,d, 0,-1,0, w,-h,-d, 0,-1,0, -w,-h,-d, 0,-1,0 }

// Player Proportions
static const float M_TORSO[]    = BOX_VERTS(0.20f, 0.30f, 0.10f);
static const float M_HEAD[]     = BOX_VERTS(0.15f, 0.15f, 0.15f);
static const float M_LIMB[]     = BOX_VERTS(0.08f, 0.22f, 0.08f);
static const float M_SWORD[]    = BOX_VERTS(0.02f, 0.40f, 0.05f);
static const float M_SHIELD[]   = BOX_VERTS(0.25f, 0.30f, 0.04f);

// Environment
static const float M_TREE_TRUNK[]= BOX_VERTS(0.15f, 1.0f, 0.15f);
static const float M_TREE_LEAVES[]= BOX_VERTS(0.6f, 0.8f, 0.6f);
static const float M_ROCK[]     = BOX_VERTS(0.40f, 0.25f, 0.40f);
static const float M_GROUND[]   = BOX_VERTS(40.0f, 0.1f, 40.0f);

#define N_CUBE 36

#endif
EOF
echo "[Models] Generated AllModels.h (bypassing Blender for core structural assets)"
