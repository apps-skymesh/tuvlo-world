#!/bin/sh
# Imports new or changed assets and registers script classes before a run.
# Skipped when nothing under Godot/ is newer than the last import.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
STAMP=Godot/.godot/.last-import
if [ -n "$REIMPORT" ] || [ ! -f "$STAMP" ] || [ -n "$(find Godot -path Godot/.godot -prune -o -newer "$STAMP" -type f -print -quit)" ]; then
  echo "Importing assets…"
  "$GODOT" --headless --path Godot --editor --quit >/dev/null 2>&1
  touch "$STAMP"
fi
