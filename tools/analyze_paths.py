#!/usr/bin/env python3
"""
Script 2: Пошук кращих комбінацій і шляхів для різних архетипів.
Beam search по дереву від старту: стан = з'єднаний набір вузлів,
крок = +1 сусідній вузол, бюджет = сумарні очки. Швидко навіть на 840 вузлах.
Виводить: топ шляхи на бюджетах 10/20/40 очок, медіани ключових статів,
топ грона (notable+кільце) за архетипом.
"""
import json, math, sys, heapq
from collections import defaultdict, Counter

# ─── завантаження ──────────────────────────────────────────────
if len(sys.argv) < 2:
    print("Використання: python3 analyze_paths.py <perk_tree.json>")
    sys.exit(1)

tree = json.load(open(sys.argv[1], encoding="utf-8"))
nodes = {n["id"]: n for n in tree["nodes"]}
links = tree["links"]
starts = tree["class_starts"]

adj = defaultdict(list)
for a, b in links:
    if a in nodes and b in nodes:
        adj[a].append(b)
        adj[b].append(a)

NODE_COST = {"small": 1, "notable": 4, "keystone": 8, "core": 12, "start": 0}

def node_cost(nid):
    return NODE_COST.get(nodes[nid]["type"], 1)

ATTR_MAP = {"str": "Сила", "agi": "Спритність", "faith": "Віра",
            "dmg_pct": "Шкода%", "hp_pct": "Життя%", "crit_pct": "Крит%",
            "dodge_pct": "Ухилення%", "armor": "Броня", "cdr_pct": "Відновл.%",
            "res_all_pct": "Опір%", "move_pct": "Рух%", "atk_speed_pct": "Швидк.атаки%",
            "lifesteal_pct": "Ліч%", "thorns_pct": "Шипи%", "block_pct": "Блок%",
            "dr_pct": "Захист%", "mana_pct": "Чар%", "mana_regen": "Реген чару",
            "heal_pct": "Лікування%", "crit_dmg_pct": "Крит.шкода%",
            "proj_speed_pct": "Снаряд%", "pen_all_pct": "Пробиття%",
            "nauz_xp_pct": "Наузи%", "aoe_pct": "Площа%", "double_hit_pct": "Подв.удар%",
            "effect_dur_pct": "Тривал.%", "skill_cost_pct": "Вартість%",
            "xp_pct": "Звитяга%", "hp": "Життя"}

ARCHETYPES = [
    {"id": "str_melee", "name": "Сила / Ближній бій", "class": "druzhynnyk",
     "primary": ["str"],
     "wanted": ["dmg_pct", "hp_pct", "armor", "lifesteal_pct", "block_pct", "atk_speed_pct", "str"],
     "avoid": ["dodge_pct"]},
    {"id": "agi_ranged", "name": "Спритність / Стрільба", "class": "strilets",
     "primary": ["agi"],
     "wanted": ["crit_pct", "crit_dmg_pct", "proj_speed_pct", "dodge_pct", "move_pct", "agi"],
     "avoid": ["armor"]},
    {"id": "faith_magic", "name": "Віра / Магія", "class": "volkhv",
     "primary": ["faith"],
     "wanted": ["dmg_pct", "mana_pct", "mana_regen", "heal_pct", "effect_dur_pct", "faith"],
     "avoid": ["dodge_pct"]},
    {"id": "hybrid_agi_faith", "name": "Гібрид Спритність+Віра", "class": "strilets",
     "primary": ["agi", "faith"],
     "wanted": ["dmg_pct", "crit_pct", "mana_pct", "cdr_pct", "agi", "faith"],
     "avoid": []},
    {"id": "tank", "name": "Танк / Захист", "class": "druzhynnyk",
     "primary": ["str"],
     "wanted": ["armor", "hp_pct", "dr_pct", "block_pct", "thorns_pct", "str"],
     "avoid": ["dodge_pct"]},
]

def collect_stats(ids):
    total = defaultdict(float)
    for nid in ids:
        for k, v in nodes[nid]["stats"].items():
            total[k] += float(v)
    return total

def score_set(ids, arch):
    """Оцінка набору: бажані стати (праймовые ×2) мінус уникані."""
    st = collect_stats(ids)
    s = 0.0
    for k, v in st.items():
        w = 2.0 if k in arch["primary"] else 1.0
        if k in arch["wanted"]:
            s += abs(v) * w
        elif k in arch["avoid"]:
            s -= abs(v) * 0.5
    return s

