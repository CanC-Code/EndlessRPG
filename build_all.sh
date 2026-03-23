#!/bin/bash
# File: build_all.sh

echo "Initializing EndlessRPG Build Pipeline..."

# 1. Clean and Prepare Directories
rm -rf app/src/main/assets/models
mkdir -p app/src/main/assets/models
mkdir -p app/src/main/cpp
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/res/layout
mkdir -p runtime/python
mkdir -p scripts

# 2. Grant Permissions
chmod +x scripts/setup_project.sh
chmod +x runtime/generate_engine.sh

# 3. Scaffold Android Architecture
echo "Generating Android and Gradle Configurations..."
./scripts/setup_project.sh

# 4. Generate High-Resolution 3D Models via Blender
# Using -noaudio to suppress ALSA headless driver warnings in GitHub Actions
echo "Baking Realistic 5-Fingered Player Anatomy..."
blender --background -noaudio --python runtime/build_models.py

echo "Baking Realistic Procedural Environmental Assets..."
blender --background -noaudio --python runtime/python/generate_realistic_assets.py

# 5. Generate C++ Procedural Engine
echo "Compiling C++ Procedural fBm Engine..."
./runtime/generate_engine.sh

echo "--------------------------------------------------------"
echo "Build environment perfectly prepared. Proceed with Gradle."
echo "--------------------------------------------------------"
