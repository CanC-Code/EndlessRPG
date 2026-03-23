#!/bin/bash
# File: runtime/generate_shaders.sh
# Writes reference GLSL shader files to assets/shaders/.
# The engine also embeds these inline in native-lib.cpp.
set -e
mkdir -p app/src/main/assets/shaders
echo "// World vertex shader — see native-lib.cpp WORLD_VS" \
     > app/src/main/assets/shaders/world_vert.glsl
echo "// World fragment shader — see native-lib.cpp WORLD_FS" \
     > app/src/main/assets/shaders/world_frag.glsl
echo "// Sky vertex shader — see native-lib.cpp SKY_VS" \
     > app/src/main/assets/shaders/sky_vert.glsl
echo "// Sky fragment shader — see native-lib.cpp SKY_FS" \
     > app/src/main/assets/shaders/sky_frag.glsl
echo "[generate_shaders.sh] Reference shaders written."
