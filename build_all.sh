#!/bin/bash
# File: build_all.sh

# 1. Clean up old build artifacts
rm -rf app/src/main/assets/models
mkdir -p app/src/main/assets/models

# 2. Setup project structure and Android files
chmod +x scripts/setup_project.sh
./scripts/setup_project.sh

# 3. Generate Realistic Character Models
# This calls the Blender script for the 5-finger character and sword
blender --background --python runtime/build_models.py

# 4. Generate High-Resolution Environment Assets
# This utilizes the realistic assets script for trees/grass
blender --background --python runtime/python/generate_realistic_assets.py

# 5. Generate the C++ Engine Code
chmod +x runtime/generate_engine.sh
./runtime/generate_engine.sh

echo "Build Pipeline Complete. You can now run ./gradlew :app:assembleDebug"
