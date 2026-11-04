#!/bin/sh
# Headless rules tests. Exits non-zero on any failure.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
GODOT="$GODOT" sh scripts/import.sh
exec "$GODOT" --headless --path Godot -s res://tests/game_rules_tests.gd
