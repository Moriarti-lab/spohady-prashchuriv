#!/usr/bin/env python3
"""CI smoke: shipped perk_tree.json is v7.3 / seed 424242 family (945 nodes)."""
import json, sys
from pathlib import Path
p = Path("data/perk_tree.json")
d = json.loads(p.read_text())
meta = d.get("meta", {})
nodes = d.get("nodes", [])
ok = True
def fail(m):
    global ok
    ok = False
    print("FAIL", m)
ver = str(meta.get("tree_version", meta.get("version_tag", "")))
if "v7.3" not in ver and ver != "v7.3":
    # allow meta.tree_version == v7.3
    if ver != "v7.3":
        fail(f"tree_version={ver!r} expected v7.3")
if len(nodes) != 945:
    fail(f"nodes={len(nodes)} expected 945")
seed = meta.get("seed", meta.get("gen_seed"))
if seed is not None and int(seed) != 424242:
    fail(f"seed={seed} expected 424242")
stubs = [n for n in nodes if str(n.get("name", "")).startswith("Вузол")]
if stubs:
    fail(f"{len(stubs)} stub names remain")
if ok:
    print("TREE_SEED_OK", ver, "nodes", len(nodes), "seed", seed)
    sys.exit(0)
sys.exit(1)
