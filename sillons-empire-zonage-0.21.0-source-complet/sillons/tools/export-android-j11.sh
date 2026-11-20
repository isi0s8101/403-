#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
./tools/verify-j11.sh
GODOT_BIN="${GODOT_BIN:-godot}"
APK='build/sillons-empire-j11-debug-0.11.0.apk'
mkdir -p build
"$GODOT_BIN" --headless --path . --export-debug Android "$APK"
test -s "$APK"
sha256sum "$APK"
printf '%s\n' 'J11_ANDROID_EXPORT=PASS ; VALIDATION_S25_ULTRA=NOT_TESTED'
