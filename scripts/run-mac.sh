#!/bin/sh
# Play the game on a Mac. Set GODOT to your Godot 4.7.2 binary if it isn't the default.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
GODOT="$GODOT" sh scripts/import.sh
exec "$GODOT" --path Godot "$@"
