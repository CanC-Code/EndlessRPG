#!/bin/bash
# File: build_all.sh
# Purpose: Master Execution Pipeline for the Enhanced 3D RPG

mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/cpp/models
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p runtime/python
mkdir -p scripts

chmod +x scripts/setup_project.sh
chmod +x runtime/generate_assets.sh
chmod +x runtime/generate_engine.sh

./scripts/setup_project.sh
./runtime/generate_assets.sh
./runtime/generate_engine.sh
