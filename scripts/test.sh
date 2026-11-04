#!/bin/sh
# Headless rules tests. Exits non-zero on any failure.
# The first run imports assets and registers script classes (the editor is
# stopped after the import because it doesn't exit by itself).
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
if [ ! -f Godot/.godot/global_script_class_cache.cfg ] || [ -n "$REIMPORT" ]; then
  "$GODOT" --headless --path Godot --editor --quit >/dev/null 2>&1
fi
exec "$GODOT" --headless --path Godot -s res://tests/game_rules_tests.gd
