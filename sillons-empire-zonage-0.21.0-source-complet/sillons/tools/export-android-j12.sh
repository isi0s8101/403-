#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
./tools/verify-j12.sh
GODOT_BIN="${GODOT_BIN:-godot}"
APK='build/sillons-empire-j12-debug-0.12.3.apk'
mkdir -p build
"$GODOT_BIN" --headless --path . --export-debug Android "$APK"
test -s "$APK"
sha256sum "$APK"
printf '%s\n' 'J12_ANDROID_EXPORT=PASS ; RECETTE_GALAXY_S25_ULTRA=NOT_RUN'
