#!/usr/bin/env python3
"""Tests for tools/gen_descriptions.py (no writes to perk_tree.json)."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "gen_descriptions.py"


def run(args: list[str], path: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--path", str(path), *args],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )


def main() -> int:
    raw = json.loads((ROOT / "data" / "perk_tree.json").read_text(encoding="utf-8"))
    # tiny fixture
    sample = {
        "format": raw.get("format"),
        "version": raw.get("version"),
        "nodes": [
            {"id": "a", "description": "Гілка.", "stats": {"str": 2, "hp_pct": 3}},
            {"id": "b", "description": "Унікальний авторський текст про долю.", "stats": {"agi": 1}},
            {"id": "c", "description": "Сплетення шляхів.", "stats": {}},
        ],
        "links": [],
    }
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "tree.json"
        p.write_text(json.dumps(sample, ensure_ascii=False, indent=2), encoding="utf-8")
        r = run(["--check", "--examples", "3"], p)
        assert r.returncode == 1, r.stdout + r.stderr
        assert "Would change" in r.stdout
        r2 = run([], p)
        assert r2.returncode == 0, r2.stderr
        data = json.loads(p.read_text(encoding="utf-8"))
        by_id = {n["id"]: n for n in data["nodes"]}
        assert "Гілка." not in by_id["a"]["description"]
        assert "Сил" in by_id["a"]["description"] or "сил" in by_id["a"]["description"].lower() or "+" in by_id["a"]["description"]
        assert by_id["b"]["description"] == "Унікальний авторський текст про долю."
        assert by_id["c"]["description"] == "Без бонусів."
        # idempotent
        r3 = run(["--check"], p)
        assert r3.returncode == 0, r3.stdout + r3.stderr
        # full tree check mode (expect drift today)
        r4 = run(["--check", "--examples", "2"], ROOT / "data" / "perk_tree.json")
        assert r4.returncode == 1
        assert "Would change" in r4.stdout
        print("ok test_gen_descriptions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
