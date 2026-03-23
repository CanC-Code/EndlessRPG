#!/bin/bash
# File: runtime/generate_models.sh
# EndlessRPG v6 - High-Fidelity Voxel Generator with Baked AO & Normals
set -e

OUT="app/src/main/cpp/models/AllModels.h"
mkdir -p app/src/main/cpp/models

echo "// EndlessRPG Generated Models - v6" > $OUT
echo "#ifndef ALLMODELS_H" >> $OUT
echo "#define ALLMODELS_H" >> $OUT

# Helper: Generates a single Voxel with Normals and Ambient Occlusion (9 floats/vertex)
# Usage: voxel "Name" width height depth r g b
gen_voxel_data() {
    local NAME=$1
    local HW=$(echo "scale=4; $2/2" | bc)
    local HH=$(echo "scale=4; $3/2" | bc)
    local HD=$(echo "scale=4; $4/2" | bc)
    local CR=$5
    local CG=$6
    local CB=$7

    cat <<VEOF >> $OUT
const float M_${NAME}[] = {
    // Pos(3), Color(3), Normal(3)
    // FRONT (Normal: 0,0,1)
    -$HW,-$HH, $HD,  $CR,$CG,$CB,  0,0,1,  $HW,-$HH, $HD,  $CR,$CG,$CB,  0,0,1,  $HW, $HH, $HD,  $CR,$CG,$CB,  0,0,1,
    -$HW,-$HH, $HD,  $CR,$CG,$CB,  0,0,1,  $HW, $HH, $HD,  $CR,$CG,$CB,  0,0,1, -$HW, $HH, $HD,  $CR,$CG,$CB,  0,0,1,
    // BACK (Normal: 0,0,-1) - Darkened for Depth
    -$HW,-$HH,-$HD,  ${CR}*0.7,${CG}*0.7,${CB}*0.7,  0,0,-1,  $HW, $HH,-$HD,  ${CR}*0.7,${CG}*0.7,${CB}*0.7,  0,0,-1,  $HW,-$HH,-$HD,  ${CR}*0.7,${CG}*0.7,${CB}*0.7,  0,0,-1,
    -$HW,-$HH,-$HD,  ${CR}*0.7,${CG}*0.7,${CB}*0.7,  0,0,-1, -$HW, $HH,-$HD,  ${CR}*0.7,${CG}*0.7,${CB}*0.7,  0,0,-1,  $HW, $HH,-$HD,  ${CR}*0.7,${CG}*0.7,${CB}*0.7,  0,0,-1,
    // TOP (Normal: 0,1,0) - Highlighted (Sun)
    -$HW, $HH, $HD,  ${CR}*1.1,${CG}*1.1,${CB}*1.1,  0,1,0,   $HW, $HH, $HD,  ${CR}*1.1,${CG}*1.1,${CB}*1.1,  0,1,0,   $HW, $HH,-$HD,  ${CR}*1.1,${CG}*1.1,${CB}*1.1,  0,1,0,
    -$HW, $HH, $HD,  ${CR}*1.1,${CG}*1.1,${CB}*1.1,  0,1,0,   $HW, $HH,-$HD,  ${CR}*1.1,${CG}*1.1,${CB}*1.1,  0,1,0,  -$HW, $HH,-$HD,  ${CR}*1.1,${CG}*1.1,${CB}*1.1,  0,1,0,
    // BOTTOM (Normal: 0,-1,0) - AO Shadows
    -$HW,-$HH, $HD,  ${CR}*0.4,${CG}*0.4,${CB}*0.4,  0,-1,0,  $HW,-$HH,-$HD,  ${CR}*0.4,${CG}*0.4,${CB}*0.4,  0,-1,0,  $HW,-$HH, $HD,  ${CR}*0.4,${CG}*0.4,${CB}*0.4,  0,-1,0,
    -$HW,-$HH, $HD,  ${CR}*0.4,${CG}*0.4,${CB}*0.4,  0,-1,0, -$HW,-$HH,-$HD,  ${CR}*0.4,${CG}*0.4,${CB}*0.4,  0,-1,0,  $HW,-$HH,-$HD,  ${CR}*0.4,${CG}*0.4,${CB}*0.4,  0,-1,0,
    // LEFT (Normal: -1,0,0)
    -$HW, $HH, $HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8, -1,0,0,  -$HW,-$HH,-$HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8, -1,0,0,  -$HW, $HH,-$HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8, -1,0,0,
    -$HW, $HH, $HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8, -1,0,0,  -$HW,-$HH, $HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8, -1,0,0,  -$HW,-$HH,-$HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8, -1,0,0,
    // RIGHT (Normal: 1,0,0)
     $HW, $HH, $HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8,  1,0,0,   $HW, $HH,-$HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8,  1,0,0,   $HW,-$HH,-$HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8,  1,0,0,
     $HW, $HH, $HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8,  1,0,0,   $HW,-$HH,-$HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8,  1,0,0,   $HW,-$HH, $HD,  ${CR}*0.8,${CG}*0.8,${CB}*0.8,  1,0,0
};
const int N_${NAME} = 36;
VEOF
}

echo "[generate_models.sh] Generating character parts..."
gen_voxel_data "HEAD"     0.6 0.6 0.6  0.92 0.75 0.65  # Skin tone
gen_voxel_data "TORSO"    0.8 1.0 0.5  0.20 0.40 0.80  # Tunic Blue
gen_voxel_data "UP_LIMB"  0.3 0.6 0.3  0.22 0.42 0.82  # Sleeve Blue
gen_voxel_data "LOW_LIMB" 0.28 0.6 0.28 0.92 0.75 0.65 # Skin tone
gen_voxel_data "HAND"     0.25 0.25 0.25 0.92 0.75 0.65
gen_voxel_data "FOOT"     0.3 0.2 0.5  0.30 0.20 0.10  # Boot brown

echo "[generate_models.sh] Generating world objects..."
gen_voxel_data "TREE"     1.0 4.0 1.0  0.40 0.25 0.15  # Trunk
gen_voxel_data "ROCK"     1.2 0.8 1.2  0.50 0.52 0.55  # Stone Gray
gen_voxel_data "SWORD"    0.1 1.2 0.25 0.80 0.82 0.85  # Steel
gen_voxel_data "SHIELD"   0.7 0.9 0.15 0.55 0.35 0.15  # Wood/Bronze

echo "#endif" >> $OUT
echo "[generate_models.sh] Success: AllModels.h (V6 High-Fidelity)"
