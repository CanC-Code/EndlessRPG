#!/bin/bash
# File: build_all.sh
# Purpose: Master Execution Pipeline for the Realistic 3D RPG

# 1. Clean up old legacy files to prevent conflicts
rm -f runtime/build_models.py

# 2. Setup directories
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/cpp/models
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p runtime/python
mkdir -p scripts

# 3. Ensure executables have permissions
chmod +x scripts/setup_project.sh
chmod +x runtime/generate_assets.sh
chmod +x runtime/generate_engine.sh

# 4. Execute the pipeline
./scripts/setup_project.sh
./runtime/generate_assets.sh
./runtime/generate_engine.sh
