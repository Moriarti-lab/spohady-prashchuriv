#!/usr/bin/env python3
"""Generate perk_tree.json v4: roots at bottom, crown at top, fruit clusters, mix at borders."""
from __future__ import annotations
import json, math, random, copy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "perk_tree.json"
OLD = json.loads(OUT.read_text())

RNG = random.Random(4053)

# Screen Y grows downward → roots (bottom) = large Y, crown (top) = small/negative Y
Y_ROOT = 2200
Y_CROWN = -2400
Y_TRUNK_TOP = -400

REGIONS = [
    {"id": "str", "name": "Сила", "color": "#D8574B", "angle": -0.55},
    {"id": "agi", "name": "Спритність", "color": "#7CBF5A", "angle": 0.0},
    {"id": "faith", "name": "Віра", "color": "#E0A526", "angle": 0.55},
]
CLASS_STARTS = {"druzhynnyk": "s_root", "strilets": "a_root", "volkhv": "f_root"}
START_IDS = {"str": "s_root", "agi": "a_root", "faith": "f_root"}

# Tier budgets by height band (0=root .. 4=crown)
TIER_STATS = {
    # small node pools per region theme
    "str": [
        {"str": 3}, {"str": 4}, {"armor": 8}, {"hp": 15}, {"dmg_pct": 4},
        {"block_pct": 2}, {"dr_pct": 2}, {"lifesteal_pct": 1}, {"thorns_pct": 2},
        {"life_on_kill": 4}, {"stun_chance_pct": 2}, {"armor_pen_pct": 3},
        {"res_all_pct": 2}, {"pen_all_pct": 2}, {"atk_speed_pct": 2},
    ],
    "agi": [
        {"agi": 3}, {"agi": 4}, {"crit_pct": 2}, {"crit_dmg_pct": 6}, {"move_pct": 3},
        {"dodge_pct": 2}, {"atk_speed_pct": 3}, {"proj_speed_pct": 4}, {"dmg_pct": 3},
        {"double_hit_pct": 2}, {"drop_pct": 3}, {"gold_pct": 4}, {"pen_all_pct": 2},
        {"res_all_pct": 2}, {"nauz_xp_pct": 5},
    ],
    "faith": [
        {"faith": 3}, {"faith": 4}, {"mana_pct": 4}, {"mana_regen": 0.3}, {"hp_pct": 3},
        {"cdr_pct": 3}, {"aoe_pct": 4}, {"effect_dur_pct": 4}, {"skill_cost_pct": -3},
        {"res_all_pct": 3}, {"pen_all_pct": 2}, {"nauz_level": 1}, {"thread_power_pct": 6},
        {"xp_pct": 4}, {"mana_on_kill": 3},
    ],
}

NOTABLES = {
    "str": [
        ("Щит роду", {"armor": 25, "block_pct": 6, "dr_pct": 4}),
        ("Кривавий удар", {"dmg_pct": 12, "lifesteal_pct": 3}),
        ("Громова стіна", {"thorns_pct": 8, "stun_chance_pct": 5}),
        ("Залізна шкіра", {"hp": 40, "armor": 20, "res_all_pct": 5}),
        ("Пробивач", {"armor_pen_pct": 12, "pen_all_pct": 6, "dmg_pct": 6}),
        ("Щедра здобич", {"gold_pct": 20, "drop_pct": 15}),
    ],
    "agi": [
        ("Тінь вовка", {"move_pct": 10, "dodge_pct": 6, "atk_speed_pct": 8}),
        ("Влучне око", {"crit_pct": 6, "crit_dmg_pct": 20}),
        ("Град стріл", {"proj_speed_pct": 12, "double_hit_pct": 5, "dmg_pct": 8}),
        ("Шлях учня", {"xp_pct": 15}),
        ("Щедра здобич", {"gold_pct": 20, "drop_pct": 15}),
        ("Гостре вістря", {"pen_all_pct": 8, "armor_pen_pct": 8}),
    ],
    "faith": [
        ("Шлях учня", {"xp_pct": 15}),
        ("Коло пращурів", {"aoe_pct": 12, "effect_dur_pct": 10}),
        ("Нитка долі", {"thread_power_pct": 18, "nauz_xp_pct": 12}),
        ("Сила науза", {"nauz_level": 1, "nauz_xp_pct": 10}),
        ("Опір стихіям", {"res_all_pct": 10, "res_fire_pct": 5, "res_frost_pct": 5}),
        ("Щедра здобич", {"gold_pct": 20, "drop_pct": 15}),
    ],
}

