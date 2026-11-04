#!/bin/sh
# Builds the iPhone/iPad Xcode project in build/ios/ and opens it.
# Installs the Godot 4.7.2 export templates first if they're missing (~1 GB download).
# Then pick your iPhone or iPad in Xcode and press Run.
set -e
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
VERSION=4.7.2
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$VERSION.stable"
cd "$(dirname "$0")/.."
if [ ! -f "$TEMPLATES/ios.zip" ]; then
  echo "Installing Godot $VERSION export templates…"
  TMP="$(mktemp -d)"
  curl -fL --progress-bar -o "$TMP/templates.tpz" "https://github.com/godotengine/godot/releases/download/$VERSION-stable/Godot_v$VERSION-stable_export_templates.tpz"
  unzip -q "$TMP/templates.tpz" -d "$TMP"
  mkdir -p "$TEMPLATES"
  cp -R "$TMP/templates/." "$TEMPLATES/"
  rm -rf "$TMP"
fi
GODOT="$GODOT" sh scripts/import.sh
mkdir -p build/ios
"$GODOT" --headless --path Godot --export-debug iOS
PROJECT="$(ls -d build/ios/*.xcodeproj | head -1)"
echo "Xcode project: $PROJECT"
[ -n "$NO_OPEN" ] || open "$PROJECT"
