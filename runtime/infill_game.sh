#!/bin/bash
# File: runtime/infill_game.sh
# Kept for backward compatibility. Delegates to generate_game.sh.
set -e
exec "$(dirname "$0")/generate_game.sh" "$@"
