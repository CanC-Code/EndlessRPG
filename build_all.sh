#!/bin/bash
# File: build_all.sh

# 1. Prepare asset directories
rm -rf app/src/main/assets/models
mkdir -p app/src/main/assets/models
mkdir -p runtime/python
mkdir -p scripts

# 2. Run Project Setup (Generates Gradle/Java/XML)
chmod +x scripts/setup_project.sh
./scripts/setup_project.sh

# 3. Generate Realistic Models (Character & Environment)
# Uses Blender to bake anatomy and nature assets
blender --background --python runtime/build_models.py
blender --background --python runtime/python/generate_realistic_assets.py

# 4. Generate C++ Engine
chmod +x runtime/generate_engine.sh
./runtime/generate_engine.sh

echo "--------------------------------------------------------"
echo "Build environment prepared. You can now run gradlew."
echo "--------------------------------------------------------"
