#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  printf '%s\n' 'SKIP: binaire Godot 4 absent (définir GODOT_BIN)' >&2
  exit 127
fi
# Le SDK Android, le JDK et les templates d'export doivent déjà être installés/configurés.
./tools/verify-j678.sh
mkdir -p build
"$GODOT_BIN" --headless --export-debug Android build/sillons-j678-debug-0.8.0.apk
if [[ ! -s build/sillons-j678-debug-0.8.0.apk ]]; then
  echo 'J678_APK_RESULT=FAIL_MISSING_OUTPUT' >&2
  exit 1
fi
printf 'J678_APK_RESULT=GENERATED %s\n' 'build/sillons-j678-debug-0.8.0.apk'
