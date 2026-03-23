#!/bin/bash
# File: runtime/generate_game.sh
# Orchestrates full project generation.
# Calls setup_project.sh (Gradle/Manifest/Java/Layout),
# then generate_engine.sh (C++ native-lib).
# Run this instead of infill_game.sh — they are now unified.

set -e
echo "[generate_game.sh] Generating full EndlessRPG project..."

# Gradle + Android scaffold
./scripts/setup_project.sh

# C++ engine
./runtime/generate_engine.sh

echo "[generate_game.sh] Done. Run: ./gradlew assembleDebug"
