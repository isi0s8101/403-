#!/usr/bin/env bash
set -Eeuo pipefail
exec "$(dirname -- "${BASH_SOURCE[0]}")/verify-j9-complete.sh" "$@"
