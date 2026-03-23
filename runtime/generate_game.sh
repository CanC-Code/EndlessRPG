#!/bin/bash
# File: runtime/generate_game.sh
# Canonical full-project orchestrator.
set -e
./scripts/setup_project.sh
./runtime/generate_engine.sh
echo "[generate_game.sh] Done."
