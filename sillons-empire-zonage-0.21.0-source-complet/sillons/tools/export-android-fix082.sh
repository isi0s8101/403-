#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
./tools/verify-fix082.sh
mkdir -p build
APK=build/sillons-empire-recette-debug-0.8.2.apk
"$GODOT_BIN" --headless --path . --export-debug Android "$APK"
test -s "$APK"
sha256sum "$APK"
echo "APK_EXPORT=GENERATED $APK ; DEVICE_TEST=NOT_RUN"
