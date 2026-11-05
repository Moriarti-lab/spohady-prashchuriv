#!/usr/bin/env python3
"""v4 tree: Yggdrasil silhouette — wide roots → one braided trunk → round dense canopy.
Colours: Сила red / Спритність green / Віра gold; mixing in trunk & inner branches.
"""
from __future__ import annotations
import json, math, random
from pathlib import Path
from collections import deque, defaultdict

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "perk_tree.json"
META = ROOT / "data" / "perk_tree_meta.json"
RNG = random.Random(40533)

# Y: larger = roots (bottom), smaller = crown (top). Total span ~5600.
Y_ROOT_TIP = 2200       # deepest rootlets
Y_ROOT_BAND = 1550      # class starts sit around here
Y_TRUNK_BASE = 450      # roots converge into trunk
Y_TRUNK_TOP = -350      # trunk flares into canopy
Y_CROWN = -2100         # apex («Серце роду»)
# Canopy = top ~42% of (Y_ROOT_TIP - Y_CROWN) ≈ 5600 → ~2350 units from -2700 to -350

MIN_DIST = 68.0
MAX_EDGE = 152.0

REGIONS = [
    {"id": "str", "name": "Сила", "color": "#D8574B"},
    {"id": "agi", "name": "Спритність", "color": "#7CBF5A"},
    {"id": "faith", "name": "Віра", "color": "#E0A526"},
]
CLASS_STARTS = {"druzhynnyk": "s_root", "strilets": "a_root", "volkhv": "f_root"}
START_IDS = {"str": "s_root", "agi": "a_root", "faith": "f_root"}
# wide root flare — class starts spread along the root system
ROOT_X = {"str": -1050.0, "agi": 0.0, "faith": 1050.0}
CYCLE = ["str", "agi", "faith"]

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
    "mix": [
        {"str": 2, "agi": 2}, {"agi": 2, "faith": 2}, {"str": 2, "faith": 2},
        {"dmg_pct": 3, "hp_pct": 2}, {"res_all_pct": 2, "pen_all_pct": 2},
        {"nauz_xp_pct": 4}, {"cdr_pct": 2, "atk_speed_pct": 2},
    ],
}

FRUITS = [
    ("Щит роду", {"armor": 25, "block_pct": 6, "dr_pct": 4}, "броня", "str", 0.06),
    ("Кривавий удар", {"dmg_pct": 12, "lifesteal_pct": 3}, "кров", "str", 0.14),
    ("Пробивач", {"armor_pen_pct": 12, "pen_all_pct": 6}, "пробиття", "str", 0.22),
    ("Залізна шкіра", {"hp": 40, "res_all_pct": 5}, "опір", "str", 0.30),
    ("Тінь вовка", {"move_pct": 10, "dodge_pct": 6, "atk_speed_pct": 8}, "рух", "agi", 0.38),
    ("Влучне око", {"crit_pct": 6, "crit_dmg_pct": 20}, "крит", "agi", 0.46),
    ("Град стріл", {"proj_speed_pct": 12, "dmg_pct": 8}, "снаряди", "agi", 0.54),
    ("Шлях учня", {"xp_pct": 15}, "звитяга", "agi", 0.62),
    ("Коло пращурів", {"aoe_pct": 12, "effect_dur_pct": 10}, "площа", "faith", 0.70),
    ("Нитка долі", {"thread_power_pct": 18, "nauz_xp_pct": 12}, "нитки", "faith", 0.78),
    ("Сила науза", {"nauz_level": 1, "nauz_xp_pct": 10}, "наузи", "faith", 0.86),
    ("Опір стихіям", {"res_all_pct": 10}, "опір", "faith", 0.94),
    ("Щедра здобич", {"gold_pct": 20, "drop_pct": 15}, "здобич", "agi", 0.10),
    ("Бойовий дух", {"dmg_pct": 8, "hp_pct": 6}, "бій", "str", 0.50),
    ("Ясне око", {"crit_pct": 4, "proj_speed_pct": 8}, "зір", "agi", 0.90),
]

