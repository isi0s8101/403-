#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
bash ./tools/verify-refonte.sh
GODOT_BIN="${GODOT_BIN:-godot}"
APK='build/sillons-empire-j13-debug-0.14.0.apk'
mkdir -p build
"$GODOT_BIN" --headless --path . --export-debug Android "$APK"
test -s "$APK"
sha256sum "$APK"
printf '%s\n' 'J13_ANDROID_EXPORT=PASS ; RECETTE_GALAXY_S25_ULTRA=NOT_RUN'
