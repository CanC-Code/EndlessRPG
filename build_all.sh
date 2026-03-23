#!/bin/bash
# File: build_all.sh
# EndlessRPG Unified Build Pipeline v3

set -e
echo "=========================================="
echo " EndlessRPG Build Pipeline v3"
echo "=========================================="

# 1. Clean and Prepare Directories
rm -rf app/src/main/assets/models
mkdir -p app/src/main/assets/models
mkdir -p app/src/main/assets/shaders
mkdir -p app/src/main/cpp/models
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p runtime/models/equipment
mkdir -p runtime/python
mkdir -p scripts

# 2. Grant Permissions
chmod +x scripts/setup_project.sh
chmod +x runtime/generate_engine.sh
chmod +x runtime/generate_assets.sh
chmod +x runtime/generate_shaders.sh
chmod +x runtime/generate_game.sh
chmod +x runtime/infill_game.sh

# 3. Scaffold Android Architecture (Gradle, Manifest, Layout, Java)
echo "[1/4] Generating Android configurations..."
./scripts/setup_project.sh

# 4. Bake all 3D models via Blender (modular model scripts)
echo "[2/4] Baking 3D models via Blender..."
blender --background -noaudio --python runtime/build_models.py

# 5. Generate reference shaders (also embedded in engine)
echo "[3/4] Generating GLSL shaders..."
./runtime/generate_shaders.sh

# 6. Generate C++ engine
echo "[4/4] Generating C++ engine..."
./runtime/generate_engine.sh

echo ""
echo "=========================================="
echo " Build environment prepared."
echo " Run: ./gradlew assembleDebug"
echo "=========================================="
