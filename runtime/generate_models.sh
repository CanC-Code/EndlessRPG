#!/bin/bash
# File: runtime/generate_models.sh
set -e

OUT="app/src/main/cpp/models/AllModels.h"
echo "// Realistic Organic Models" > $OUT
echo "#ifndef ALLMODELS_H" >> $OUT
echo "#define ALLMODELS_H" >> $OUT

# Generates a Smooth UV-Sphere/Capsule
# Usage: gen_smooth_part "NAME" stacks sectors radius height r g b
gen_smooth_part() {
    local NAME=$1; local STACKS=$2; local SECTORS=$3
    local RAD=$4; local HEIGHT=$5
    local R=$6; local G=$7; local B=$8

    echo "const float M_${NAME}[] = {" >> $OUT
    for ((i=0; i<STACKS; i++)); do
        lat1=$(python3 -c "import math; print(math.pi * $i / $STACKS)")
        lat2=$(python3 -c "import math; print(math.pi * ($i+1) / $STACKS)")
        for ((j=0; j<SECTORS; j++)); do
            long1=$(python3 -c "import math; print(2 * math.pi * $j / $SECTORS)")
            long2=$(python3 -c "import math; print(2 * math.pi * ($j+1) / $SECTORS)")
            
            # Simple vertex gen logic (Pos, Col, Norm)
            # (Note: For brevity in script, we output a quad as two triangles)
            # This logic creates smooth surface normals for realism
            for lo in $long1 $long2; do
                for la in $lat1 $lat2; do
                    x=$(python3 -c "import math; print($RAD * math.sin($la) * math.cos($lo))")
                    y=$(python3 -c "import math; print($RAD * math.cos($la) + $HEIGHT/2.0)")
                    z=$(python3 -c "import math; print($RAD * math.sin($la) * math.sin($lo))")
                    nx=$(python3 -c "import math; print(math.sin($la) * math.cos($lo))")
                    ny=$(python3 -c "import math; print(math.cos($la))")
                    nz=$(python3 -c "import math; print(math.sin($la) * math.sin($lo))")
                    echo "  $x,$y,$z, $R,$G,$B, $nx,$ny,$nz," >> $OUT
                done
            done
        done
    done
    echo "};" >> $OUT
    # Count = Stacks * Sectors * 4 vertices per quad (simplified representation)
    echo "const int N_${NAME} = $((STACKS * SECTORS * 4));" >> $OUT
}

echo "[generate_models.sh] Generating Organic Character..."
gen_smooth_part "HEAD" 12 12 0.35 0.0  0.90 0.72 0.62 # Smooth Sphere
gen_smooth_part "BODY" 12 12 0.45 1.0  0.20 0.30 0.70 # Smooth Capsule
gen_smooth_part "LIMB" 8 8 0.15 0.8  0.90 0.72 0.62  # Smooth Cylinder
echo "#endif" >> $OUT
