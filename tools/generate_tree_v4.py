#!/usr/bin/env python3
"""v4 tree: clear silhouette — roots bottom, trunk, spreading branches, crown fruits."""
from __future__ import annotations
import json, math, random
from pathlib import Path
from collections import deque

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "perk_tree.json"
RNG = random.Random(40531)

Y_ROOT = 2400
Y_CROWN = -2600
Y_TRUNK_MID = 200
Y_CROWN_BASE = -900

REGIONS = [
    {"id": "str", "name": "Сила", "color": "#D8574B"},
    {"id": "agi", "name": "Спритність", "color": "#7CBF5A"},
    {"id": "faith", "name": "Віра", "color": "#E0A526"},
]
CLASS_STARTS = {"druzhynnyk": "s_root", "strilets": "a_root", "volkhv": "f_root"}
START_IDS = {"str": "s_root", "agi": "a_root", "faith": "f_root"}
ROOT_X = {"str": -520.0, "agi": 0.0, "faith": 520.0}

TIER_STATS = {
    "str": [
        {"str": 3}, {"str": 4}, {"armor": 8}, {"hp": 15}, {"dmg_pct": 4},
        {"block_pct": 2}, {"dr_pct": 2}, {"lifesteal_pct": 1}, {"thorns_pct": 2},
        {"armor_pen_pct": 3}, {"res_all_pct": 2}, {"pen_all_pct": 2},
    ],
    "agi": [
        {"agi": 3}, {"agi": 4}, {"crit_pct": 2}, {"crit_dmg_pct": 6}, {"move_pct": 3},
        {"dodge_pct": 2}, {"atk_speed_pct": 3}, {"proj_speed_pct": 4}, {"dmg_pct": 3},
        {"drop_pct": 3}, {"pen_all_pct": 2}, {"nauz_xp_pct": 5},
    ],
    "faith": [
        {"faith": 3}, {"faith": 4}, {"mana_pct": 4}, {"mana_regen": 0.3}, {"hp_pct": 3},
        {"cdr_pct": 3}, {"aoe_pct": 4}, {"effect_dur_pct": 4}, {"skill_cost_pct": -3},
        {"res_all_pct": 3}, {"nauz_level": 1}, {"thread_power_pct": 6}, {"xp_pct": 4},
    ],
}

FRUITS = {
    "str": [
        ("Щит роду", {"armor": 25, "block_pct": 6, "dr_pct": 4}, "броня"),
        ("Кривавий удар", {"dmg_pct": 12, "lifesteal_pct": 3}, "кров"),
        ("Пробивач", {"armor_pen_pct": 12, "pen_all_pct": 6}, "пробиття"),
        ("Залізна шкіра", {"hp": 40, "res_all_pct": 5}, "опір"),
        ("Щедра здобич", {"gold_pct": 20, "drop_pct": 15}, "здобич"),
    ],
    "agi": [
        ("Тінь вовка", {"move_pct": 10, "dodge_pct": 6, "atk_speed_pct": 8}, "рух"),
        ("Влучне око", {"crit_pct": 6, "crit_dmg_pct": 20}, "крит"),
        ("Град стріл", {"proj_speed_pct": 12, "dmg_pct": 8}, "снаряди"),
        ("Шлях учня", {"xp_pct": 15}, "звитяга"),
        ("Щедра здобич", {"gold_pct": 20, "drop_pct": 15}, "здобич"),
    ],
    "faith": [
        ("Коло пращурів", {"aoe_pct": 12, "effect_dur_pct": 10}, "площа"),
        ("Нитка долі", {"thread_power_pct": 18, "nauz_xp_pct": 12}, "нитки"),
        ("Сила науза", {"nauz_level": 1, "nauz_xp_pct": 10}, "наузи"),
        ("Опір стихіям", {"res_all_pct": 10}, "опір"),
        ("Шлях учня", {"xp_pct": 15}, "звитяга"),
    ],
}

KEYSTONES = [
    ("s_ks1", "str", "Один шлях", {"one_path": 1, "thread_power_pct": 40}, -0.85),
    ("s_ks2", "str", "Кривава данина", {"life_pay_skills": 1, "dmg_pct": 15}, -0.5),
    ("a_ks1", "agi", "Смертельна тінь", {"crit_stun": 1, "crit_pct": 8}, 0.0),
    ("a_ks2", "agi", "Блок без щита", {"block_no_shield": 1, "dodge_pct": 8}, 0.35),
    ("f_ks1", "faith", "Вільні вміння", {"free_skills": 1, "mana_pct": 10}, 0.55),
    ("f_ks2", "faith", "Жага вбивства", {"kill_haste": 1, "atk_speed_pct": 12}, 0.85),
    ("c_ks1", "str", "Серце війни", {"dmg_pct": 10, "hp_pct": 8, "res_all_pct": 5}, -0.2),
    ("c_ks2", "agi", "Серце полювання", {"crit_dmg_pct": 25, "move_pct": 8}, 0.15),
    ("c_ks3", "faith", "Серце віри", {"nauz_level": 1, "cdr_pct": 10}, 0.4),
]