KEYSTONES = [
    ("s_ks1", "str", "Один шлях", {"one_path": 1, "thread_power_pct": 40}, -0.7),
    ("s_ks2", "str", "Кривава данина", {"life_pay_skills": 1, "dmg_pct": 15}, -0.45),
    ("a_ks1", "agi", "Смертельна тінь", {"crit_stun": 1, "crit_pct": 8}, 0.0),
    ("a_ks2", "agi", "Блок без щита", {"block_no_shield": 1, "dodge_pct": 8}, 0.25),
    ("f_ks1", "faith", "Вільні вміння", {"free_skills": 1, "mana_pct": 10}, 0.55),
    ("f_ks2", "faith", "Жага вбивства", {"kill_haste": 1, "atk_speed_pct": 12}, 0.75),
    ("c_ks1", "str", "Серце війни", {"dmg_pct": 10, "hp_pct": 8, "res_all_pct": 5}, -0.2),
    ("c_ks2", "agi", "Серце полювання", {"crit_dmg_pct": 25, "move_pct": 8, "pen_all_pct": 5}, 0.15),
    ("c_ks3", "faith", "Серце віри", {"nauz_level": 1, "cdr_pct": 10, "res_all_pct": 6}, 0.4),
]

names_small = {
    "str": ["Корінь сили", "Жила сили", "Сучок сили", "Пагін сили", "Лист сили"],
    "agi": ["Корінь спритності", "Жила спритності", "Сучок спритності", "Пагін спритності", "Лист спритності"],
    "faith": ["Корінь віри", "Жила віри", "Сучок віри", "Пагін віри", "Лист віри"],
}


def tier_of_y(y: float) -> int:
    # 0 root .. 4 crown
    t = (Y_ROOT - y) / (Y_ROOT - Y_CROWN)
    return int(max(0, min(4, math.floor(t * 5))))


def scale_stats(stats: dict, tier: int) -> dict:
    out = {}
    mult = 1.0 + 0.22 * tier
    for k, v in stats.items():
        if isinstance(v, (int, float)) and k not in ("one_path", "life_pay_skills", "free_skills", "crit_stun", "block_no_shield", "kill_haste", "nauz_level", "nauz_thread_slots"):
            nv = v * mult
            out[k] = int(round(nv)) if abs(nv) >= 2 or isinstance(v, int) else round(nv, 1)
        else:
            out[k] = v
    return out


def fruit_ring(cx, cy, n, radius, jitter=18.0):
    pts = []
    for i in range(n):
        a = (i / n) * math.tau + RNG.uniform(-0.08, 0.08)
        r = radius + RNG.uniform(-jitter, jitter)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r * 0.75))
    return pts


def add_node(nodes, nid, name, typ, x, y, region, stats, desc=""):
    nodes[nid] = {
        "id": nid, "name": name, "description": desc,
        "x": round(x, 1), "y": round(y, 1),
        "type": typ, "stats": stats, "skill": "", "icon": "", "region": region,
    }


def link(links, a, b, seen):
    key = tuple(sorted((a, b)))
    if key in seen or a == b:
        return
    seen.add(key)
    links.append([a, b])


def nearest(candidates, x, y, exclude=None):
    best, bd = None, 1e18
    for c in candidates:
        if exclude and c["id"] in exclude:
            continue
        d = (c["x"] - x) ** 2 + (c["y"] - y) ** 2
        if d < bd:
            bd, best = d, c
    return best


