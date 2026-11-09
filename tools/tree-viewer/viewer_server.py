#!/usr/bin/env python3
"""
Сервер візуалізатора «Древа звитяги» v5.

Віддає статику (index.html, style.css, app.js) і API:
  GET  /api/tree      — поточне дерево + seed + статистика + журнал
  POST /api/generate  — генерація заново: {"seed": 123} (необов'язково)

Запуск: python3 tools/tree-viewer/viewer_server.py [порт=8734]
Лише stdlib. Оригінал tools/generate_perk_tree_v5.py не змінюється: на кожен
запуск береться його копія в out/ з іншим seed і шляхом виводу в out/.
Гра в data/perk_tree.json не чіпається.
"""
import json
import math
import random
import re
import subprocess
import sys
import threading
import time
from collections import Counter, deque
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
GEN = ROOT.parent / "generate_perk_tree_v5.py"
OUT = ROOT / "out"
OUT.mkdir(exist_ok=True)

LOCK = threading.Lock()
STATE = {"tree": None, "seed": None, "stats": None, "log": "", "ts": 0.0}


def compute_stats(tree):
    """Ті самі показники, що друкує генератор, але для конкретного дерева."""
    ids = {n["id"] for n in tree["nodes"]}
    adj = {i: [] for i in ids}
    for a, b in tree["links"]:
        if a in ids and b in ids:
            adj[a].append(b)
            adj[b].append(a)
    starts = [s for s in tree.get("class_starts", {}).values() if s in ids]
    seen = set()
    q = deque(starts)
    while q:
        c = q.popleft()
        if c in seen:
            continue
        seen.add(c)
        for nb in adj[c]:
            if nb not in seen:
                q.append(nb)
    deg = [len(v) for v in adj.values()]
    ns = tree["nodes"]
    md = min(
        (math.dist((a["x"], a["y"]), (b["x"], b["y"]))
         for i, a in enumerate(ns) for b in ns[i + 1:]),
        default=0.0,
    )
    return {
        "nodes": len(ids),
        "links": len(tree["links"]),
        "reachable": len(seen),
        "orphans": len(ids - seen),
        "avg_degree": round(sum(deg) / max(1, len(deg)), 2),
        "min_dist": round(md, 1),
        "types": dict(Counter(n["type"] for n in ns)),
        "regions": dict(Counter(n["region"] for n in ns)),
    }


def generate(seed):
    """Копія генератора з іншим seed і виводом у out/, запуск, збір JSON."""
    if not GEN.exists():
        raise RuntimeError(f"немає генератора: {GEN}")
    src = GEN.read_text(encoding="utf-8")
    src, n_seed = re.subn(r"^random\.seed\(.*$", f"random.seed({seed})",
                          src, count=1, flags=re.M)
    target = OUT / f"perk_tree_{seed}.json"
    src, n_out = re.subn(r"^out = .*$", f"out = {json.dumps(str(target))}",
                         src, count=1, flags=re.M)
    if not (n_seed and n_out):
        raise RuntimeError("не знайшов у генераторі рядки 'random.seed(...)' і 'out = ...'")

    run = OUT / f"_run_{seed}.py"
    run.write_text(src, encoding="utf-8")
    t0 = time.time()
    p = subprocess.run([sys.executable, str(run)], capture_output=True,
                       text=True, timeout=180, cwd=str(ROOT.parent))
    dt = time.time() - t0
    if p.returncode != 0 or not target.exists():
        raise RuntimeError(f"генератор завершився з кодом {p.returncode}\n"
                           f"{(p.stderr or '')[-3000:]}")

    tree = json.loads(target.read_text(encoding="utf-8"))

    # прибираємо старі артефакти, лишаємо 10 останніх дерев
    for old in sorted(OUT.glob("perk_tree_*.json"), key=lambda f: f.stat().st_mtime)[:-10]:
        old.unlink(missing_ok=True)
    for old in OUT.glob("_run_*.py"):
        if old.name != run.name:
            old.unlink(missing_ok=True)

    return {
        "tree": tree,
        "seed": seed,
        "log": p.stdout,
        "duration": round(dt, 2),
        "stats": compute_stats(tree),
    }


def payload():
    with LOCK:
        return dict(STATE)


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(ROOT), **kw)

    def _json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/api/tree":
            data = payload()
            if not data.get("tree"):
                self._json(404, {"error": "дерева ще немає — POST /api/generate"})
            else:
                self._json(200, data)
            return
        super().do_GET()

    def do_POST(self):
        path = self.path.split("?")[0]
        if path != "/api/generate":
            self._json(404, {"error": "не знайдено"})
            return
        try:
            n = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(n) if n else b"{}"
            req = json.loads(raw or b"{}")
            seed = int(req.get("seed") or random.SystemRandom().randint(1, 2**31 - 1))
        except (ValueError, json.JSONDecodeError) as e:
            self._json(400, {"error": f"поганий запит: {e}"})
            return
        try:
            with LOCK:
                STATE.update(generate(seed))
                STATE["ts"] = time.time()
            self._json(200, payload())
        except Exception as e:  # noqa: BLE001
            self._json(500, {"error": str(e)})

    def log_message(self, fmt, *args):
        sys.stderr.write("[viewer] " + (fmt % args) + "\n")


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8734
    if len(sys.argv) > 2:
        with LOCK:
            STATE.update(generate(int(sys.argv[2])))
            STATE["ts"] = time.time()
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Візуалізатор: http://127.0.0.1:{port}", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
