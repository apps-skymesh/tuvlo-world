#!/bin/sh
# Headless rules and interface-feel tests. Exits non-zero on any failure.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
GODOT="$GODOT" sh scripts/import.sh
"$GODOT" --headless --path Godot -s res://tests/game_rules_tests.gd || exit 1
exec "$GODOT" --headless --path Godot -s res://tests/feel_spam_tests.gd
