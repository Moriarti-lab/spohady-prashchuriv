#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}"
cd "$ROOT"
echo "== core =="
"$GODOT" --headless --path . -s tests/editor/test_editor_core.gd
echo "== ui =="
if command -v xvfb-run >/dev/null; then
  xvfb-run -a "$GODOT" --path . -s tests/editor/test_editor_ui_tabs.gd --resolution 1024x473
else
  "$GODOT" --path . -s tests/editor/test_editor_ui_tabs.gd --resolution 1024x473
fi
echo "ALL_EDITOR_TESTS_OK"
