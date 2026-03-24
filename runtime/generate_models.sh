#!/bin/bash
# File: runtime/generate_models.sh
set -e
OUT="app/src/main/cpp/models/AllModels.h"
echo "#ifndef ALLMODELS_H" > $OUT
echo "#define ALLMODELS_H" >> $OUT

gen_mesh() {
    local NAME=$1; local STACKS=$2; local SECTORS=$3
    local RAD=$4; local HEIGHT=$5
    local R=$6; local G=$7; local B=$8
    echo "const float M_${NAME}[] = {" >> $OUT
    python3 <<PYEOF >> $OUT
import math
for i in range($STACKS):
    lat1, lat2 = math.pi*i/$STACKS, math.pi*(i+1)/$STACKS
    for j in range($SECTORS):
        lon1, lon2 = 2*math.pi*j/$SECTORS, 2*math.pi*(j+1)/$SECTORS
        for la, lo in [(lat1,lon1),(lat2,lon1),(lat2,lon2),(lat1,lon1),(lat2,lon2),(lat1,lon2)]:
            nx, ny, nz = math.sin(la)*math.cos(lo), math.cos(la), math.sin(la)*math.sin(lo)
            y_off = ($HEIGHT/2.0) if ny > 0 else (-$HEIGHT/2.0)
            print(f"{nx*$RAD},{ny*$RAD+y_off},{nz*$RAD}, $R,$G,$B, {nx},{ny},{nz},")
PYEOF
    echo "}; const int N_${NAME} = $(($STACKS * $SECTORS * 6));" >> $OUT
}

echo "[generate_models.sh] Baking Meshes..."
gen_mesh "HEAD"   12 12 0.35 0.0  0.9 0.7 0.6
gen_mesh "BODY"   12 12 0.45 0.8  0.2 0.4 0.8
gen_mesh "LIMB"   8  8  0.15 0.6  0.9 0.7 0.6
gen_mesh "SWORD"  6  6  0.05 1.2  0.8 0.8 0.9
gen_mesh "SHIELD" 12 4  0.50 0.1  0.5 0.3 0.1
echo "#endif" >> $OUT
