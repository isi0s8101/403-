#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
python3 tools/verify-j678-static.py
python3 tools/verify-recette-static.py
python3 tools/verify-fix082-static.py
if ! command -v "${GODOT_BIN:-godot}" >/dev/null 2>&1; then
 echo 'FIX082_GODOT_RESULT=NOT_RUN (Godot 4.7.x absent)' >&2
 exit 127
fi
./tools/verify-recette.sh
echo 'FIX082_GODOT_RESULT=PASS (tests headless ; physique Android toujours manuelle)'
