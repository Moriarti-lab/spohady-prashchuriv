#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}"
cd "$ROOT"
echo "== core =="
"$GODOT" --headless --path . -s tests/editor/test_editor_core.gd
echo "== tree gen v7 (≥10 seeds) =="
"$GODOT" --headless --path . -s tests/editor/test_tree_gen_v7.gd
echo "== flow =="
"$GODOT" --headless --path . -s tests/editor/test_editor_flow.gd
echo "== ui =="
if command -v xvfb-run >/dev/null; then
  xvfb-run -a "$GODOT" --path . -s tests/editor/test_editor_ui_tabs.gd --resolution 1920x864
else
  "$GODOT" --path . -s tests/editor/test_editor_ui_tabs.gd --resolution 1920x864
fi
echo "ALL_EDITOR_TESTS_OK"
