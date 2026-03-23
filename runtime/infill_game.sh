#!/bin/bash
# File: runtime/infill_game.sh — delegates to generate_game.sh
set -e
exec "$(dirname "$0")/generate_game.sh" "$@"
