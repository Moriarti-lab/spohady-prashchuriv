#!/usr/bin/env python3
"""v4 tree — deterministic Yggdrasil silhouette.
Wide root fan → clean tapering braided trunk → even rounded canopy dome.
Shape/readability over node count (~700–950).
"""
from __future__ import annotations
import json, math, random
from pathlib import Path
from collections import deque, defaultdict

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "perk_tree.json"
META = ROOT / "data" / "perk_tree_meta.json"
RNG = random.Random(40540)  # only for stats flavour, not layout

# --- Geometry (Y↑ crown = smaller y; roots = larger y) ---
Y_CROWN = -2000
Y_TRUNK_TOP = -200
Y_TRUNK_BASE = 500
Y_ROOT_TIP = 2100

CANOPY_RX = 1280.0          # half-width of dome
CANOPY_RY = 980.0
CANOPY_CY = (Y_CROWN + Y_TRUNK_TOP) * 0.40

# Trunk width ≈ 16–18% of canopy diameter (2*CANOPY_RX)
TRUNK_RAD_BASE = 210.0      # ~16% of 2560
TRUNK_RAD_TOP = 105.0
TRUNK_STRANDS = 5
TRUNK_STEPS = 14

MIN_DIST = 70.0
MAX_EDGE = 150.0

REGIONS = [
    {"id": "str", "name": "Сила", "color": "#D8574B"},
    {"id": "agi", "name": "Спритність", "color": "#7CBF5A"},
    {"id": "faith", "name": "Віра", "color": "#E0A526"},
]
CLASS_STARTS = {"druzhynnyk": "s_root", "strilets": "a_root", "volkhv": "f_root"}
START_IDS = {"str": "s_root", "agi": "a_root", "faith": "f_root"}
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


def lean_of_x(x: float) -> str:
    if x < -CANOPY_RX * 0.28:
        return "str"
    if x > CANOPY_RX * 0.28:
        return "faith"
    return "agi"


def canopy_point(frac: float, radius_scale: float = 1.0):
    """frac 0..1 left→right across upper semicircle of the dome."""
    ang = math.pi * (0.08 + 0.84 * frac)
    x = math.cos(ang) * CANOPY_RX * radius_scale
    y = CANOPY_CY - math.sin(ang) * CANOPY_RY * radius_scale
    y = max(Y_CROWN + 50, min(Y_TRUNK_TOP - 20, y))
    return x, y


def in_canopy(x: float, y: float) -> bool:
    if y > Y_TRUNK_TOP + 40 or y < Y_CROWN - 40:
        return False
    nx = x / CANOPY_RX
    ny = (CANOPY_CY - y) / CANOPY_RY
    return nx * nx + ny * ny <= 1.05 and ny >= -0.05