def main():
    nodes = {}
    links = []
    seen = set()

    # --- Roots / starts ---
    root_x = {"str": -1100.0, "agi": 0.0, "faith": 1100.0}
    for reg, rx in root_x.items():
        sid = START_IDS[reg]
        add_node(nodes, sid, f"Корінь {REGIONS[['str','agi','faith'].index(reg)]['name']}", "start",
                 rx, Y_ROOT, reg, {reg: 5}, "Початок шляху класу.")

    # --- Trunk spine upward from each root toward crown center ---
    trunk = {"str": [], "agi": [], "faith": []}
    for reg, rx in root_x.items():
        prev = START_IDS[reg]
        steps = 14
        for i in range(1, steps + 1):
            t = i / steps
            # converge toward center as we rise
            x = rx * (1.0 - 0.55 * t) + RNG.uniform(-40, 40)
            y = Y_ROOT + (Y_TRUNK_TOP - Y_ROOT) * t + RNG.uniform(-30, 30)
            nid = f"{reg[0]}_t{i}"
            tier = tier_of_y(y)
            base = RNG.choice(TIER_STATS[reg])
            add_node(nodes, nid, names_small[reg][min(tier, 4)], "small", x, y, reg, scale_stats(dict(base), tier))
            link(links, prev, nid, seen)
            trunk[reg].append(nid)
            prev = nid

    # cross-links between trunks at mid height (border mix)
    for i in range(3, 12, 3):
        for a, b in (("str", "agi"), ("agi", "faith")):
            if i < len(trunk[a]) and i < len(trunk[b]):
                link(links, trunk[a][i], trunk[b][i], seen)
                # mix node between them
                na, nb = nodes[trunk[a][i]], nodes[trunk[b][i]]
                mx, my = (na["x"] + nb["x"]) / 2, (na["y"] + nb["y"]) / 2 - 40
                mid = f"mix_{a[0]}{b[0]}_{i}"
                stats = scale_stats({a: 2, b: 2} if a != "faith" else {a: 2, "faith": 2}, tier_of_y(my))
                # fix faith key
                if "faith" in (a, b):
                    stats = scale_stats({a: 2, "faith": 2} if a != "faith" else {"agi": 2, "faith": 2}, tier_of_y(my))
                if a == "str" and b == "agi":
                    stats = scale_stats({"str": 2, "agi": 2}, tier_of_y(my))
                add_node(nodes, mid, "Суміжний пагін", "small", mx, my, a, stats)
                link(links, trunk[a][i], mid, seen)
                link(links, mid, trunk[b][i], seen)

    # --- Side branches along trunks ---
    for reg, chain in trunk.items():
        for i, nid in enumerate(chain):
            if i < 2:
                continue
            n = nodes[nid]
            for side in (-1, 1):
                if RNG.random() < 0.35:
                    continue
                bx = n["x"] + side * RNG.uniform(90, 160)
                by = n["y"] + RNG.uniform(-80, 40)
                bid = f"{nid}_b{side+1}"
                tier = tier_of_y(by)
                add_node(nodes, bid, names_small[reg][min(tier, 4)], "small", bx, by, reg,
                         scale_stats(dict(RNG.choice(TIER_STATS[reg])), tier))
                link(links, nid, bid, seen)
                # maybe one more leaf
                if RNG.random() < 0.55:
                    lx = bx + side * RNG.uniform(70, 120)
                    ly = by + RNG.uniform(-70, 20)
                    lid = f"{bid}_l"
                    add_node(nodes, lid, names_small[reg][min(tier_of_y(ly), 4)], "small", lx, ly, reg,
                             scale_stats(dict(RNG.choice(TIER_STATS[reg])), tier_of_y(ly)))
                    link(links, bid, lid, seen)

    # --- Fruit clusters in crown ---
    fruit_id = 0
    for reg, notables in NOTABLES.items():
        rx = root_x[reg] * 0.35
        for ni, (name, stats) in enumerate(notables):
            # place fruits across crown band
            fx = rx + RNG.uniform(-380, 380) + (ni - 2.5) * 70
            fy = Y_CROWN + 180 + ni * 95 + RNG.uniform(-40, 40)
            # keep in crown
            fy = max(Y_CROWN + 40, min(Y_TRUNK_TOP - 80, fy))
            core_id = f"{reg[0]}_fruit{ni}"
            add_node(nodes, core_id, name, "notable", fx, fy, reg, dict(stats),
                     "Плід крони — помітний бонус.")
            # attach to nearest trunk top
            tops = [nodes[t] for t in trunk[reg][-4:]]
            near = nearest(tops, fx, fy)
            if near:
                link(links, near["id"], core_id, seen)
            # ring of smalls
            ring_n = 5 + (ni % 2)
            for j, (sx, sy) in enumerate(fruit_ring(fx, fy, ring_n, 95 + 10 * (ni % 3))):
                sid = f"{core_id}_s{j}"
                add_node(nodes, sid, names_small[reg][4], "small", sx, sy, reg,
                         scale_stats(dict(RNG.choice(TIER_STATS[reg])), 4))
                link(links, core_id, sid, seen)
                fruit_id += 1
            # sometimes link adjacent fruits
            if ni > 0:
                prev = f"{reg[0]}_fruit{ni-1}"
                if prev in nodes and abs(nodes[prev]["x"] - fx) < 420:
                    # bridge small
                    bx = (nodes[prev]["x"] + fx) / 2
                    by = (nodes[prev]["y"] + fy) / 2 - 30
                    brid = f"bridge_{reg[0]}_{ni}"
                    add_node(nodes, brid, "Гілка крони", "small", bx, by, reg,
                             scale_stats(dict(RNG.choice(TIER_STATS[reg])), 4))
                    link(links, prev, brid, seen)
                    link(links, brid, core_id, seen)

    # --- Keystones higher in crown ---
    for kid, reg, name, stats, ang in KEYSTONES:
        x = math.sin(ang) * 900
        y = Y_CROWN + 320 + abs(ang) * 200
        add_node(nodes, kid, name, "keystone", x, y, reg, dict(stats), "Ключовий вузол.")
        # connect to nearest fruit or trunk
        cands = [nodes[k] for k in nodes if nodes[k]["region"] == reg and nodes[k]["type"] in ("notable", "small")]
        near = nearest(cands, x, y)
        if near:
            link(links, near["id"], kid, seen)

    # --- Core at very top ---
    add_node(nodes, "core", "Серце роду", "core", 0, Y_CROWN - 80, "str",
             {"str": 5, "agi": 5, "faith": 5, "dmg_pct": 8, "hp_pct": 8, "res_all_pct": 5},
             "Вершина Древа роду.")
    # connect core to nearest keystones / fruits
    for kid, *_rest in KEYSTONES[:3]:
        if kid in nodes:
            link(links, kid, "core", seen)
    for reg in ("str", "agi", "faith"):
        fid = f"{reg[0]}_fruit5"
        if fid in nodes:
            link(links, fid, "core", seen)
        else:
            # last fruit
            last = f"{reg[0]}_fruit{len(NOTABLES[reg])-1}"
            if last in nodes:
                link(links, last, "core", seen)

    # Fill more mid-tree smalls to reach ~450+ nodes
    fill = 0
    existing = list(nodes.values())
    while len(nodes) < 460 and fill < 800:
        fill += 1
        base = RNG.choice(existing)
        if base["type"] == "core":
            continue
        ang = RNG.uniform(0, math.tau)
        dist = RNG.uniform(70, 140)
        x = base["x"] + math.cos(ang) * dist
        y = base["y"] + math.sin(ang) * dist * 0.8
        if y > Y_ROOT + 50 or y < Y_CROWN - 100:
            continue
        # avoid overlap
        if nearest(list(nodes.values()), x, y) and nearest(list(nodes.values()), x, y) and \
           ((nearest(list(nodes.values()), x, y)["x"] - x) ** 2 + (nearest(list(nodes.values()), x, y)["y"] - y) ** 2) < 55 ** 2:
            continue
        reg = base["region"]
        nid = f"fill_{fill}"
        tier = tier_of_y(y)
        add_node(nodes, nid, names_small[reg][min(tier, 4)], "small", x, y, reg,
                 scale_stats(dict(RNG.choice(TIER_STATS[reg])), tier))
        link(links, base["id"], nid, seen)
        existing.append(nodes[nid])

    # Ensure connectivity from each start via BFS — orphan attach
    from collections import deque
    def reachable(start):
        seen_n = {start}
        q = deque([start])
        adj = {}
        for a, b in links:
            adj.setdefault(a, []).append(b)
            adj.setdefault(b, []).append(a)
        while q:
            u = q.popleft()
            for v in adj.get(u, []):
                if v not in seen_n:
                    seen_n.add(v)
                    q.append(v)
        return seen_n
    all_ids = set(nodes)
    reach = set()
    for s in START_IDS.values():
        reach |= reachable(s)
    for oid in list(all_ids - reach):
        near = nearest([nodes[i] for i in reach], nodes[oid]["x"], nodes[oid]["y"])
        if near:
            link(links, near["id"], oid, seen)
            reach |= reachable(list(START_IDS.values())[0])
            # simpler: just add and mark
            reach.add(oid)

    node_list = list(nodes.values())
    # types count
    types = {}
    for n in node_list:
        types[n["type"]] = types.get(n["type"], 0) + 1

    data = {
        "format": "spohady-perk-tree",
        "version": 4,
        "title": "Древо звитяги",
        "comment": "v4: коріння внизу, крона вгорі, плоди-кластери, суміш на стиках регіонів.",
        "regions": REGIONS,
        "class_starts": CLASS_STARTS,
        "nodes": node_list,
        "links": links,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print("nodes", len(node_list), "links", len(links), "types", types)
    print("y range", min(n["y"] for n in node_list), max(n["y"] for n in node_list))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
