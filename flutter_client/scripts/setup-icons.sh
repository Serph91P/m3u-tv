#!/bin/bash
# Flutter icon + splash generation for m3u-tv/flutter_client
#
# Workflow:
#   1. Run the upstream generate-icons.sh to (re)build PNGs from SVG source
#   2. Sync the generated PNGs into flutter_client/assets/icons/
#   3. Run flutter_launcher_icons  → platform app icons
#   4. Run flutter_native_splash   → platform splash screens
#
# Prerequisites: librsvg, ImageMagick (see ../scripts/generate-icons.sh)
# Run from anywhere — the script resolves its own paths.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_DIR="$(dirname "$SCRIPT_DIR")"          # flutter_client/
TV_ROOT="$(dirname "$FLUTTER_DIR")"             # m3u-tv/
ICONS_DIR="$FLUTTER_DIR/assets/icons"

echo "=== Step 1: Regenerate source PNGs from SVG ==="
bash "$TV_ROOT/scripts/generate-icons.sh"

echo ""
echo "=== Step 2: Sync PNGs into flutter_client/assets/icons/ ==="
mkdir -p "$ICONS_DIR"
cp "$TV_ROOT/assets/icon.png"          "$ICONS_DIR/icon.png"
cp "$TV_ROOT/assets/adaptive-icon.png" "$ICONS_DIR/adaptive-icon.png"
cp "$TV_ROOT/assets/splash-icon.png"   "$ICONS_DIR/splash-icon.png"
cp "$TV_ROOT/favicon.png"              "$ICONS_DIR/favicon.png"
echo "  Synced 4 files to $ICONS_DIR"

echo ""
echo "=== Step 3: flutter pub get ==="
cd "$FLUTTER_DIR"
flutter pub get

echo ""
echo "=== Step 4: Generate app icons (all platforms) ==="
dart run flutter_launcher_icons

echo ""
echo "=== Step 5: Generate splash screens (Android + iOS) ==="
dart run flutter_native_splash:create

echo ""
echo "=== Done ==="
echo "App icons and splash screens are up to date."
echo "Run 'flutter run' to verify on your target platform."
