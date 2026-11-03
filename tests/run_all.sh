#!/usr/bin/env bash
# Усі перевірки одним запуском: bash tests/run_all.sh
# Потрібні: Godot 4.7.2 (змінна GODOT або команда godot у PATH), node, python3.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
fail=0

echo "== Редактор Древа: логіка =="
node tools/test_editor.js || fail=1

echo "== Редактор Древа: вбудоване Древо збігається з data/perk_tree.json =="
python3 tools/sync_editor_tree.py --check || fail=1

if [ -n "${JSDOM_PATH:-}" ]; then
  echo "== Редактор Древа: інтерфейс (jsdom) =="
  NODE_PATH="$JSDOM_PATH" node tools/test_editor_ui.js || fail=1
fi

echo "== Гра: smoke-тест (1–2 хвилини) =="
"$GODOT" --headless --path . res://tests/smoke_test.tscn > /tmp/smoke.log 2>&1
grep -v "^  ok" /tmp/smoke.log | grep -v "^ERROR: \(Pages in use\|.*were never freed\|Buffer with\|.*leaked\|Texture with\|Parameter\)" | tail -25
if grep -q "FAIL" /tmp/smoke.log; then fail=1; fi
grep -E "Підсумок" /tmp/smoke.log

[ $fail -eq 0 ] && echo "ВСЕ ГАРАЗД" || echo "Є ПОМИЛКИ"
exit $fail
