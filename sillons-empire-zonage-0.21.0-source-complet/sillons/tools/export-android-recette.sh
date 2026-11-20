#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo 'RECETTE_ANDROID_EXPORT=SKIP (Godot 4 introuvable)' >&2
  exit 127
fi
./tools/verify-recette.sh
mkdir -p build
APK=build/sillons-recette-debug-0.8.2.apk
"$GODOT_BIN" --headless --path . --export-debug Android "$APK"
if [[ ! -s "$APK" ]]; then
  echo 'RECETTE_ANDROID_EXPORT=FAIL (APK absent)' >&2
  exit 1
fi
printf 'RECETTE_ANDROID_EXPORT=GENERATED %s\n' "$APK"
