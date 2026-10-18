#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir/alloop-SDK"
flutter pub get
flutter test test/web_preview_test.dart
flutter build web --target lib/main_web.dart --release --no-wasm-dry-run
cd "$repo_dir"
mkdir -p .web-dist
rsync -a --delete alloop-SDK/build/web/ .web-dist/
python3 web_deploy/check_bundle.py