NAMES = {
    "str": ["Корінь сили", "Жила сили", "Сучок сили", "Пагін сили", "Лист сили"],
    "agi": ["Корінь спритності", "Жила спритності", "Сучок спритності", "Пагін спритності", "Лист спритності"],
    "faith": ["Корінь віри", "Жила віри", "Сучок віри", "Пагін віри", "Лист віри"],
}


def tier_of_y(y: float) -> int:
    t = (Y_ROOT - y) / (Y_ROOT - Y_CROWN)
    return int(max(0, min(4, math.floor(t * 5))))


def scale_stats(stats: dict, tier: int) -> dict:
    out = {}
    mult = 1.0 + 0.22 * tier
    skip = {"one_path", "life_pay_skills", "free_skills", "crit_stun", "block_no_shield", "kill_haste", "nauz_level", "nauz_thread_slots"}
    for k, v in stats.items():
        if isinstance(v, (int, float)) and k not in skip:
            nv = v * mult
            out[k] = int(round(nv)) if abs(nv) >= 2 or isinstance(v, int) else round(nv, 1)
        else:
            out[k] = v
    return out


def add_node(nodes, nid, name, typ, x, y, region, stats, desc=""):
    nodes[nid] = {
        "id": nid, "name": name, "description": desc or "Вузол Древа звитяги.",
        "x": round(x, 1), "y": round(y, 1),
        "type": typ, "stats": stats, "skill": "", "icon": "", "region": region,
    }


def link(links, seen, a, b):
    key = tuple(sorted((a, b)))
    if a == b or key in seen:
        return
    seen.add(key)
    links.append([a, b])


def nearest(cands, x, y):
    best, bd = None, 1e18
    for c in cands:
        d = (c["x"] - x) ** 2 + (c["y"] - y) ** 2
        if d < bd:
            bd, best = d, c
    return best


def fruit_ring(cx, cy, n, radius):
    pts = []
    for i in range(n):
        a = (i / n) * math.tau + RNG.uniform(-0.05, 0.05)
        r = radius + RNG.uniform(-8, 8)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r * 0.72))
    return pts