class Builder:
    def __init__(self):
        self.nodes = {}
        self.links = []
        self.seen = set()
        self.seq = 0

    def _xy(self, x, y):
        x = 0.0 if abs(x) < 0.05 else round(x, 1)
        y = 0.0 if abs(y) < 0.05 else round(y, 1)
        return x, y

    def add(self, nid, name, typ, x, y, region, stats, desc="", force=False):
        if not force:
            x, y = self._place(x, y)
        x, y = self._xy(x, y)
        self.nodes[nid] = {
            "id": nid, "name": name, "description": desc or "Вузол Древа звитяги.",
            "x": x, "y": y,
            "type": typ, "stats": stats, "skill": "", "icon": "", "region": region,
        }
        return self.nodes[nid]

    def _place(self, x, y, tries=36):
        for _ in range(tries):
            if all((n["x"] - x) ** 2 + (n["y"] - y) ** 2 >= MIN_DIST ** 2 for n in self.nodes.values()):
                return x, y
            x += RNG.uniform(-MIN_DIST * 0.35, MIN_DIST * 0.35)
            y += RNG.uniform(-MIN_DIST * 0.3, MIN_DIST * 0.3)
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
            self.seq += 1
            mid = f"seg_{self.seq}"
            if reg_a != reg_b:
                reg = CYCLE[self.seq % 3]
                pool = TIER_STATS["mix"]
                nk = "mix"
            else:
                reg = reg_a if t < 0.5 else reg_b
                pool = TIER_STATS.get(reg, TIER_STATS["mix"])
                nk = reg if reg in NAMES else "mix"
            tier = tier_of_y(y)
            self.add(mid, NAMES[nk][min(tier, 4)], "small", x, y, reg,
                     scale_stats(dict(RNG.choice(pool)), tier),
                     "Сплетення шляхів." if reg_a != reg_b else "Гілка.")
            self.links.append([prev, mid])
            self.seen.add(tuple(sorted((prev, mid))))
            prev = mid
        self.links.append([prev, b])
        self.seen.add(tuple(sorted((prev, b))))

    def harden_edges(self):
        changed, guard = True, 0
        while changed and guard < 8:
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
                if dist <= MAX_EDGE:
                    key = tuple(sorted((a, b)))
                    if key not in self.seen:
                        self.seen.add(key)
                        self.links.append([a, b])
                    continue
                changed = True
                steps = max(2, int(math.ceil(dist / MAX_EDGE)))
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
                    x, y = self._xy(x, y)
                    self.nodes[mid] = {
                        "id": mid, "name": NAMES.get(reg, NAMES["mix"])[min(tier, 4)],
                        "description": "Гілка.", "x": x, "y": y,
                        "type": "small", "stats": scale_stats(dict(RNG.choice(TIER_STATS.get(reg, TIER_STATS["mix"]))), tier),
                        "skill": "", "icon": "", "region": reg,
                    }
                    key = tuple(sorted((prev, mid)))
                    self.seen.add(key)
                    self.links.append([prev, mid])
                    prev = mid
                key = tuple(sorted((prev, b)))
                self.seen.add(key)
                self.links.append([prev, b])


