#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 .vercel/flutter
  export PATH="$PWD/.vercel/flutter/bin:$PATH"
fi

flutter --version
flutter pub get
flutter build web --release --no-wasm-dry-run
