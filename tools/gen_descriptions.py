#!/usr/bin/env python3
"""Generate perk tree node `description` from `stats` (handoff §9).

Removes filler descriptions such as «Гілка.» by replacing them with a
deterministic Ukrainian summary of bonuses. Idempotent.

  python3 tools/gen_descriptions.py --check     # exit 1 if would change; no writes
  python3 tools/gen_descriptions.py             # write data/perk_tree.json
  python3 tools/gen_descriptions.py --force     # overwrite ALL descriptions

Templates: prefer data/stat_registry.json `ua_template` when present; else
parse scripts/data/perk_tree.gd STAT_TEXT.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TREE_PATH = ROOT / "data" / "perk_tree.json"
REGISTRY_PATH = ROOT / "data" / "stat_registry.json"
PERK_GD = ROOT / "scripts" / "data" / "perk_tree.gd"

FILLERS = {
    "",
    "Гілка.",
    "Гілочка.",
    "Пагін.",
    "Стовбур.",
    "Сплетення шляхів.",
    "Стовбур роду — сплетення шляхів.",
    "Корінь.",
    "Бічний корінь.",
    "Сплетення гілки.",
    "Сплетення коріння.",
    "Корінець.",
}

ORDER_HINT = [
    "str", "agi", "faith", "hp", "hp_pct", "mana_pct", "mana_regen", "mana_regen_pct",
    "armor", "dmg", "dmg_pct", "atk_speed_pct", "crit_pct", "crit_dmg_pct", "cdr_pct",
    "lifesteal_pct", "thorns_pct", "hp_regen_pct", "dr_pct", "move_pct", "dodge_pct",
    "block_pct", "block_power_pct", "aoe_pct", "effect_dur_pct", "skill_cost_pct",
    "gold_pct", "drop_pct", "xp_pct", "nauz_xp_pct", "nauz_level", "thread_power_pct",
    "one_path", "free_skills", "life_pay_skills", "crit_stun", "block_no_shield", "kill_haste",
]


def load_templates() -> dict[str, str]:
    templates: dict[str, str] = {}
    if REGISTRY_PATH.is_file():
        data = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
        for e in data.get("entries", []):
            tid = str(e.get("id", ""))
            tpl = str(e.get("ua_template", ""))
            if tid and tpl:
                templates[tid] = tpl
    if PERK_GD.is_file():
        text = PERK_GD.read_text(encoding="utf-8")
        m = re.search(r"const STAT_TEXT := \{([\s\S]*?)\n\}", text)
        if m:
            for k, v in re.findall(r'"([^"]+)":\s*"([^"]*)"', m.group(1)):
                templates.setdefault(k, v)
    return templates


def format_signed(n: float | int) -> str:
    if isinstance(n, float) and n.is_integer():
        n = int(n)
    if isinstance(n, float):
        s = f"{n:g}"
    else:
        s = str(int(n))
    if not s.startswith(("-", "+")):
        s = "+" + s
    return s


def format_stat(key: str, value, templates: dict[str, str]) -> str:
    tpl = templates.get(key)
    if tpl is None:
        return f"{format_signed(value)} {key}"
    if "%s" not in tpl:
        return tpl
    return tpl % format_signed(value)


def describe_stats(stats: dict, templates: dict[str, str]) -> str:
    if not isinstance(stats, dict) or not stats:
        return "Без бонусів."
    parts: list[str] = []
    keys = [k for k in ORDER_HINT if k in stats]
    keys += sorted(str(k) for k in stats.keys() if str(k) not in keys)
    for k in keys:
        v = stats[k]
        if v is None or v == 0 or v == 0.0:
            continue
        parts.append(format_stat(str(k), v, templates))
    if not parts:
        return "Без бонусів."
    if len(parts) == 1:
        return parts[0] + "."
    if len(parts) == 2:
        return f"{parts[0]} та {parts[1]}."
    return ", ".join(parts[:-1]) + f" та {parts[-1]}."


def should_replace(desc: str, new_desc: str, force: bool) -> bool:
    d = (desc or "").strip()
    if d == new_desc:
        return False
    if force:
        return True
    return d in FILLERS


def process(tree: dict, templates: dict[str, str], force: bool = False):
    changes: list[tuple[str, str, str]] = []
    out_nodes = []
    for n in tree.get("nodes", []):
        if not isinstance(n, dict):
            out_nodes.append(n)
            continue
        nn = dict(n)
        new_desc = describe_stats(nn.get("stats", {}) or {}, templates)
        old = str(nn.get("description", ""))
        if should_replace(old, new_desc, force):
            if old != new_desc:
                changes.append((str(nn.get("id", "?")), old, new_desc))
            nn["description"] = new_desc
        out_nodes.append(nn)
    new_tree = dict(tree)
    new_tree["nodes"] = out_nodes
    return new_tree, changes


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="Exit 1 if would change; do not write")
    ap.add_argument("--force", action="store_true", help="Overwrite all descriptions from stats")
    ap.add_argument("--path", type=Path, default=TREE_PATH)
    ap.add_argument("--examples", type=int, default=0)
    args = ap.parse_args(argv)

    templates = load_templates()
    if not templates:
        print("WARNING: no stat templates loaded", file=sys.stderr)

    raw = json.loads(args.path.read_text(encoding="utf-8"))
    new_tree, changes = process(raw, templates, force=args.force)

    # Idempotency: applying again yields no further changes
    _, second = process(new_tree, templates, force=False)
    if second:
        print(f"INTERNAL: non-idempotent ({len(second)} lingering)", file=sys.stderr)
        return 2

    n_ex = args.examples or (5 if args.check and changes else 0)
    if n_ex and changes:
        print(f"Would change {len(changes)} nodes. Examples:")
        for nid, old, new in changes[:n_ex]:
            print(f"  [{nid}]")
            print(f"    before: {old!r}")
            print(f"    after:  {new!r}")
    elif args.check and not changes:
        print("CHECK OK: descriptions up to date")

    if args.check:
        if changes:
            print(f"CHECK FAIL: {len(changes)} descriptions would change", file=sys.stderr)
            return 1
        return 0

    if not changes:
        print("No changes.")
        return 0
    args.path.write_text(json.dumps(new_tree, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Updated {len(changes)} descriptions in {args.path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
