#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
./tools/verify-j9-complete.sh
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p build
APK='build/sillons-empire-j9-debug-0.9.1.apk'
"$GODOT_BIN" --headless --path . --export-debug Android "$APK"
test -s "$APK"
sha256sum "$APK"
echo 'APK_EXPORT=PASS ; VALIDATION_S25_ULTRA=NOT_RUN'
