#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

: "${SUPABASE_URL:?Set SUPABASE_URL in .env or environment}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY in .env or environment}"

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export PATH="/opt/flutter/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/deno/bin:$PATH"

flutter build apk --debug \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