def main():
    B = Builder()
    root_names = {"str": "Сила", "agi": "Спритність", "faith": "Віра"}

    # ========== CLEAN TAPERING TRUNK ==========
    # 5 longitudinal strands, gentle weave, regular rungs. No knots.
    strand_keys = ["s", "m1", "c", "m2", "f"]
    strand_regs = ["str", "agi", "agi", "faith", "faith"]
    strand_lanes = [-1.0, -0.5, 0.0, 0.5, 1.0]
    strand_prev = {}
    trunk_spine = []
    trunk_by_step = []

    for i in range(TRUNK_STEPS + 1):
        t = i / TRUNK_STEPS
        y = Y_TRUNK_BASE + (Y_TRUNK_TOP - Y_TRUNK_BASE) * t
        rad = TRUNK_RAD_BASE + (TRUNK_RAD_TOP - TRUNK_RAD_BASE) * t
        # slight flare into canopy in last 15%
        if t > 0.85:
            rad += 28 * ((t - 0.85) / 0.15)
        phase = t * math.pi * 1.8  # gentle wind, not tight braid knots
        step_ids = []
        for si, (key, reg, lane) in enumerate(zip(strand_keys, strand_regs, strand_lanes)):
            weave = math.sin(phase + si * 0.7) * 14.0
            x = lane * rad + weave
            if i == 0:
                nid = "trunk0" if key == "c" else f"trunk_{key}0"
            else:
                nid = f"trunk_{key}{i}"
            name = "Сплетення коріння" if nid == "trunk0" else NAMES["mix"][min(tier_of_y(y), 4)]
            typ = "keystone" if nid == "trunk0" else "small"
            desc = "Три шляхи сходяться в один стовбур." if nid == "trunk0" else "Стовбур роду — сплетення шляхів."
            B.add(nid, name, typ, x, y, reg,
                  scale_stats(dict(RNG.choice(TIER_STATS["mix"])), tier_of_y(y)),
                  desc, force=True)
            if key in strand_prev:
                B.link(strand_prev[key], nid)
            strand_prev[key] = nid
            step_ids.append(nid)
        # regular rungs between neighbours
        for a, b in zip(step_ids, step_ids[1:]):
            B.link(a, b)
        # occasional skip-one rung for lattice strength (every other step)
        if i % 2 == 0 and len(step_ids) >= 5:
            B.link(step_ids[0], step_ids[2])
            B.link(step_ids[2], step_ids[4])
        trunk_by_step.append(step_ids)
        trunk_spine.append(step_ids[2])

    # connect non-center base strands to trunk0 as well
    for key in strand_keys:
        if key == "c":
            continue
        B.link("trunk0", f"trunk_{key}0")

    # ========== BROAD ROOT FAN (single system, starts integrated) ==========
    # Radial roots from trunk base downward across a wide fan.
    N_ROOTS = 13
    root_chains = []  # list of lists of node ids per ray
    for ri in range(N_ROOTS):
        # angles: downward fan, π*0.12 .. π*0.88 (screen +y down)
        ang = math.pi * (0.12 + 0.76 * (ri / (N_ROOTS - 1)))
        # lean by side
        # ang~0 → +x (праворуч) = faith; ang~π → −x (ліворуч) = str
        if ri >= 9:
            lean = "str"
        elif ri <= 3:
            lean = "faith"
        else:
            lean = "agi" if ri in (5, 6, 7) else CYCLE[ri % 3]
        segs = 6
        # outer rays longer
        length = 980 + abs(ri - (N_ROOTS - 1) / 2) * 40
        chain = ["trunk0"]
        prev = "trunk0"
        for s in range(1, segs + 1):
            tt = s / segs
            # ease-out for wider tips
            ease = tt * (0.85 + 0.35 * tt)
            x = math.cos(ang) * length * ease
            y = Y_TRUNK_BASE + math.sin(ang) * length * ease
            y = min(y, Y_ROOT_TIP - 30)
            # slight curve
            x += math.sin(tt * math.pi) * 40 * math.cos(ang + math.pi / 2)
            nid = f"root_{ri}_{s}"
            # mixing near trunk
            reg = CYCLE[(ri + s) % 3] if tt < 0.25 else lean
            B.add(nid, NAMES[reg if reg in NAMES else "mix"][min(tier_of_y(y), 1)], "small",
                  x, y, reg,
                  scale_stats(dict(RNG.choice(TIER_STATS[reg if reg in TIER_STATS else "mix"])),
                              tier_of_y(y)),
                  "Корінь." if tt >= 0.25 else "Сплетення коріння.", force=(s == 1))
            B.link(prev, nid)
            prev = nid
            chain.append(nid)
            # fork at mid depth for lushness
            if s in (3, 5):
                side = 1 if ri % 2 == 0 else -1
                fx = x + side * 95 * math.cos(ang + math.pi / 2)
                fy = y + 70
                fid = f"root_{ri}_{s}f"
                B.add(fid, NAMES[lean][0], "small", fx, fy, lean,
                      scale_stats(dict(RNG.choice(TIER_STATS[lean])), 0), "Бічний корінь.")
                B.link(nid, fid)
                chain.append(fid)
        root_chains.append(chain)

    # Lateral cross-links between adjacent rays at same depth index
    for ri in range(N_ROOTS - 1):
        a_chain = [n for n in root_chains[ri] if n.startswith("root_")]
        b_chain = [n for n in root_chains[ri + 1] if n.startswith("root_")]
        # pair by sorted y (depth)
        a_sorted = sorted(a_chain, key=lambda n: B.nodes[n]["y"])
        b_sorted = sorted(b_chain, key=lambda n: B.nodes[n]["y"])
        for ai, bi in zip(a_sorted[1::2], b_sorted[1::2]):
            B.link(ai, bi)

    # Place class starts ON the fan at prominent positions (integrated, not blobs)
    # left / center / right mid-depth
    start_rays = {0: "str", 6: "agi", 12: "faith"}  # ray indices
    # actually use rays 1, 6, 11 for better spread
    start_place = [("str", 11, 3), ("agi", 6, 3), ("faith", 1, 3)]
    for reg, ray, seg in start_place:
        host = f"root_{ray}_{seg}"
        if host not in B.nodes:
            host = root_chains[ray][min(seg, len(root_chains[ray]) - 1)]
        hx, hy = B.nodes[host]["x"], B.nodes[host]["y"]
        # offset slightly outward so start is prominent
        ox = -80 if reg == "str" else (80 if reg == "faith" else 0)
        B.add(START_IDS[reg], f"Корінь · {root_names[reg]}",
              "start", hx + ox, hy + 40, reg, {reg: 5},
              "Початок шляху класу.", force=True)
        B.link(host, START_IDS[reg])
        # small halo of 3 smalls around start (not a dense blob)
        for j in range(3):
            a = (j / 3) * math.tau + 0.4
            sx = hx + ox + math.cos(a) * 90
            sy = hy + 40 + math.sin(a) * 70
            sid = f"{reg[0]}_halo{j}"
            B.add(sid, NAMES[reg][0], "small", sx, sy, reg,
                  scale_stats(dict(RNG.choice(TIER_STATS[reg])), 0), "Корінець.")
            B.link(START_IDS[reg], sid)

    # Soft start bridges
    B.link("s_root", "a_root")
    B.link("a_root", "f_root")

    # ========== CANOPY: primary branches into even dome ==========
    N_BRANCHES = 14
    branch_tips = []
    for bi in range(N_BRANCHES):
        # attach along upper half of trunk
        attach_i = max(TRUNK_STEPS // 2, int((0.55 + 0.4 * bi / (N_BRANCHES - 1)) * TRUNK_STEPS))
        attach_i = min(attach_i, TRUNK_STEPS)
        attach = trunk_by_step[attach_i][bi % TRUNK_STRANDS]
        ax, ay = B.nodes[attach]["x"], B.nodes[attach]["y"]
        # target point on canopy ellipse
        frac = bi / (N_BRANCHES - 1)
        tx, ty = canopy_point(frac, 0.92)
        lean = lean_of_x(tx)
        segs = 5
        prev = attach
        for s in range(1, segs + 1):
            tt = s / segs
            x = ax + (tx - ax) * tt
            y = ay + (ty - ay) * tt
            # slight arc outward
            x += math.sin(tt * math.pi) * 30 * (1 if frac < 0.5 else -1) * (0.5 - abs(frac - 0.5))
            reg = CYCLE[(bi + s) % 3] if tt < 0.3 else lean
            nid = f"br{bi}_{s}"
            B.add(nid, NAMES[reg if reg in NAMES else "mix"][min(tier_of_y(y), 4)], "small",
                  x, y, reg,
                  scale_stats(dict(RNG.choice(TIER_STATS[reg if reg in TIER_STATS else "mix"])),
                              tier_of_y(y)),
                  "Гілка." if tt >= 0.3 else "Сплетення гілки.")
            B.link(prev, nid)
            prev = nid
        branch_tips.append(prev)
        # sub-branch fork near tip
        if bi % 2 == 0:
            side = 1 if frac < 0.5 else -1
            sx = B.nodes[prev]["x"] + side * 110
            sy = B.nodes[prev]["y"] - 80
            if in_canopy(sx, sy):
                sid = f"br{bi}_sub"
                B.add(sid, NAMES[lean][4], "small", sx, sy, lean,
                      scale_stats(dict(RNG.choice(TIER_STATS[lean])), 4), "Пагін.")
                B.link(prev, sid)
                branch_tips.append(sid)

    # Interconnect neighbouring primary branch tips
    for i in range(len(branch_tips) - 1):
        B.link(branch_tips[i], branch_tips[i + 1])

    # ========== FRUITS evenly on dome ==========
    fruit_meta = []
    fruit_ids = []
    for fi, (name, stats, theme, lean, frac) in enumerate(FRUITS):
        ring = 0.58 + 0.36 * ((fi % 3) / 2.0)
        # redistribute frac evenly across 15 slots for no clustering
        even_frac = (fi + 0.5) / len(FRUITS)
        fx, fy = canopy_point(even_frac, ring)
        fid = f"fruit{fi}"
        B.add(fid, name, "notable", fx, fy, lean, dict(stats),
              f"Плід крони («{theme}»).", force=True)
        fruit_meta.append({"id": fid, "theme": theme, "name": name, "region": lean})
        fruit_ids.append(fid)
        near = min(branch_tips, key=lambda tip: (B.nodes[tip]["x"] - fx) ** 2 + (B.nodes[tip]["y"] - fy) ** 2)
        B.link(near, fid)
        for j in range(4):
            a = (j / 4) * math.tau + even_frac
            sx = fx + math.cos(a) * 95
            sy = fy + math.sin(a) * 72
            sid = f"{fid}_s{j}"
            B.add(sid, NAMES[lean][4], "small", sx, sy, lean,
                  scale_stats(dict(RNG.choice(TIER_STATS[lean])), 4),
                  f"Навколо плоду «{theme}».")
            B.link(fid, sid)

    # bridges between angularly neighbouring fruits
    for i in range(len(fruit_ids)):
        B.link(fruit_ids[i], fruit_ids[(i + 1) % len(fruit_ids)])
        if i + 2 < len(fruit_ids):
            d = math.hypot(B.nodes[fruit_ids[i]]["x"] - B.nodes[fruit_ids[i + 2]]["x"],
                           B.nodes[fruit_ids[i]]["y"] - B.nodes[fruit_ids[i + 2]]["y"])
            if d < 520:
                B.link(fruit_ids[i], fruit_ids[i + 2])

    # Keystones inner ring
    for kid, reg, name, stats, frac in KEYSTONES:
        even = frac
        kx, ky = canopy_point(even, 0.40)
        ky -= 40
        store = reg if reg != "mix" else CYCLE[abs(hash(kid)) % 3]
        B.add(kid, name, "keystone", kx, ky, store, dict(stats),
              "Ключовий вузол крони.", force=True)
        near = min(fruit_ids, key=lambda fid: (B.nodes[fid]["x"] - kx) ** 2 + (B.nodes[fid]["y"] - ky) ** 2)
        B.link(near, kid)

    # Core at apex
    B.add("core", "Серце роду", "core", 0, Y_CROWN + 60, "agi",
          {"str": 5, "agi": 5, "faith": 5, "dmg_pct": 8, "hp_pct": 8, "res_all_pct": 5},
          "Вершина Древа роду.", force=True)
    for kid, *_ in KEYSTONES[:4]:
        if kid in B.nodes:
            B.link(kid, "core")
    for fid in sorted(fruit_ids, key=lambda f: B.nodes[f]["y"])[:4]:
        B.link(fid, "core")

    # ========== EVEN CANOPY FILL (deterministic polar grid) ==========
    # rings × angles — only keep points inside dome with min spacing
    fill_ids = []
    for ring_i, rscale in enumerate([0.25, 0.42, 0.58, 0.72, 0.86, 0.98]):
        n_ang = 8 + ring_i * 3
        for ai in range(n_ang):
            frac = (ai + 0.5) / n_ang
            x, y = canopy_point(frac, rscale)
            if not in_canopy(x, y):
                continue
            if any((n["x"] - x) ** 2 + (n["y"] - y) ** 2 < MIN_DIST ** 2 for n in B.nodes.values()):
                continue
            lean = lean_of_x(x)
            # mix near center
            if abs(x) < 160:
                lean = CYCLE[(ring_i + ai) % 3]
            nid = f"can_{ring_i}_{ai}"
            B.add(nid, NAMES[lean][4], "small", x, y, lean,
                  scale_stats(dict(RNG.choice(TIER_STATS[lean])), 4), "Крона.", force=True)
            fill_ids.append(nid)
            near = min(B.nodes.values(),
                       key=lambda n: (n["x"] - x) ** 2 + (n["y"] - y) ** 2 if n["id"] != nid else 1e18)
            if near["id"] != nid:
                B.link(near["id"], nid)

    # Link fill neighbours within short range for web (no holes)
    for i, a in enumerate(fill_ids):
        na = B.nodes[a]
        cands = []
        for b in fill_ids[i + 1:]:
            nb = B.nodes[b]
            d = math.hypot(na["x"] - nb["x"], na["y"] - nb["y"])
            if MIN_DIST < d < 200:
                cands.append((d, b))
        cands.sort()
        for _, b in cands[:2]:
            B.link(a, b)

    # Light root fill on a polar fan grid (not random blobs)
    for ring_i, rscale in enumerate([0.35, 0.55, 0.75, 0.92]):
        n_ang = 10 + ring_i * 2
        for ai in range(n_ang):
            ang = math.pi * (0.12 + 0.76 * ((ai + 0.5) / n_ang))
            length = 1000 * rscale
            x = math.cos(ang) * length
            y = Y_TRUNK_BASE + math.sin(ang) * length
            if y > Y_ROOT_TIP - 40 or y < Y_TRUNK_BASE + 80:
                continue
            if abs(x) < TRUNK_RAD_BASE * 0.6 and y < Y_TRUNK_BASE + 200:
                continue
            if any((n["x"] - x) ** 2 + (n["y"] - y) ** 2 < MIN_DIST ** 2 for n in B.nodes.values()):
                continue
            lean = lean_of_x(x)
            nid = f"rfill_{ring_i}_{ai}"
            B.add(nid, NAMES[lean][0], "small", x, y, lean,
                  scale_stats(dict(RNG.choice(TIER_STATS[lean])), 0), "Коріння.", force=True)
            near = min(B.nodes.values(),
                       key=lambda n: (n["x"] - x) ** 2 + (n["y"] - y) ** 2 if n["id"] != nid else 1e18)
            if near["id"] != nid:
                B.link(near["id"], nid)

    # Connectivity repair
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

    # Cap gently with leaf-only prune if over 950
    if len(B.nodes) > 950:
        adj = defaultdict(list)
        for a, b in B.links:
            adj[a].append(b)
            adj[b].append(a)
        protect = set(START_IDS.values()) | {"trunk0", "core"}
        protect |= {n["id"] for n in B.nodes.values() if n["type"] != "small"}
        protect |= {nid for nid in B.nodes if nid.startswith(("trunk_", "br", "fruit", "ks_", "root_"))}
        cands = [nid for nid in B.nodes if nid not in protect and nid.startswith(("can_", "rfill_", "fill_", "seg_"))]
        cands.sort(key=lambda nid: len(adj[nid]))
        for nid in cands:
            if len(B.nodes) <= 920:
                break
            if len(adj.get(nid, [])) != 1:
                continue
            for nb in list(adj.get(nid, [])):
                adj[nb] = [x for x in adj[nb] if x != nid]
            del B.nodes[nid]
            adj.pop(nid, None)
        seen, nl = set(), []
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
        B.links, B.seen = nl, seen
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
    lens = [math.hypot(B.nodes[a]["x"] - B.nodes[b]["x"], B.nodes[a]["y"] - B.nodes[b]["y"])
            for a, b in B.links]

    data = {
        "format": "spohady-perk-tree",
        "version": 4,
        "title": "Древо звитяги",
        "comment": "v4: детермінована геометрія — широкий віяловий корінь, чистий сплетений стовбур, рівна куполна крона.",
        "regions": REGIONS,
        "class_starts": CLASS_STARTS,
        "nodes": node_list,
        "links": B.links,
    }
    layout = {
        "y_root": Y_TRUNK_BASE, "y_crown": Y_CROWN, "y_trunk_top": Y_TRUNK_TOP,
        "y_trunk_base": Y_TRUNK_BASE,
        "canopy_rx": CANOPY_RX, "canopy_ry": CANOPY_RY,
        "trunk_rad_base": TRUNK_RAD_BASE, "trunk_rad_top": TRUNK_RAD_TOP,
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
    for y0, y1, name in [(Y_CROWN, Y_TRUNK_TOP, "crown"), (Y_TRUNK_TOP, Y_TRUNK_BASE, "trunk"),
                         (Y_TRUNK_BASE, Y_ROOT_TIP, "roots")]:
        xs = [n["x"] for n in node_list if y0 <= n["y"] < y1]
        if xs:
            print(f"  {name}: n={len(xs)} |x|mean={sum(abs(x) for x in xs)/len(xs):.0f} xmax={max(abs(x) for x in xs):.0f}")


if __name__ == "__main__":
    main()
