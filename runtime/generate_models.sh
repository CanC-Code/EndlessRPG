#!/bin/bash
# File: runtime/generate_models.sh
set -e

OUT="app/src/main/cpp/models/AllModels.h"
echo "// Realistic Organic Meshes" > $OUT
echo "#ifndef ALLMODELS_H" >> $OUT
echo "#define ALLMODELS_H" >> $OUT

# Helper: Generates a smooth UV-sphere/Capsule mesh
# Usage: gen_organic "NAME" stacks sectors radius height r g b
gen_organic() {
    local NAME=$1; local STACKS=$2; local SECTORS=$3
    local RAD=$4; local HEIGHT=$5
    local R=$6; local G=$7; local B=$8

    echo "const float M_${NAME}[] = {" >> $OUT
    # Geometry generation logic using Python for precision math
    python3 <<PYEOF >> $OUT
import math
stacks = $STACKS; sectors = $SECTORS
radius = $RAD; height = $HEIGHT
r, g, b = $R, $G, $B

for i in range(stacks):
    lat1 = math.pi * i / stacks
    lat2 = math.pi * (i + 1) / stacks
    for j in range(sectors):
        long1 = 2 * math.pi * j / sectors
        long2 = 2 * math.pi * (j + 1) / sectors
        
        # Two triangles per quad
        for la, lo in [(lat1, long1), (lat2, long1), (lat2, long2), (lat1, long1), (lat2, long2), (lat1, long2)]:
            nx = math.sin(la) * math.cos(lo)
            ny = math.cos(la)
            nz = math.sin(la) * math.sin(lo)
            # Add height for capsule effect
            y_off = (height / 2.0) if ny > 0 else (-height / 2.0)
            print(f"{nx*radius},{ny*radius + y_off},{nz*radius}, {r},{g},{b}, {nx},{ny},{nz},")
PYEOF
    echo "};" >> $OUT
    echo "const int N_${NAME} = $((STACKS * SECTORS * 6));" >> $OUT
}

echo "[generate_models.sh] Generating Realistic Character Geometry..."
gen_organic "HEAD" 16 16 0.35 0.0  0.90 0.72 0.62 # Skin
gen_organic "BODY" 16 16 0.45 0.8  0.15 0.25 0.65 # Tunic
gen_organic "LIMB" 12 12 0.15 0.6  0.90 0.72 0.62 # Skin
echo "#endif" >> $OUT
