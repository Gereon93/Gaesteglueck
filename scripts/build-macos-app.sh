#!/usr/bin/env bash
set -euo pipefail

# Build und Bundle Gästeglück als macOS-.app.
# Beseitigt die macOS-Console-Warnungen (CFBundleIdentifier-fehlt, etc.)
# und macht die App im Finder als richtige Anwendung doppelklickbar.

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
BIN_NAME="Gaesteglueck"
APP_DIR="dist/Gaesteglueck.app"
PLIST="scripts/Info.plist"

echo "▶ Build (config: $CONFIG)"
swift build -c "$CONFIG"

echo "▶ Bundle: $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp ".build/$CONFIG/$BIN_NAME" "$APP_DIR/Contents/MacOS/$BIN_NAME"
cp "$PLIST" "$APP_DIR/Contents/Info.plist"

# Einmal touch'en damit Launch Services das App-Bundle frisch indexiert
touch "$APP_DIR"

echo "✓ Fertig: $APP_DIR"
echo
echo "Starten:"
echo "  open $APP_DIR"
echo
echo "Optional ins Programme-Verzeichnis kopieren:"
echo "  cp -R $APP_DIR /Applications/"
