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


echo "== Редактор APK: core / gen / UI =="
if [ -x tests/editor/run_all.sh ] || [ -f tests/editor/run_all.sh ]; then
  bash tests/editor/run_all.sh || fail=1
fi

echo "== Гра: smoke-тест (1–2 хвилини) =="
"$GODOT" --headless --path . res://tests/smoke_test.tscn > /tmp/smoke.log 2>&1
grep -v "^  ok" /tmp/smoke.log | grep -v "^ERROR: \(Pages in use\|.*were never freed\|Buffer with\|.*leaked\|Texture with\|Parameter\)" | tail -25
if grep -q "FAIL" /tmp/smoke.log; then fail=1; fi
grep -E "Підсумок" /tmp/smoke.log

echo "== Гра: справжній шлях нового гравця (створення героя → світ) =="
if command -v xvfb-run >/dev/null 2>&1; then
  xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 res://tests/flow_test.tscn > /tmp/flow.log 2>&1 || fail=1
else
  "$GODOT" --headless --path . res://tests/flow_test.tscn > /tmp/flow.log 2>&1 || fail=1
fi
grep -E "^  (ok|FAIL)|Підсумок|SCRIPT ERROR|TIMEOUT" /tmp/flow.log
if grep -q "FAIL\|SCRIPT ERROR\|TIMEOUT" /tmp/flow.log; then fail=1; fi



echo "== Гра: регресія UI наузів/ниток =="
if command -v xvfb-run >/dev/null 2>&1; then
  xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 res://tests/nauzi_ui_test.tscn > /tmp/nauzi_ui.log 2>&1 || fail=1
else
  "$GODOT" --path . res://tests/nauzi_ui_test.tscn > /tmp/nauzi_ui.log 2>&1 || fail=1
fi
grep -E "^  (ok|FAIL)|Підсумок|SCRIPT ERROR" /tmp/nauzi_ui.log | tail -60
if grep -q "FAIL\|SCRIPT ERROR" /tmp/nauzi_ui.log; then fail=1; fi

echo "== Гра: регресія layout (1024x473 / 1280x576 / 854x480) =="
mkdir -p /tmp/layout_shots
if command -v xvfb-run >/dev/null 2>&1; then
  xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 res://tests/layout_regression.tscn -- /tmp/layout_shots > /tmp/layout.log 2>&1 || fail=1
else
  "$GODOT" --path . res://tests/layout_regression.tscn -- /tmp/layout_shots > /tmp/layout.log 2>&1 || fail=1
fi
grep -E "^  (ok|FAIL)|Підсумок|shot |rect |SCRIPT ERROR|zoom=" /tmp/layout.log | tail -80
if grep -q "FAIL\|SCRIPT ERROR" /tmp/layout.log; then fail=1; fi


echo "== Гра: скасування продажу цінної речі =="
if command -v xvfb-run >/dev/null 2>&1; then
  xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 res://tests/sell_cancel_test.tscn > /tmp/sell_cancel.log 2>&1 || fail=1
else
  "$GODOT" --headless --path . res://tests/sell_cancel_test.tscn > /tmp/sell_cancel.log 2>&1 || fail=1
fi
grep -E "^  (ok|FAIL)|Підсумок|SCRIPT ERROR" /tmp/sell_cancel.log | tail -40
if grep -q "FAIL\|SCRIPT ERROR" /tmp/sell_cancel.log; then fail=1; fi

[ $fail -eq 0 ] && echo "ВСЕ ГАРАЗД" || echo "Є ПОМИЛКИ"
exit $fail