KEYSTONES = [
    ("ks_one", "mix", "Один шлях", {"one_path": 1, "thread_power_pct": 40}, 0.20),
    ("ks_blood", "str", "Кривава данина", {"life_pay_skills": 1, "dmg_pct": 15}, 0.35),
    ("ks_shadow", "agi", "Смертельна тінь", {"crit_stun": 1, "crit_pct": 8}, 0.50),
    ("ks_free", "faith", "Вільні вміння", {"free_skills": 1, "mana_pct": 10}, 0.65),
    ("ks_war", "mix", "Серце війни", {"dmg_pct": 10, "hp_pct": 8, "res_all_pct": 5}, 0.12),
    ("ks_hunt", "agi", "Серце полювання", {"crit_dmg_pct": 25, "move_pct": 8}, 0.80),
    ("ks_faith", "faith", "Серце віри", {"nauz_level": 1, "cdr_pct": 10}, 0.92),
]

NAMES = {
    "str": ["Корінь сили", "Жила сили", "Сучок сили", "Пагін сили", "Лист сили"],
    "agi": ["Корінь спритності", "Жила спритності", "Сучок спритності", "Пагін спритності", "Лист спритності"],
    "faith": ["Корінь віри", "Жила віри", "Сучок віри", "Пагін віри", "Лист віри"],
    "mix": ["Сплетення", "Жила роду", "Сучок роду", "Пагін роду", "Лист роду"],
}


def tier_of_y(y: float) -> int:
    t = (Y_ROOT_TIP - y) / (Y_ROOT_TIP - Y_CROWN)
    return int(max(0, min(4, math.floor(t * 5))))


def scale_stats(stats: dict, tier: int) -> dict:
    out = {}
    mult = 1.0 + 0.22 * tier
    skip = {"one_path", "life_pay_skills", "free_skills", "crit_stun", "block_no_shield",
            "kill_haste", "nauz_level", "nauz_thread_slots"}
    for k, v in stats.items():
        if isinstance(v, (int, float)) and k not in skip:
            nv = v * mult
            out[k] = int(round(nv)) if abs(nv) >= 2 or isinstance(v, int) else round(nv, 1)
        else:
            out[k] = v
    return out


