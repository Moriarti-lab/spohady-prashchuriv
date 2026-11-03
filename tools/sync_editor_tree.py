#!/usr/bin/env python3
"""Вбудовує data/perk_tree.json у tools/tree-editor/index.html (стартове Древо редактора).
Запуск: python3 tools/sync_editor_tree.py   (перевірка без змін: --check)"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TREE = os.path.join(ROOT, "data", "perk_tree.json")
HTML = os.path.join(ROOT, "tools", "tree-editor", "index.html")
OPEN = '<script id="default-tree" type="application/json">'


def main() -> int:
    data = json.load(open(TREE, encoding="utf-8"))
    body = json.dumps(data, ensure_ascii=False, indent=1).replace("</", "<\\/")
    html = open(HTML, encoding="utf-8").read()
    pat = re.compile(re.escape(OPEN) + r".*?</script>", re.S)
    if not pat.search(html):
        print("немає блоку default-tree")
        return 2
    new = pat.sub(lambda m: OPEN + body + "</script>", html, count=1)
    if "--check" in sys.argv:
        print("синхронно" if new == html else "ПОТРІБНО синхронізувати")
        return 0 if new == html else 1
    open(HTML, "w", encoding="utf-8").write(new)
    print("вбудовано %d вузлів, %d зв'язків" % (len(data["nodes"]), len(data["links"])))
    return 0


sys.exit(main())
