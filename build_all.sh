#!/bin/bash
echo "Starting Master Build Pipeline..."

# 1. Setup Directories
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/cpp/models
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p runtime/python
mkdir -p scripts

# 2. Make sub-scripts executable
chmod +x scripts/setup_project.sh
chmod +x runtime/generate_assets.sh
chmod +x runtime/generate_engine.sh

# 3. Execute Pipeline
./scripts/setup_project.sh
./runtime/generate_assets.sh
./runtime/generate_engine.sh

echo "Project Generation Complete. Ready for Gradle Build!"