class Builder:
    def __init__(self):
        self.nodes = {}
        self.links = []
        self.seen = set()
        self.seq = 0

    def add(self, nid, name, typ, x, y, region, stats, desc="", force=False):
        if not force:
            x, y = self._place(x, y)
        self.nodes[nid] = {
            "id": nid, "name": name, "description": desc or "Вузол Древа звитяги.",
            "x": 0.0 if abs(x) < 0.05 else round(x, 1), "y": 0.0 if abs(y) < 0.05 else round(y, 1),
            "type": typ, "stats": stats, "skill": "", "icon": "", "region": region,
        }
        return self.nodes[nid]

    def _place(self, x, y, tries=50):
        for _ in range(tries):
            ok = True
            for n in self.nodes.values():
                if (n["x"] - x) ** 2 + (n["y"] - y) ** 2 < MIN_DIST ** 2:
                    ok = False
                    break
            if ok:
                return x, y
            x += RNG.uniform(-MIN_DIST * 0.45, MIN_DIST * 0.45)
            y += RNG.uniform(-MIN_DIST * 0.35, MIN_DIST * 0.35)
        return x, y

    def link(self, a, b):
        if a == b or a not in self.nodes or b not in self.nodes:
            return
        key = tuple(sorted((a, b)))
        if key in self.seen:
            return
        self.seen.add(key)
        ax, ay = self.nodes[a]["x"], self.nodes[a]["y"]
        bx, by = self.nodes[b]["x"], self.nodes[b]["y"]
        dist = math.hypot(bx - ax, by - ay)
        if dist <= MAX_EDGE:
            self.links.append([a, b])
            return
        steps = int(math.ceil(dist / MAX_EDGE))
        prev = a
        reg_a = self.nodes[a]["region"]
        reg_b = self.nodes[b]["region"]
        for i in range(1, steps):
            t = i / steps
            x = ax + (bx - ax) * t
            y = ay + (by - ay) * t
            # slight bend; pull mid-segments toward x=0 for trunk cohesion
            nx = -(by - ay) / max(dist, 1)
            bend = 14 * math.sin(t * math.pi)
            x = x * (0.97 + 0.03 * abs(0.5 - t) * 2)
            x += nx * bend
            self.seq += 1
            mid = f"seg_{self.seq}"
            if reg_a != reg_b:
                # mixing zone: alternate colours along the braid
                reg = CYCLE[self.seq % 3] if RNG.random() < 0.55 else (reg_a if t < 0.5 else reg_b)
                pool = TIER_STATS["mix"]
                name_key = "mix"
            else:
                reg = reg_a if t < 0.5 else reg_b
                pool = TIER_STATS.get(reg, TIER_STATS["mix"])
                name_key = reg if reg in NAMES else "mix"
            tier = tier_of_y(y)
            self.add(mid, NAMES[name_key][min(tier, 4)], "small", x, y, reg,
                     scale_stats(dict(RNG.choice(pool)), tier),
                     "Сплетення шляхів." if reg_a != reg_b else "Гілка.")
            self.links.append([prev, mid])
            self.seen.add(tuple(sorted((prev, mid))))
            prev = mid
        self.links.append([prev, b])
        self.seen.add(tuple(sorted((prev, b))))

    def harden_edges(self, max_edge=MAX_EDGE):
        changed = True
        guard = 0
        while changed and guard < 10:
            guard += 1
            changed = False
            old = list(self.links)
            self.links = []
            self.seen = set()
            for a, b in old:
                if a not in self.nodes or b not in self.nodes:
                    continue
                ax, ay = self.nodes[a]["x"], self.nodes[a]["y"]
                bx, by = self.nodes[b]["x"], self.nodes[b]["y"]
                dist = math.hypot(bx - ax, by - ay)
                if dist <= max_edge:
                    key = tuple(sorted((a, b)))
                    if key not in self.seen:
                        self.seen.add(key)
                        self.links.append([a, b])
                    continue
                changed = True
                steps = max(2, int(math.ceil(dist / max_edge)))
                prev = a
                for i in range(1, steps):
                    tt = i / steps
                    x = ax + (bx - ax) * tt
                    y = ay + (by - ay) * tt
                    self.seq += 1
                    mid = f"fill_{self.seq}"
                    while mid in self.nodes:
                        self.seq += 1
                        mid = f"fill_{self.seq}"
                    reg = self.nodes[a]["region"] if tt < 0.5 else self.nodes[b]["region"]
                    tier = tier_of_y(y)
                    pool = TIER_STATS.get(reg, TIER_STATS["mix"])
                    self.nodes[mid] = {
                        "id": mid, "name": NAMES.get(reg, NAMES["mix"])[min(tier, 4)],
                        "description": "Гілка.",
                        "x": 0.0 if abs(x) < 0.05 else round(x, 1), "y": 0.0 if abs(y) < 0.05 else round(y, 1),
                        "type": "small", "stats": scale_stats(dict(RNG.choice(pool)), tier),
                        "skill": "", "icon": "", "region": reg,
                    }
                    key = tuple(sorted((prev, mid)))
                    self.seen.add(key)
                    self.links.append([prev, mid])
                    prev = mid
                key = tuple(sorted((prev, b)))
                self.seen.add(key)
                self.links.append([prev, b])


def canopy_pos(frac: float, radius_scale: float = 1.0):
    """Wide rounded dome: frac 0..1 left→right across upper semicircle."""
    ang = math.pi * (0.06 + 0.88 * frac)
    rx = 1350 * radius_scale
    ry = 920 * radius_scale
    cx, cy = 0.0, (Y_CROWN + Y_TRUNK_TOP) * 0.38
    x = cx + math.cos(ang) * rx
    y = cy - math.sin(ang) * ry
    y = max(Y_CROWN + 60, min(Y_TRUNK_TOP - 30, y))
    return x, y


