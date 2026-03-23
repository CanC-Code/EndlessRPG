#!/bin/bash
# File: runtime/generate_assets.sh
# Bakes all models via Blender using the modular model scripts.
set -e
mkdir -p app/src/main/cpp/models
echo "[generate_assets.sh] Baking models..."
blender --background -noaudio --python runtime/build_models.py
echo "[generate_assets.sh] Done."
