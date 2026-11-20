#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
./tools/verify-j10.sh
GODOT_BIN="${GODOT_BIN:-godot}"
APK='build/sillons-empire-j10-debug-0.10.0.apk'
mkdir -p build
"$GODOT_BIN" --headless --path . --export-debug Android "$APK"
test -s "$APK"
sha256sum "$APK"
printf '%s\n' 'J10_ANDROID_EXPORT=PASS ; VALIDATION_MATERIELLE_S25_ULTRA=NOT_TESTED'
