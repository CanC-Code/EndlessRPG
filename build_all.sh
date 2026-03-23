#!/bin/bash
# File: build_all.sh
# EndlessRPG Unified Build Pipeline v4 - Clean Model Generation

set -e
echo "=========================================="
echo " EndlessRPG Build Pipeline v4"
echo "=========================================="

# 1. Clean and Prepare Directories
mkdir -p app/src/main/cpp/models
mkdir -p app/src/main/cpp/shaders
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout

# 2. Grant Permissions
chmod +x scripts/setup_project.sh
chmod +x runtime/generate_models.sh
chmod +x runtime/generate_shaders.sh
chmod +x runtime/generate_engine.sh

# 3. Scaffold Android Architecture
echo "[1/4] Generating Android configurations..."
./scripts/setup_project.sh

# 4. Generate 3D Models (REPLACED Blender with Shell Generator)
echo "[2/4] Generating 3D Voxel Models..."
./runtime/generate_models.sh

# 5. Generate Shaders
echo "[3/4] Generating Shaders..."
./runtime/generate_shaders.sh

# 6. Generate C++ Engine
echo "[4/4] Generating C++ Native Engine..."
./runtime/generate_engine.sh

echo "=========================================="
echo " Build Preparation Complete."
echo " Run './gradlew :app:assembleDebug' to compile."
echo "=========================================="
