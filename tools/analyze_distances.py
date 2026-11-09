#!/usr/bin/env python3
"""
Script 1: Аналіз відстаней від стартових точок до кластерів (грон/плодів).
Виводить таблицю: старт → кластер → відстань (кроків по зв'язках),
найкоротші шляхи, середні/медіанні відстані.
"""
import json, math, sys, heapq
from collections import defaultdict, Counter

# ─── завантаження ──────────────────────────────────────────────
if len(sys.argv) < 2:
    print("Використання: python3 analyze_distances.py <perk_tree.json>")
    sys.exit(1)

tree = json.load(open(sys.argv[1], encoding="utf-8"))
nodes = {n["id"]: n for n in tree["nodes"]}
links = tree["links"]
starts = tree["class_starts"]   # class_id → node_id
regions = {r["id"]: r["name"] for r in tree["regions"]}

# ─── граф ──────────────────────────────────────────────────────
adj = defaultdict(list)
for a, b in links:
    if a in nodes and b in nodes:
        adj[a].append(b)
        adj[b].append(a)

# ─── знайти кластери (notable + оточення з малих) ────────────────
# notable: тип "notable"
# оточення: малі вузли, сусідні до notable, утворюють "кільце"
notable_ids = [n["id"] for n in nodes.values() if n["type"] == "notable"]
clusters = {}   # notable_id → {notable_node, ring_nodes[]}

for nid in notable_ids:
    ring = [nb for nb in adj[nid] if nodes[nb]["type"] == "small"]
    clusters[nid] = {"center": nodes[nid], "ring": ring}

print("=" * 70)
print("СКРИПТ 1: ВІДСТАНІ ДО КЛАСТЕРІВ")
print("=" * 70)

# ─── BFS від кожного старту ────────────────────────────────────
def bfs_distances(start_id):
    """BFS від start_id, повертає dict node_id → відстань (кроків)."""
    dist = {start_id: 0}
    q = [start_id]
    while q:
        cur = q.pop(0)
        for nb in adj[cur]:
            if nb not in dist:
                dist[nb] = dist[cur] + 1
                q.append(nb)
    return dist

class_dist = {}
for cls, sid in starts.items():
    if sid in nodes:
        class_dist[cls] = bfs_distances(sid)

# ─── таблиця відстаней старт → кожен кластер ─────────────────
print(f"\n{'Клас':<14} {'Гроно':<28} {'Кроків':>6}  {'ПройденоXY':>12}")
print("-" * 70)

results = []
for nid, cl in clusters.items():
    cn = cl["center"]
    for cls, dist_map in class_dist.items():
        if nid in dist_map:
            d = dist_map[nid]
            results.append((cls, cn["name"], d, cn["x"], cn["y"]))

results.sort(key=lambda x: (x[0], x[2]))

for cls, name, d, x, y in results:
    cls_name = {"druzhynnyk":"Дружинник","strilets":"Стрілець","volkhv":"Волхв"}.get(cls, cls)
    print(f"{cls_name:<14} {name:<28} {d:>6}  ({x:>7.0f},{y:>7.0f})")

# ─── статистика по відстанях ────────────────────────────────────
print("\n── Статистика відстаней ──")
all_d = defaultdict(list)
for cls, name, d, _, _ in results:
    all_d[cls].append(d)

for cls, ds in all_d.items():
    ds_sorted = sorted(ds)
    n = len(ds_sorted)
    mean = sum(ds) / n
    median = ds_sorted[n // 2]
    min_d = ds_sorted[0]
    max_d = ds_sorted[-1]
    cls_name = {"druzhynnyk":"Дружинник","strilets":"Стрілець","volkhv":"Волхв"}.get(cls, cls)
    print(f"  {cls_name}: мін={min_d}, макс={max_d}, середень={mean:.1f}, медіана={median}")

# ─── медіанна таблиця: клас → середня відстань до всіх кластерів ─
print("\n── Підсумок: клас → середня відстань до грон ──")
cls_names = {"druzhynnyk":"Дружинник","strilets":"Стрілець","volkhv":"Волхв"}
for cls in sorted(class_dist.keys()):
    ds = [d for c, name, d, _, _ in results if c == cls]
    if ds:
        print(f"  {cls_names[cls]}: {sum(ds)/len(ds):.1f} кроків (до {len(ds)} грон)")

# ─── геометричні відстані ───────────────────────────────────────
print("\n── Геометричні (прямі) відстані від стартів до грон ──")
starts_pos = {cls: (nodes[sid]["x"], nodes[sid]["y"]) for cls, sid in starts.items() if sid in nodes}
for nid, cl in clusters.items():
    cn = cl["center"]
    for cls, (sx, sy) in starts_pos.items():
        dist_geom = math.hypot(cn["x"] - sx, cn["y"] - sy)
        print(f"  {cls_names[cls]} → {cn['name']}: {dist_geom:.0f} од.")

# ─── зберегти результат у JSON ────────────────────────────────
report = {
    "clusters": {nid: {"name": cl["center"]["name"],
                        "region": cl["center"]["region"],
                        "x": cl["center"]["x"], "y": cl["center"]["y"],
                        "ring_count": len(cl["ring"])} for nid, cl in clusters.items()},
    "distances": {cls: {nid: d for nid in clusters for d in [class_dist[cls].get(nid, None)] if d is not None}
                  for cls in class_dist}
}
out_path = sys.argv[1].replace(".json", "_cluster_distances.json")
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=2)
print(f"\n✓ Таблиця відстаней → {out_path}")