def beam_best_sets(start_id, budget, arch, beam=24, top=20):
    """Beam search: стан = (score, cost, sorted-tuple вузлів). Крок: +1 сусід."""
    init = (0.0, node_cost(start_id), (start_id,))
    states = [init]
    best_final = []

    for _ in range(budget + 1):
        nxt = []
        for score, cost, ids in states:
            # стан можна завершити
            best_final.append((score, cost, ids))
            frontier = set()
            for nid in ids:
                for nb in adj[nid]:
                    if nb not in ids:
                        frontier.add(nb)
            for nb in frontier:
                c2 = cost + node_cost(nb)
                if c2 > budget:
                    continue
                ids2 = tuple(sorted(ids + (nb,)))
                # швидка оцінка приросту
                st = nodes[nb]["stats"]
                gain = 0.0
                for k, v in st.items():
                    w = 2.0 if k in arch["primary"] else 1.0
                    if k in arch["wanted"]:
                        gain += abs(float(v)) * w
                    elif k in arch["avoid"]:
                        gain -= abs(float(v)) * 0.5
                nxt.append((score + gain, c2, ids2))
        if not nxt:
            break
        nxt.sort(key=lambda x: -x[0])
        # дедуплікація однакових наборів
        seen = set()
        states = []
        for s in nxt:
            if s[2] in seen:
                continue
            seen.add(s[2])
            states.append(s)
            if len(states) >= beam:
                break
        if not states:
            break

    best_final.sort(key=lambda x: (-x[0], x[1]))
    out, seen = [], set()
    for s in best_final:
        if s[2] in seen:
            continue
        seen.add(s[2])
        out.append(s)
        if len(out) >= top:
            break
    return out

def median(vals):
    v = sorted(vals)
    n = len(v)
    return v[n // 2] if n else 0

print("=" * 70)
print("СКРИПТ 2: КРАЩІ ШЛЯХИ ТА КОМБІНАЦІЇ (beam search)")
print("=" * 70)

KEY_STATS = ["dmg_pct", "hp_pct", "crit_pct", "armor", "cdr_pct", "str", "agi", "faith"]

for arch in ARCHETYPES:
    sid = starts[arch["class"]]
    print(f"\n{'─'*66}\n{arch['name']}  (клас: {arch['class']}, старт: {sid})")
    print(f"   бажані: {', '.join(arch['wanted'])}")

    for budget in [10, 20, 40]:
        results = beam_best_sets(sid, budget, arch, beam=24, top=20)
        if not results:
            print(f"\n   Бюджет {budget}: шляхів немає")
            continue
        top = results[0]
        st = collect_stats(top[2])
        print(f"\n   Бюджет {budget} очок — найкращий (оцінка {top[0]:.0f}, вузлів {len(top[2])}):")
        parts = []
        for k in KEY_STATS:
            if st.get(k):
                parts.append(f"{ATTR_MAP.get(k,k)}+{st[k]:.0f}")
        print(f"     Стати: {', '.join(parts[:8])}")
        names = [nodes[n]["name"] for n in top[2][:8]]
        print(f"     Шлях: {' → '.join(names)}{' …' if len(top[2])>8 else ''}")

        # медіани ключових статів по топ-20 наборах
        meds = []
        for k in arch["wanted"][:6]:
            vals = [collect_stats(r[2]).get(k, 0) for r in results]
            meds.append(f"{ATTR_MAP.get(k,k)}~{median(vals):.0f}")
        print(f"     Медіани (топ-20): {', '.join(meds)}")

    # топ грона
    from collections import deque
    dist = {sid: 0}
    q = deque([sid])
    while q:
        c = q.popleft()
        for nb in adj[c]:
            if nb not in dist:
                dist[nb] = dist[c] + 1
                q.append(nb)
    scored = []
    for nid, n in nodes.items():
        if n["type"] != "notable" or nid not in dist:
            continue
        ring = [nb for nb in adj[nid] if nodes[nb]["type"] == "small"]
        st = collect_stats([nid] + ring)
        sc = sum(abs(st.get(k, 0)) * (2 if k in arch["primary"] else 1) for k in arch["wanted"])
        scored.append((sc, nid, st))
    scored.sort(key=lambda x: -x[0])
    print(f"\n   Топ-3 грона:")
    for sc, nid, st in scored[:3]:
        d = dist.get(nid, "?")
        parts = [f"{ATTR_MAP.get(k,k)}+{v:.0f}" for k, v in sorted(st.items(), key=lambda x: -abs(x[1]))[:4]]
        print(f"     {nodes[nid]['name']} (оцінка {sc:.0f}, {d} кроків від старту): {', '.join(parts)}")

print("\n✓ Аналіз шляхів завершено")
