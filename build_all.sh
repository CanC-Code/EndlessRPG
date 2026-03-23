#!/bin/bash
# File: build_all.sh
# EndlessRPG Unified Build Pipeline

set -e
echo "=========================================="
echo " EndlessRPG Build Pipeline"
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
mkdir -p runtime/python
mkdir -p scripts

# 2. Grant Permissions
chmod +x scripts/setup_project.sh
chmod +x runtime/generate_engine.sh
chmod +x runtime/generate_assets.sh
chmod +x runtime/generate_shaders.sh
chmod +x runtime/generate_game.sh
chmod +x runtime/infill_game.sh

# 3. Scaffold Android Architecture
echo "[1/5] Generating Android and Gradle Configurations..."
./scripts/setup_project.sh

# 4. Generate 3D Models via Blender
echo "[2/5] Baking Realistic Character Models..."
blender --background -noaudio --python runtime/build_models.py

echo "[3/5] Baking Realistic Environmental Assets..."
blender --background -noaudio --python runtime/python/generate_realistic_assets.py

# 5. Generate shaders
echo "[4/5] Generating Photorealistic GLSL Shaders..."
./runtime/generate_shaders.sh

# 6. Generate C++ Engine
echo "[5/5] Compiling C++ Procedural Engine..."
./runtime/generate_engine.sh

echo ""
echo "=========================================="
echo " Build environment prepared. Run Gradle."
echo "=========================================="
