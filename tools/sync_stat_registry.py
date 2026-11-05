#!/usr/bin/env python3
"""Sync HTML STAT_KEYS/MOD_KEYS from data/stat_registry.json. Check mode: --check"""
import json, re, sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
reg = json.loads((root / "data/stat_registry.json").read_text())
keys = []
for e in reg["entries"]:
    mech = e["mechanics"]
    applies = e.get("applies_to", [])
    if mech in ("wired", "display_only") and "tree_node" in applies:
        keys.append(e["id"])
    elif e.get("in_html_editor_STAT_KEYS") and mech not in ("weapon_field", "nauz_mod"):
        if e["id"] not in keys:
            keys.append(e["id"])
for fid in ["one_path","thread_power_pct","life_pay_skills","free_skills","crit_stun","block_no_shield","kill_haste"]:
    if fid not in keys and any(e["id"]==fid for e in reg["entries"]):
        keys.append(fid)
mod_keys = []
seen=set()
for e in reg["entries"]:
    if e.get("in_html_editor_MOD_KEYS") or e["mechanics"]=="nauz_mod":
        if e["id"] not in seen:
            mod_keys.append(e["id"]); seen.add(e["id"])
html_path = root / "tools/tree-editor/index.html"
html = html_path.read_text()
stat_line = "var STAT_KEYS = %s;" % json.dumps(keys)
mod_line = "var MOD_KEYS = %s;" % json.dumps(mod_keys)
m1 = re.search(r"var STAT_KEYS = \[.*?\];", html)
m2 = re.search(r"var MOD_KEYS = \[.*?\];", html)
if not m1 or not m2:
    print("STAT_KEYS/MOD_KEYS not found"); sys.exit(1)
if "--check" in sys.argv:
    ok = m1.group(0) == stat_line and m2.group(0) == mod_line
    print("OK" if ok else "DRIFT")
    sys.exit(0 if ok else 1)
html = re.sub(r"var STAT_KEYS = \[.*?\];", stat_line, html, count=1)
html = re.sub(r"var MOD_KEYS = \[.*?\];", mod_line, html, count=1)
html_path.write_text(html)
print("synced", len(keys), "STAT_KEYS", len(mod_keys), "MOD_KEYS")