def main():
    B = Builder()

    # ========== WIDE LUSH ROOT SYSTEM ==========
    root_names = {"str": "Сила", "agi": "Спритність", "faith": "Віра"}
    for reg, rx in ROOT_X.items():
        B.add(START_IDS[reg], f"Корінь · {root_names[reg]}",
              "start", rx, Y_ROOT_BAND, reg, {reg: 5}, "Початок шляху класу.", force=True)

    root_nodes = list(START_IDS.values())
    # Many root arms per class: downward fan + side roots + forks
    for reg, rx in ROOT_X.items():
        start = START_IDS[reg]
        for arm in range(8):
            ang = math.pi * (0.15 + 0.70 * (arm / 7.0))  # down-ish semicircle
            # mirror so left class fans left-down, right class right-down, center both
            if reg == "str":
                dir_x = -abs(math.cos(ang))
            elif reg == "faith":
                dir_x = abs(math.cos(ang))
            else:
                dir_x = math.cos(ang) * (1 if arm % 2 == 0 else -1)
            dir_y = abs(math.sin(ang))
            prev = start
            segs = 4 if arm < 5 else 3
            length = 280 + arm * 35
            for s in range(1, segs + 1):
                tt = s / segs
                x = rx + dir_x * length * tt * (1.0 + 0.35 * tt)
                y = Y_ROOT_BAND + dir_y * length * tt + 40 * tt
                # keep within tip bound
                y = min(y, Y_ROOT_TIP - 40)
                nid = f"{reg[0]}_arm{arm}_{s}"
                B.add(nid, NAMES[reg][0], "small", x, y, reg,
                      scale_stats(dict(RNG.choice(TIER_STATS[reg])), 0), "Корінець.")
                B.link(prev, nid)
                prev = nid
                root_nodes.append(nid)
                # side fork
                if s == 2:
                    fork = f"{reg[0]}_arm{arm}_f"
                    fx = x + dir_x * 70 + (-1 if arm % 2 == 0 else 1) * 80
                    fy = y + 90
                    B.add(fork, NAMES[reg][0], "small", fx, fy, reg,
                          scale_stats(dict(RNG.choice(TIER_STATS[reg])), 0), "Бічний корінь.")
                    B.link(nid, fork)
                    root_nodes.append(fork)

    # Dense cross-links between nearby root nodes (web, not 3 lines)
    for a in list(root_nodes):
        if a not in B.nodes:
            continue
        na = B.nodes[a]
        near = []
        for b in root_nodes:
            if a == b or b not in B.nodes:
                continue
            nb = B.nodes[b]
            d = math.hypot(na["x"] - nb["x"], na["y"] - nb["y"])
            if 70 < d < 220:
                near.append((d, b))
        near.sort()
        for _, b in near[:3]:
            B.link(a, b)

    # Soft bridges between class starts
    B.link("s_root", "a_root")
    B.link("a_root", "f_root")

    # ========== CONVERGE → MASSIVE BRAIDED TRUNK ==========
    converge_ids = {}
    for reg, rx in ROOT_X.items():
        prev = START_IDS[reg]
        steps = 6
        for i in range(1, steps + 1):
            t = i / steps
            x = rx * (1.0 - t) ** 1.15
            y = Y_ROOT_BAND + (Y_TRUNK_BASE - Y_ROOT_BAND) * t
            x += math.sin(t * math.pi * 2.2 + {"str": 0, "agi": 2.0, "faith": 4.0}[reg]) * 40 * (1 - t)
            nid = f"{reg[0]}_conv{i}"
            use_reg = reg if t < 0.5 else CYCLE[(CYCLE.index(reg) + i) % 3]
            pool = TIER_STATS["mix"] if t >= 0.4 else TIER_STATS[reg]
            B.add(nid, NAMES["mix" if t >= 0.4 else reg][min(tier_of_y(y), 4)], "small",
                  x, y, use_reg,
                  scale_stats(dict(RNG.choice(pool)), tier_of_y(y)),
                  "Шлях до стовбура." if t < 0.5 else "Сплетення коріння.")
            B.link(prev, nid)
            # lateral weave toward neighbours
            if i >= 3:
                for other in CYCLE:
                    if other == reg:
                        continue
                    oid = f"{other[0]}_conv{i}"
                    if oid in B.nodes:
                        B.link(nid, oid)
            prev = nid
        converge_ids[reg] = prev

    B.add("trunk0", "Сплетення коріння", "keystone", 0, Y_TRUNK_BASE, "agi",
          scale_stats(dict(RNG.choice(TIER_STATS["mix"])), 1),
          "Три шляхи сходяться в один стовбур.")
    for reg in CYCLE:
        B.link(converge_ids[reg], "trunk0")

    # 5-strand massive braid: 3 class colours + 2 mix companions; frequent rungs; taper
    TRUNK_STEPS = 12
    STRANDS = [
        ("s", "str", -1.0),
        ("m1", "agi", -0.45),
        ("c", "agi", 0.0),
        ("m2", "faith", 0.45),
        ("f", "faith", 1.0),
    ]
    strand_prev = {key: "trunk0" for key, _, _ in STRANDS}
    trunk_spine = ["trunk0"]
    for i in range(1, TRUNK_STEPS + 1):
        t = i / TRUNK_STEPS
        y = Y_TRUNK_BASE + (Y_TRUNK_TOP - Y_TRUNK_BASE) * t
        # wide at base, taper mid, slight flare at top into canopy
        rad = 130 * (1.0 - 0.45 * t) + 25 * math.sin(t * math.pi)
        if t > 0.85:
            rad += 35 * ((t - 0.85) / 0.15)
        phase = t * math.pi * 2.6
        step_ids = []
        for si, (key, reg, lane) in enumerate(STRANDS):
            weave = math.sin(phase + si * 0.9) * 18
            x = lane * rad + weave
            nid = f"trunk_{key}{i}"
            B.add(nid, NAMES["mix"][min(tier_of_y(y), 4)], "small", x, y, reg,
                  scale_stats(dict(RNG.choice(TIER_STATS["mix"])), tier_of_y(y)),
                  "Стовбур роду — сплетення шляхів.")
            B.link(strand_prev[key], nid)
            strand_prev[key] = nid
            step_ids.append(nid)
        # rungs: link every neighbouring strand this step + every other skip
        for a, b in zip(step_ids, step_ids[1:]):
            B.link(a, b)
        if i % 2 == 0 and len(step_ids) >= 4:
            B.link(step_ids[0], step_ids[2])
            B.link(step_ids[1], step_ids[3])
            B.link(step_ids[2], step_ids[-1])
        trunk_spine.append(step_ids[2])  # center

    trunk_top_nodes = [strand_prev[k] for k, _, _ in STRANDS]

    # ========== PRIMARY BRANCHES → ROUND CANOPY ==========
    branch_tips = []
    N_BRANCHES = 16
    for bi in range(N_BRANCHES):
        attach_t = 0.5 + 0.48 * (bi / max(N_BRANCHES - 1, 1))
        attach_i = max(1, min(TRUNK_STEPS, int(attach_t * TRUNK_STEPS)))
        attach_key = STRANDS[bi % len(STRANDS)][0]
        attach = f"trunk_{attach_key}{attach_i}"
        if attach not in B.nodes:
            attach = trunk_top_nodes[bi % len(trunk_top_nodes)]
        ax, ay = B.nodes[attach]["x"], B.nodes[attach]["y"]
        ang = math.pi * (0.08 + 0.84 * (bi / (N_BRANCHES - 1)))
        if bi <= 4:
            lean = "str"
        elif bi >= 11:
            lean = "faith"
        else:
            lean = "agi" if bi in (7, 8) else CYCLE[bi % 3]
        segs = 5
        length = 560 + (bi % 4) * 45
        prev = attach
        for s in range(1, segs + 1):
            tt = s / segs
            x = ax + math.cos(ang) * length * tt * 1.2
            y = ay - math.sin(ang) * length * tt * 1.05
            x *= (1.0 + 0.3 * tt)
            reg = CYCLE[(bi + s) % 3] if tt < 0.35 else lean
            nid = f"br{bi}_{s}"
            B.add(nid, NAMES[reg if reg in NAMES else "mix"][min(tier_of_y(y), 4)], "small",
                  x, y, reg,
                  scale_stats(dict(RNG.choice(TIER_STATS[reg if reg in TIER_STATS else "mix"])),
                              tier_of_y(y)),
                  "Гілка." if tt >= 0.35 else "Сплетення гілки.")
            B.link(prev, nid)
            prev = nid
        branch_tips.append(prev)

    # ========== CANOPY FRUITS on big dome ==========
    fruit_meta = []
    fruit_ids = []
    for fi, (name, stats, theme, lean, frac) in enumerate(FRUITS):
        ring = 0.62 + 0.38 * ((fi % 3) / 2.0)
        fx, fy = canopy_pos(frac, ring)
        fid = f"fruit{fi}"
        B.add(fid, name, "notable", fx, fy, lean, dict(stats), f"Плід крони («{theme}»).")
        fruit_meta.append({"id": fid, "theme": theme, "name": name, "region": lean})
        fruit_ids.append(fid)
        near = min(branch_tips, key=lambda tip: (B.nodes[tip]["x"] - fx) ** 2 + (B.nodes[tip]["y"] - fy) ** 2)
        B.link(near, fid)
        for j in range(5):
            a = (j / 5) * math.tau + 0.12
            sx = fx + math.cos(a) * 105
            sy = fy + math.sin(a) * 82
            sid = f"{fid}_s{j}"
            B.add(sid, NAMES[lean][4], "small", sx, sy, lean,
                  scale_stats(dict(RNG.choice(TIER_STATS[lean])), 4),
                  f"Навколо плоду «{theme}».")
            B.link(fid, sid)

    for i, fid in enumerate(fruit_ids):
        a = B.nodes[fid]
        cands = []
        for j, oid in enumerate(fruit_ids):
            if i == j:
                continue
            b = B.nodes[oid]
            d = math.hypot(a["x"] - b["x"], a["y"] - b["y"])
            if d < 480:
                cands.append((d, oid))
        cands.sort()
        for _, oid in cands[:3]:
            B.link(fid, oid)

    for kid, reg, name, stats, frac in KEYSTONES:
        kx, ky = canopy_pos(frac, 0.42)
        ky -= 70
        store = reg if reg != "mix" else CYCLE[abs(hash(kid)) % 3]
        B.add(kid, name, "keystone", kx, ky, store, dict(stats), "Ключовий вузол крони.")
        near = min(fruit_ids, key=lambda fid: (B.nodes[fid]["x"] - kx) ** 2 + (B.nodes[fid]["y"] - ky) ** 2)
        B.link(near, kid)

    B.add("core", "Серце роду", "core", 0, Y_CROWN + 50, "agi",
          {"str": 5, "agi": 5, "faith": 5, "dmg_pct": 8, "hp_pct": 8, "res_all_pct": 5},
          "Вершина Древа роду.", force=True)
    for kid, *_ in KEYSTONES[:4]:
        if kid in B.nodes:
            B.link(kid, "core")
    for fid in sorted(fruit_ids, key=lambda fid: B.nodes[fid]["y"])[:5]:
        B.link(fid, "core")

    # Dense canopy fill (big round crown)
    fill = 0
    target = 320
    while len(B.nodes) < target and fill < 1100:
        fill += 1
        frac = RNG.random()
        scale = RNG.uniform(0.28, 1.08)
        x, y = canopy_pos(frac, scale)
        if y > Y_TRUNK_TOP + 20:
            continue
        too_close = any((n["x"] - x) ** 2 + (n["y"] - y) ** 2 < MIN_DIST ** 2 for n in B.nodes.values())
        if too_close:
            continue
        if x < -420:
            lean = "str"
        elif x > 420:
            lean = "faith"
        elif abs(x) < 180:
            lean = CYCLE[fill % 3]
        else:
            lean = "agi"
        nid = f"can_{fill}"
        B.add(nid, NAMES[lean][4], "small", x, y, lean,
              scale_stats(dict(RNG.choice(TIER_STATS[lean])), 4), "Крона.")
        near = min(B.nodes.values(),
                   key=lambda n: (n["x"] - x) ** 2 + (n["y"] - y) ** 2 if n["id"] != nid else 1e18)
        if near["id"] != nid:
            B.link(near["id"], nid)

    # Dense root fill for lush flare
    fill_r = 0
    while len(B.nodes) < 400 and fill_r < 160:
        fill_r += 1
        x = RNG.uniform(-1300, 1300)
        y = RNG.uniform(Y_TRUNK_BASE + 60, Y_ROOT_TIP - 30)
        if abs(x) < 140 and y < Y_ROOT_BAND + 100:
            continue
        too_close = any((n["x"] - x) ** 2 + (n["y"] - y) ** 2 < MIN_DIST ** 2 for n in B.nodes.values())
        if too_close:
            continue
        if x < -320:
            lean = "str"
        elif x > 320:
            lean = "faith"
        else:
            lean = CYCLE[fill_r % 3]
        nid = f"rootfill_{fill_r}"
        B.add(nid, NAMES[lean][0], "small", x, y, lean,
              scale_stats(dict(RNG.choice(TIER_STATS[lean])), 0), "Коріння.")
        near = min(B.nodes.values(),
                   key=lambda n: (n["x"] - x) ** 2 + (n["y"] - y) ** 2 if n["id"] != nid else 1e18)
        if near["id"] != nid:
            B.link(near["id"], nid)

    # Connectivity from starts
    def reachable(starts):
        adj = defaultdict(list)
        for a, b in B.links:
            adj[a].append(b)
            adj[b].append(a)
        seen = set(starts)
        q = deque(starts)
        while q:
            u = q.popleft()
            for v in adj[u]:
                if v not in seen:
                    seen.add(v)
                    q.append(v)
        return seen

    reach = reachable(list(START_IDS.values()))
    for oid in list(set(B.nodes) - reach):
        near = min((B.nodes[i] for i in reach),
                   key=lambda n: (n["x"] - B.nodes[oid]["x"]) ** 2 + (n["y"] - B.nodes[oid]["y"]) ** 2)
        B.link(near["id"], oid)
        reach.add(oid)

    B.harden_edges()
    # Cap node count for smoke test (≤600) by collapsing intermediate chain nodes
    def collapse_to(limit):
        adj = defaultdict(list)
        for a, b in B.links:
            adj[a].append(b)
            adj[b].append(a)
        cands = [nid for nid in list(B.nodes)
                 if nid.startswith(("fill_", "seg_", "can_", "rootfill_"))
                 and B.nodes[nid]["type"] == "small"
                 and len(adj[nid]) == 2]
        # collapse from canopy/root fills first, then segs farthest from x=0
        cands.sort(key=lambda nid: (0 if nid.startswith(("can_", "rootfill_")) else 1,
                                    -abs(B.nodes[nid]["x"])))
        for nid in cands:
            if len(B.nodes) <= limit:
                break
            nbs = [x for x in adj[nid] if x in B.nodes]
            if len(nbs) != 2:
                continue
            a, b = nbs
            # skip if collapsing would make a very long edge
            da = B.nodes[a]; db = B.nodes[b]
            if math.hypot(da["x"] - db["x"], da["y"] - db["y"]) > MAX_EDGE * 1.15:
                continue
            del B.nodes[nid]
            # rebuild adj lightly
            adj[a] = [x for x in adj[a] if x != nid]
            adj[b] = [x for x in adj[b] if x != nid]
            if b not in adj[a]:
                adj[a].append(b)
                adj[b].append(a)
        # rewrite links from adj
        seen = set()
        new_links = []
        for a, nbs in adj.items():
            if a not in B.nodes:
                continue
            for b in nbs:
                if b not in B.nodes:
                    continue
                key = tuple(sorted((a, b)))
                if key in seen:
                    continue
                seen.add(key)
                new_links.append([a, b])
        B.links = new_links
        B.seen = seen

    collapse_to(580)
    if len(B.nodes) > 580:
        collapse_to(560)
    B.harden_edges()
    # final safety collapse if harden re-inflated
    if len(B.nodes) > 650:
        collapse_to(620)
    if len(B.nodes) > 650:
        collapse_to(600)
    B.harden_edges()
    # Leaf-only prune (never cut chains) + reconnect orphans
    if len(B.nodes) > 780:
        adj = defaultdict(list)
        for a, b in B.links:
            adj[a].append(b)
            adj[b].append(a)
        protect = set(START_IDS.values()) | {"trunk0", "core"}
        protect |= {n["id"] for n in B.nodes.values() if n["type"] in ("notable", "keystone", "start", "core")}
        protect |= {nid for nid in B.nodes if nid.startswith(("trunk_", "br", "fruit", "ks_", "s_conv", "a_conv", "f_conv", "s_root", "a_root", "f_root"))}
        cands = [nid for nid, n in B.nodes.items()
                 if nid not in protect and n["type"] == "small"
                 and nid.startswith(("can_", "rootfill_"))]
        cands.sort(key=lambda nid: len(adj[nid]))
        for nid in cands:
            if len(B.nodes) <= 750:
                break
            if len(adj.get(nid, [])) != 1:
                continue
            for nb in list(adj.get(nid, [])):
                adj[nb] = [x for x in adj[nb] if x != nid]
            del B.nodes[nid]
            adj.pop(nid, None)
        seen = set()
        nl = []
        for a, nbs in adj.items():
            if a not in B.nodes:
                continue
            for b in nbs:
                if b not in B.nodes:
                    continue
                k = tuple(sorted((a, b)))
                if k in seen:
                    continue
                seen.add(k)
                nl.append([a, b])
        B.links = nl
        B.seen = seen

    # Reconnect anything severed
    def reachable(starts):
        adj = defaultdict(list)
        for a, b in B.links:
            adj[a].append(b)
            adj[b].append(a)
        seen = set(starts)
        q = deque(starts)
        while q:
            u = q.popleft()
            for v in adj[u]:
                if v not in seen:
                    seen.add(v)
                    q.append(v)
        return seen
    reach = reachable(list(START_IDS.values()))
    for oid in list(set(B.nodes) - reach):
        near = min((B.nodes[i] for i in reach),
                   key=lambda n: (n["x"] - B.nodes[oid]["x"]) ** 2 + (n["y"] - B.nodes[oid]["y"]) ** 2)
        B.link(near["id"], oid)
        reach.add(oid)
    B.harden_edges()

    node_list = list(B.nodes.values())
    types = {}
    for n in node_list:
        types[n["type"]] = types.get(n["type"], 0) + 1
    lens = []
    for a, b in B.links:
        na, nb = B.nodes[a], B.nodes[b]
        lens.append(math.hypot(na["x"] - nb["x"], na["y"] - nb["y"]))

    data = {
        "format": "spohady-perk-tree",
        "version": 4,
        "title": "Древо звитяги",
        "comment": "v4: широке коріння → один сплетений стовбур → кругла крона (Yggdrasil).",
        "regions": REGIONS,
        "class_starts": CLASS_STARTS,
        "nodes": node_list,
        "links": B.links,
    }
    layout = {
        "y_root": Y_ROOT_BAND, "y_crown": Y_CROWN, "y_trunk_top": Y_TRUNK_TOP,
        "y_trunk_base": Y_TRUNK_BASE,
        "bands": [
            {"id": "roots", "name": "Коріння", "y0": Y_TRUNK_BASE, "y1": Y_ROOT_TIP},
            {"id": "trunk", "name": "Стовбур", "y0": Y_TRUNK_TOP, "y1": Y_TRUNK_BASE},
            {"id": "crown", "name": "Крона", "y0": Y_CROWN - 80, "y1": Y_TRUNK_TOP},
        ],
        "trunk_spine": trunk_spine,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    META.write_text(json.dumps({"fruits": fruit_meta, "layout": layout}, ensure_ascii=False, indent=2) + "\n")
    print("nodes", len(node_list), "links", len(B.links), "types", types)
    print("edge max", round(max(lens), 1), "mean", round(sum(lens) / len(lens), 1),
          "over_max", sum(1 for L in lens if L > MAX_EDGE + 1))
    print("y", min(n["y"] for n in node_list), max(n["y"] for n in node_list))
    # silhouette stats
    for y0, y1, name in [(Y_CROWN, Y_TRUNK_TOP, "crown"), (Y_TRUNK_TOP, Y_TRUNK_BASE, "trunk"),
                         (Y_TRUNK_BASE, Y_ROOT_TIP, "roots")]:
        xs = [n["x"] for n in node_list if y0 <= n["y"] < y1]
        if xs:
            print(f"  {name}: n={len(xs)} |x|mean={sum(abs(x) for x in xs)/len(xs):.0f} xmax={max(abs(x) for x in xs):.0f}")


if __name__ == "__main__":
    main()
