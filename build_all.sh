#!/bin/bash
# File: build_all.sh
# EndlessRPG Unified Build Pipeline - Restored Functional State

set -e
echo "=========================================="
echo " EndlessRPG Build Pipeline - Restoring Legacy Pipeline"
echo "=========================================="

# 1. Setup directories
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/cpp/models
mkdir -p app/src/main/cpp/shaders
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p runtime/python
mkdir -p scripts

# 2. Ensure executables have permissions
chmod +x scripts/setup_project.sh
chmod +x runtime/generate_assets.sh
chmod +x runtime/generate_engine.sh

# 3. Execute the pipeline
echo "[1/3] Generating Android configurations and Overlay UI..."
./scripts/setup_project.sh

echo "[2/3] Generating 3D Models via Blender..."
./runtime/generate_assets.sh

echo "[3/3] Generating C++ Native Engine..."
./runtime/generate_engine.sh

echo "=========================================="
echo " Build Preparation Complete."
echo " Run './gradlew :app:assembleDebug' to compile."
echo "=========================================="