def main():
    nodes, links, seen = {}, [], set()

    # --- Roots (bottom) ---
    for reg, rx in ROOT_X.items():
        sid = START_IDS[reg]
        add_node(nodes, sid, f"Корінь · { {'str':'Сила','agi':'Спритність','faith':'Віра'}[reg] }",
                 "start", rx, Y_ROOT, reg, {reg: 5}, "Початок шляху класу в корінні Древа.")

    # Connect roots into a root ball (horizontal)
    link(links, seen, "s_root", "a_root")
    link(links, seen, "a_root", "f_root")
    # small rootlets
    for reg, rx in ROOT_X.items():
        for i in range(3):
            ang = math.pi * 0.15 + i * 0.35  # downward-ish fans
            nid = f"{reg[0]}_rootlet{i}"
            x = rx + math.cos(ang + (0 if reg != 'faith' else math.pi)) * (70 + i * 35) * (1 if reg != 'str' else -1)
            if reg == "agi":
                x = rx + (i - 1) * 90
            y = Y_ROOT + 80 + i * 40
            add_node(nodes, nid, NAMES[reg][0], "small", x, y, reg,
                     scale_stats(dict(RNG.choice(TIER_STATS[reg])), 0), "Корінець.")
            link(links, seen, START_IDS[reg], nid)

    # --- Trunk: three braided spines that converge upward ---
    trunk = {"str": [], "agi": [], "faith": []}
    STEPS = 16
    for reg, rx0 in ROOT_X.items():
        prev = START_IDS[reg]
        for i in range(1, STEPS + 1):
            t = i / STEPS
            # converge strongly toward x=0 as we rise
            converge = t ** 1.15
            x = rx0 * (1.0 - 0.92 * converge) + RNG.uniform(-18, 18)
            y = Y_ROOT + (Y_CROWN_BASE - Y_ROOT) * t
            # slight S-curve for organic trunk
            x += math.sin(t * math.pi) * (40 if reg == "agi" else (-35 if reg == "str" else 35))
            nid = f"{reg[0]}_t{i}"
            tier = tier_of_y(y)
            add_node(nodes, nid, NAMES[reg][min(tier, 4)], "small", x, y, reg,
                     scale_stats(dict(RNG.choice(TIER_STATS[reg])), tier), "Стовбур Древа.")
            link(links, seen, prev, nid)
            trunk[reg].append(nid)
            prev = nid

    # Cross-brace trunks mid-height (thin mix band, not messy)
    for i in (4, 8, 12):
        for a, b in (("str", "agi"), ("agi", "faith")):
            if i <= len(trunk[a]) and i <= len(trunk[b]):
                na, nb = nodes[trunk[a][i - 1]], nodes[trunk[b][i - 1]]
                mx, my = (na["x"] + nb["x"]) / 2, (na["y"] + nb["y"]) / 2 - 25
                mid = f"mix_{a[0]}{b[0]}_{i}"
                stats = scale_stats({"str": 2, "agi": 2} if b == "agi" and a == "str" else {"agi": 2, "faith": 2}, tier_of_y(my))
                add_node(nodes, mid, "Суміжний пагін", "small", mx, my, a, stats, "Стик гілок класів.")
                link(links, seen, trunk[a][i - 1], mid)
                link(links, seen, mid, trunk[b][i - 1])

    # --- Side branches: spread wider with height ---
    for reg, chain in trunk.items():
        for i, nid in enumerate(chain):
            t = (i + 1) / len(chain)
            if t < 0.12:
                continue
            spread = 110 + 420 * (t ** 1.3)
            n = nodes[nid]
            for side in (-1, 1):
                if RNG.random() < 0.22:
                    continue
                length = spread * RNG.uniform(0.35, 0.7)
                bx = n["x"] + side * length
                by = n["y"] - RNG.uniform(20, 90)  # tip slightly higher
                bid = f"{nid}_b{'L' if side < 0 else 'R'}"
                tier = tier_of_y(by)
                add_node(nodes, bid, NAMES[reg][min(tier, 4)], "small", bx, by, reg,
                         scale_stats(dict(RNG.choice(TIER_STATS[reg])), tier), "Гілка.")
                link(links, seen, nid, bid)
                # secondary twig
                if t > 0.35 and RNG.random() < 0.65:
                    tx = bx + side * RNG.uniform(60, 140)
                    ty = by - RNG.uniform(30, 100)
                    tid = f"{bid}_tw"
                    add_node(nodes, tid, NAMES[reg][min(tier_of_y(ty), 4)], "small", tx, ty, reg,
                             scale_stats(dict(RNG.choice(TIER_STATS[reg])), tier_of_y(ty)), "Гілочка.")
                    link(links, seen, bid, tid)

    # --- Crown fruits ---
    fruit_meta = []  # for renderer labels
    for reg, fruits in FRUITS.items():
        base_x = ROOT_X[reg] * 0.55
        for ni, (name, stats, theme) in enumerate(fruits):
            # arc across crown
            ang = -0.9 + (ni / max(1, len(fruits) - 1)) * 1.8
            if reg == "str":
                ang -= 0.55
            elif reg == "faith":
                ang += 0.55
            fx = math.sin(ang) * (380 + ni * 40) + base_x * 0.2
            fy = Y_CROWN + 220 + abs(ang) * 180 + ni * 55
            fy = max(Y_CROWN + 60, min(Y_CROWN_BASE - 40, fy))
            core_id = f"{reg[0]}_fruit{ni}"
            add_node(nodes, core_id, name, "notable", fx, fy, reg, dict(stats),
                     f"Плід крони («{theme}»).")
            fruit_meta.append({"id": core_id, "theme": theme, "name": name, "region": reg})
            # attach to nearest upper trunk / branch of same region
            cands = [nodes[k] for k in trunk[reg][-5:]]
            cands += [nodes[k] for k in nodes if k.startswith(f"{reg[0]}_t") and "_b" in k]
            near = nearest(cands, fx, fy)
            if near:
                link(links, seen, near["id"], core_id)
            for j, (sx, sy) in enumerate(fruit_ring(fx, fy, 6, 100)):
                sid = f"{core_id}_s{j}"
                add_node(nodes, sid, NAMES[reg][4], "small", sx, sy, reg,
                         scale_stats(dict(RNG.choice(TIER_STATS[reg])), 4), f"Навколо плоду «{theme}».")
                link(links, seen, core_id, sid)

    # bridges between nearby fruits same region
    by_reg = {}
    for fm in fruit_meta:
        by_reg.setdefault(fm["region"], []).append(fm["id"])
    for reg, ids in by_reg.items():
        for i in range(len(ids) - 1):
            a, b = nodes[ids[i]], nodes[ids[i + 1]]
            if abs(a["x"] - b["x"]) < 520:
                brid = f"cbridge_{reg[0]}_{i}"
                add_node(nodes, brid, "Гілка крони", "small",
                         (a["x"] + b["x"]) / 2, (a["y"] + b["y"]) / 2 - 40, reg,
                         scale_stats(dict(RNG.choice(TIER_STATS[reg])), 4), "Зв'язок плодів.")
                link(links, seen, ids[i], brid)
                link(links, seen, brid, ids[i + 1])

    # Keystones in upper crown
    for kid, reg, name, stats, ang in KEYSTONES:
        x = math.sin(ang) * 720
        y = Y_CROWN + 280 + abs(ang) * 160
        add_node(nodes, kid, name, "keystone", x, y, reg, dict(stats), "Ключовий вузол крони.")
        cands = [nodes[k] for k in nodes if nodes[k]["region"] == reg and nodes[k]["type"] in ("notable", "small")]
        near = nearest(cands, x, y)
        if near:
            link(links, seen, near["id"], kid)

    # Core apex
    add_node(nodes, "core", "Серце роду", "core", 0, Y_CROWN - 40, "str",
             {"str": 5, "agi": 5, "faith": 5, "dmg_pct": 8, "hp_pct": 8, "res_all_pct": 5},
             "Вершина Древа роду.")
    for kid, *_ in KEYSTONES[:3]:
        if kid in nodes:
            link(links, seen, kid, "core")
    for reg in ("str", "agi", "faith"):
        last = f"{reg[0]}_fruit{len(FRUITS[reg]) - 1}"
        if last in nodes:
            link(links, seen, last, "core")

    # Fill to ~420–480 along existing structure (prefer near branches)
    existing = list(nodes.values())
    fill = 0
    while len(nodes) < 440 and fill < 900:
        fill += 1
        base = RNG.choice(existing)
        if base["type"] in ("core", "start"):
            continue
        ang = RNG.uniform(0, math.tau)
        dist = RNG.uniform(55, 120)
        x = base["x"] + math.cos(ang) * dist
        y = base["y"] + math.sin(ang) * dist * 0.7
        if y > Y_ROOT + 120 or y < Y_CROWN - 80:
            continue
        near = nearest(list(nodes.values()), x, y)
        if near and (near["x"] - x) ** 2 + (near["y"] - y) ** 2 < 48 ** 2:
            continue
        reg = base["region"]
        nid = f"fill_{fill}"
        tier = tier_of_y(y)
        add_node(nodes, nid, NAMES[reg][min(tier, 4)], "small", x, y, reg,
                 scale_stats(dict(RNG.choice(TIER_STATS[reg])), tier))
        link(links, seen, base["id"], nid)
        existing.append(nodes[nid])

    # Connectivity repair from starts
    def reachable(starts):
        adj = {}
        for a, b in links:
            adj.setdefault(a, []).append(b)
            adj.setdefault(b, []).append(a)
        seen_n = set(starts)
        q = deque(starts)
        while q:
            u = q.popleft()
            for v in adj.get(u, []):
                if v not in seen_n:
                    seen_n.add(v)
                    q.append(v)
        return seen_n

    reach = reachable(list(START_IDS.values()))
    for oid in list(set(nodes) - reach):
        near = nearest([nodes[i] for i in reach], nodes[oid]["x"], nodes[oid]["y"])
        if near:
            link(links, seen, near["id"], oid)
            reach.add(oid)

    node_list = list(nodes.values())
    types = {}
    for n in node_list:
        types[n["type"]] = types.get(n["type"], 0) + 1

    layout = {
        "y_root": Y_ROOT, "y_crown": Y_CROWN, "y_crown_base": Y_CROWN_BASE,
        "bands": [
            {"id": "roots", "name": "Коріння", "y0": Y_ROOT - 50, "y1": Y_ROOT + 200},
            {"id": "trunk", "name": "Стовбур", "y0": Y_TRUNK_MID, "y1": Y_ROOT - 50},
            {"id": "boughs", "name": "Гілля", "y0": Y_CROWN_BASE, "y1": Y_TRUNK_MID},
            {"id": "crown", "name": "Крона", "y0": Y_CROWN - 100, "y1": Y_CROWN_BASE},
        ],
    }
    data = {
        "format": "spohady-perk-tree",
        "version": 4,
        "title": "Древо звитяги",
        "comment": "v4: коріння внизу, стовбур, гілки, крона з плодами.",
        "regions": REGIONS,
        "class_starts": CLASS_STARTS,
        "nodes": node_list,
        "links": links,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    (ROOT / "data" / "perk_tree_meta.json").write_text(
        json.dumps({"fruits": fruit_meta, "layout": layout}, ensure_ascii=False, indent=2) + "\n")
    print("nodes", len(node_list), "links", len(links), "types", types)
    print("y", min(n["y"] for n in node_list), max(n["y"] for n in node_list))


if __name__ == "__main__":
    main()
