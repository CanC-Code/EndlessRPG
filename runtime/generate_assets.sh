#!/bin/bash
# File: runtime/generate_assets.sh
# Invokes Blender to bake all character and environment assets
# into app/src/main/cpp/models/AllModels.h.

set -e
mkdir -p app/src/main/cpp/models

echo "[generate_assets.sh] Baking models via Blender..."
blender --background -noaudio --python runtime/build_models.py

echo "[generate_assets.sh] Baking supplementary tree model..."
blender --background -noaudio --python runtime/python/generate_realistic_assets.py

echo "[generate_assets.sh] All assets baked."
