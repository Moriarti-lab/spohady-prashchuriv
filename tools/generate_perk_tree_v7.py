#!/usr/bin/env python3
"""
Древо звитяги v7 — силует дерева (маска) + всередині павутина PoE.

Зовні: коріння знизу (3 старти), вужчий стовбур, широка кругла крона.
Всередині: колеса-кластери, з'єднані короткими стежками (Gabriel/MST + петлі).
Без прямих хребтів і драбин. Лише mechanics_wired статы. desc == stats.

  python3 tools/generate_perk_tree_v7.py --seed 424242 --out out/tree.json

Координати в JSON — формат v4, SCALE×10.
Вартість у грі: 1 перк = 1 вузол (старт безкоштовний).
"""
from __future__ import annotations

import argparse
import heapq
import json
import math
import os
import random
import sys
from collections import Counter, defaultdict, deque

SCALE = 10
MAX_DEG = 6
MIN_DIST = 18.0
STEP = 26.0  # target travel spacing (pre-scale)

REGIONS = [
    {"id": "str", "name": "Сила", "color": "#C62828"},
    {"id": "agi", "name": "Спритність", "color": "#2E7D32"},
    {"id": "faith", "name": "Віра", "color": "#F9A825"},
]
CLASS_STARTS = {"druzhynnyk": "s_root", "strilets": "a_root", "volkhv": "f_root"}
START_ID = {"str": "s_root", "agi": "a_root", "faith": "f_root"}
BR = ["str", "agi", "faith"]

WIRED = {
    "str", "agi", "faith", "hp", "hp_pct", "mana_pct", "mana_regen", "mana_regen_pct",
    "armor", "dmg_pct", "atk_speed_pct", "crit_pct", "crit_dmg_pct", "cdr_pct",
    "lifesteal_pct", "thorns_pct", "hp_regen_pct", "dr_pct", "move_pct", "dodge_pct",
    "block_pct", "block_power_pct", "aoe_pct", "effect_dur_pct", "skill_cost_pct",
    "nauz_xp_pct", "one_path", "free_skills", "block_no_shield",
}
NEEDS_WIRING = ["proj_speed_pct", "double_hit_pct", "armor_pen_pct", "pen_all_pct", "res_all_pct"]

THEMES = {
    "str": {
        "life": ["hp", "hp_pct", "lifesteal_pct"],
        "melee": ["dmg_pct", "atk_speed_pct", "str"],
        "armour": ["armor", "dr_pct", "block_pct", "thorns_pct", "block_power_pct"],
    },
    "agi": {
        "evasion": ["dodge_pct", "move_pct", "agi"],
        "ranged": ["dmg_pct", "atk_speed_pct", "agi"],
        "crit": ["crit_pct", "crit_dmg_pct", "atk_speed_pct"],
    },
    "faith": {
        "spell": ["dmg_pct", "aoe_pct", "faith"],
        "resource": ["mana_pct", "mana_regen", "cdr_pct", "skill_cost_pct"],
        "support": ["hp_regen_pct", "effect_dur_pct", "nauz_xp_pct", "faith"],
    },
}
TRAVEL = {
    "str": ["str", "hp", "armor"],
    "agi": ["agi", "move_pct", "hp"],
    "faith": ["faith", "mana_regen", "hp"],
}
STAT_NAMES = {
    "str": "Сила", "agi": "Спритність", "faith": "Віра", "dmg_pct": "шкоди", "hp_pct": "життя",
    "armor": "броні", "atk_speed_pct": "швидкості атаки", "hp": "життя", "lifesteal_pct": "лічі",
    "thorns_pct": "шипів", "block_pct": "блоку", "dr_pct": "захисту", "crit_pct": "крита",
    "dodge_pct": "ухилення", "move_pct": "руху", "crit_dmg_pct": "критичної шкоди",
    "cdr_pct": "відновлення", "mana_pct": "чару", "mana_regen": "відновлення чару",
    "mana_regen_pct": "відн. чару", "effect_dur_pct": "тривалості", "hp_regen_pct": "регенерації",
    "nauz_xp_pct": "росту наузів", "skill_cost_pct": "вартості", "aoe_pct": "площі",
    "block_power_pct": "сили блоку", "one_path": "один шлях", "free_skills": "вільні вміння",
    "block_no_shield": "блок без щита",
}
NS = {
    "str": [
        "Жила сили", "Криця роду", "Міць предка", "Кістка ведмедя", "Удар молота", "Щит стін",
        "Брусок гарту", "Кров воїна", "Плече дружини", "Корінь дуба", "Ланцюг клятви",
        "Лезо сокири", "Вага щита", "Рев полку", "Слід тура", "Загартований кулак",
        "Обруч сили", "Нитка сили", "Камінь опори", "Хват заліза", "Шлях ратника",
        "Знак вепра", "Тиск строю", "Клич бою", "Броня предків", "Стовбур сили",
        "Кіготь ведмедя", "Удар щитом", "Гудок рогу", "Плита гарту", "Ребро щита",
        "Крок велетня", "Залізний обруч", "Стяг полку", "Тиснява", "Кістяний щит",
        "Важкий крок", "Гартоване рамено", "Зуб вепра", "Клинок варти",
    ],
    "agi": [
        "Тінь кроку", "Гостре око", "Сагайдак вітру", "Слід рисі", "Тетіва ясена",
        "Шепіт листя", "Стрибок сарни", "Нитка влучності", "Подих швидкості", "Кіготь яструба",
        "Слід на воді", "Змах крила", "Точка прицілу", "Шлях ловця", "Легкий крок",
        "Кільце спритності", "Змах кинджала", "Свист стріли", "Тінь у траві", "Око сокола",
        "Пружність тятиви", "Знак вовка", "Хід по гілках", "Мить удару", "Плин річки",
        "Лист ясена", "Стрімкий крок", "Змах сагайдака", "Тінь гілки", "Нитка вітру",
        "Роса на тятиві", "Крок по моху", "Зір рисі", "Шип стріли", "Подих листя",
        "Тінь осоки", "Хижий змах", "Слід роси", "Нитка стежки", "Око вітру",
    ],
    "faith": [
        "Нитка долі", "Шепіт волхва", "Коло пращурів", "Іскра Сварога", "Дихання Вію",
        "Знак Перуна", "Чаша роси", "Світло капища", "Пісня Мокоші", "Корені роду",
        "Сліди ярила", "Крила віри", "Слово оберегу", "Прядка часу", "Дзвін дзвоника",
        "Світло рун", "Подих капища", "Струмок сили", "Око відуна", "Круг сонця",
        "Нитка Мокоші", "Знак Лади", "Тінь капища", "Жар вогнища", "Голос предків",
        "Крила Лади", "Руна шляху", "Свіча роду", "Пісня вітру", "Коло сонця",
        "Роса капища", "Тихе слово", "Знак Дажбога", "Нитка оберегу", "Світло роси",
        "Подих рун", "Коло вогнища", "Пісня роду", "Чаша сонця", "Слід волхва",
    ],
}
NN = {
    "str": {
        "life": ["Кривавий удар", "Серце вепра", "Жила роду", "Кров предків", "Дихання ведмедя"],
        "melee": ["Удар дружини", "Молот предків", "Гнів тура", "Криця серця", "Важкий замах"],
        "armour": ["Залізна шкіра", "Щит роду", "Стіна ратників", "Плита гарту", "Броня дуба"],
    },
    "agi": {
        "evasion": ["Тінь вовка", "Стрибок рисі", "Тінь лисиці", "Легкий крок", "Танок вітру"],
        "ranged": ["Град стріл", "Сагайдак бурі", "Стрімкий вітер", "Око бурі", "Тятива грози"],
        "crit": ["Влучне око", "Ясне око", "Зір яструба", "Мить удару", "Гострий зір"],
    },
    "faith": {
        "spell": ["Вогонь Сварога", "Жар капища", "Коло Мокоші", "Іскра Перуна", "Слово вогню"],
        "resource": ["Нитка долі", "Сила науза", "Чаша роси", "Вільні вміння", "Джерело чару"],
        "support": ["Оберіг", "Коло пращурів", "Дихання світу", "Світло капища", "Покров роду"],
    },
}
# C10: великий плюс + мінус. Опис завжди з stats (desc()).
NK = [
    ("Один шлях", "str", {"dmg_pct": 25, "one_path": 1}),
    ("Серце війни", "str", {"dmg_pct": 20, "armor": -12}),
    ("Кривава данина", "str", {"lifesteal_pct": 8, "hp_pct": -10}),
    ("Смертельна тінь", "agi", {"crit_dmg_pct": 30, "armor": -8}),
    ("Серце полювання", "agi", {"crit_pct": 12, "hp_pct": -10}),
    ("Гнів пращурів", "agi", {"aoe_pct": 20, "atk_speed_pct": -10}),
    ("Вільні вміння", "faith", {"cdr_pct": 25, "free_skills": 1, "mana_pct": -15}),
    ("Серце віри", "faith", {"dmg_pct": 20, "move_pct": -12}),
    ("Щит без щита", "str", {"block_no_shield": 1, "block_pct": 12, "move_pct": -8}),
]


def parse(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("--seed", type=int, required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--force", action="store_true")
    return p.parse_args(argv)


def refuse(path, force):
    n = os.path.normpath(os.path.abspath(path))
    if n.endswith(os.path.join("data", "perk_tree.json")) and not force:
        print("ВІДМОВА: data/perk_tree.json без --force", file=sys.stderr)
        sys.exit(2)


# ---------------------------------------------------------------------------
# Silhouette (y-up internally: roots at y≈0, crown at y≈H)
# ---------------------------------------------------------------------------

class Sil:
    """Union of root fans, tapered trunk, and a slightly irregular elliptic crown."""

    def __init__(self, seed: int):
        self.seed = seed
        self.phase = (seed % 997) / 997.0 * math.tau
        ph = self.phase
        # Crown: wide and relatively short (width / height ≈ 1.6–2.0)
        self.crx = 720 + 90 * math.sin(ph)                 # 630–810
        self.cry = 400 + 35 * math.cos(ph * 1.3)           # 365–435
        self.cx, self.cy = 0.0, 1320 + 50 * math.sin(ph * 0.7)
        # Trunk
        self.trunk_top = self.cy - self.cry * 0.92
        self.trunk_bot = 430 + 30 * math.sin(ph * 1.2)
        self.th_top = 150 + 18 * math.sin(ph * 1.1)
        self.th_bot = 168 + 18 * math.cos(ph * 0.9)
        # Roots
        self.root_y0 = 70 + 20 * math.cos(ph * 0.5)
        spread = 1.0 + 0.14 * math.sin(ph * 0.55)
        self.fans = [
            # (cx, cy, rx, ry, region) — compact skirt, not long side-arms
            (-290 * spread, 250, 270 * spread, 240, "str"),
            (0.0, 200, 230 * spread, 230, "agi"),
            (290 * spread, 250, 270 * spread, 240, "faith"),
        ]
        # Collar under trunk so fans connect
        self.collar_hw = 260 * spread
        self.collar_y0 = self.trunk_bot - 40
        self.collar_y1 = 340

    def crown_r(self, ang: float) -> float:
        a, b = self.crx, self.cry
        den = math.sqrt((b * math.cos(ang)) ** 2 + (a * math.sin(ang)) ** 2)
        r = (a * b / den) if den > 1e-9 else a
        r *= 1.0 + 0.09 * math.sin(3 * ang + self.phase) + 0.05 * math.sin(5 * ang + self.phase * 1.7)
        return r

    def in_crown(self, x, y, margin=1.0) -> bool:
        dx, dy = x - self.cx, y - self.cy
        ang = math.atan2(dy, dx)
        r = math.hypot(dx, dy)
        return r <= self.crown_r(ang) * margin

    def trunk_hw(self, y: float) -> float:
        if self.trunk_bot == self.trunk_top:
            return self.th_bot
        t = (y - self.trunk_top) / (self.trunk_bot - self.trunk_top)
        t = max(0.0, min(1.0, t))
        wave = 8 * math.sin(t * math.pi * 3 + self.phase)
        return (1 - t) * self.th_top + t * self.th_bot + wave

    def in_trunk(self, x, y, margin=1.0) -> bool:
        # y-up: trunk_bot is the lower end, trunk_top the upper end (larger y).
        if y > self.trunk_top + 30 or y < self.trunk_bot - 40:
            return False
        return abs(x) <= self.trunk_hw(y) * margin

    def in_roots(self, x, y, margin=1.0) -> bool:
        # collar: flare from trunk_bot down into the fans
        if self.trunk_bot + 50 >= y >= min(self.collar_y1, self.trunk_bot) - 80:
            t = (self.trunk_bot - y) / 160.0
            t = max(0.0, min(1.0, t))
            hw = self.th_bot + (self.collar_hw - self.th_bot) * t
            if abs(x) <= hw * margin:
                return True
        for cx, cy, rx, ry, _ in self.fans:
            if ((x - cx) / (rx * margin)) ** 2 + ((y - cy) / (ry * margin)) ** 2 <= 1.0:
                return True
        return False

    def inside(self, x, y, margin=1.0) -> bool:
        return self.in_crown(x, y, margin) or self.in_trunk(x, y, margin) or self.in_roots(x, y, margin)

    def zone(self, x, y) -> str:
        # prefer crown in the upper overlap, roots in the lower overlap
        if self.in_crown(x, y, 1.04) and y >= self.trunk_top - 50:
            return "crown"
        if self.in_roots(x, y, 1.04) and y <= self.trunk_bot + 50:
            return "roots"
        if self.in_trunk(x, y, 1.08):
            return "trunk"
        if self.in_crown(x, y, 1.06):
            return "crown"
        return "roots"

    def region(self, x, y) -> tuple[str, bool]:
        """Return (region, is_junction). Junctions are mixed corridors."""
        z = self.zone(x, y)
        if z == "roots":
            # nearest fan, junction if close to two fans
            d = []
            for cx, cy, rx, ry, rg in self.fans:
                e = math.hypot((x - cx) / rx, (y - cy) / ry)
                d.append((e, rg))
            d.sort()
            if d[1][0] < 1.05 and abs(d[0][0] - d[1][0]) < 0.28:
                return d[0][1], True
            return d[0][1], False
        if z == "crown":
            dy = y - self.cy
            if self.cry > 1 and abs(dy) < self.cry:
                hw = self.crx * math.sqrt(max(0.05, 1.0 - (dy / self.cry) ** 2))
            else:
                hw = max(80.0, abs(x) + 30)
            wave = 18 * math.sin(y / 200.0 + self.phase)
            b1 = -0.40 * hw + wave
            b2 = 0.40 * hw + wave * 0.6
            band = 0.08 * hw
            if x < b1 - band:
                return "str", False
            if x > b2 + band:
                return "faith", False
            if abs(x - b1) <= band:
                return "str", True
            if abs(x - b2) <= band:
                return "faith", True
            return "agi", False
        hw = self.trunk_hw(y)
        wave = 10 * math.sin(y / 90.0 + self.phase)
        b1 = -0.36 * hw + wave
        b2 = 0.36 * hw + wave * 0.6
        band = 0.10 * hw
        if x < b1 - band:
            return "str", False
        if x > b2 + band:
            return "faith", False
        if abs(x - b1) <= band:
            return "str", True
        if abs(x - b2) <= band:
            return "faith", True
        return "agi", False

    def bbox(self):
        xs = [self.crx + 20]
        for cx, _cy, rx, _ry, _ in self.fans:
            xs.append(abs(cx) + rx)
        W = max(xs) + 40
        return -W, W, self.root_y0 - 40, self.cy + self.cry + 40

    def outline(self, n=240):
        """Sample boundary points for preview (not exact)."""
        pts = []
        # crown
        for i in range(n):
            ang = i * math.tau / n
            r = self.crown_r(ang)
            x, y = self.cx + r * math.cos(ang), self.cy + r * math.sin(ang)
            # skip the very bottom of the ellipse that sits on the trunk if inside trunk
            pts.append((x, y, "crown"))
        return pts


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def lerp(a, b, t):
    return a + (b - a) * t


def seg_intersect(a, b, c, d, share_ok=True):
    """Proper intersection of open/closed segments. Endpoints sharing is not a crossing."""
    def ori(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])

    def on_seg(p, q, r):
        return (min(p[0], r[0]) - 1e-9 <= q[0] <= max(p[0], r[0]) + 1e-9
                and min(p[1], r[1]) - 1e-9 <= q[1] <= max(p[1], r[1]) + 1e-9)

    o1, o2 = ori(a, b, c), ori(a, b, d)
    o3, o4 = ori(c, d, a), ori(c, d, b)
    # shared endpoint
    for p in (a, b):
        for q in (c, d):
            if dist(p, q) < 1e-6:
                return False
    if o1 * o2 < 0 and o3 * o4 < 0:
        return True
    return False


def point_seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    vx, vy = bx - ax, by - ay
    l2 = vx * vx + vy * vy
    if l2 < 1e-12:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / l2))
    return math.hypot(px - (ax + t * vx), py - (ay + t * vy))


# ---------------------------------------------------------------------------
# Graph builder
# ---------------------------------------------------------------------------

class G:
    def __init__(self, seed: int):
        self.seed = seed
        self.rng = random.Random(seed)
        self.sil = Sil(seed)
        self.nodes = []
        self.links = []
        self.occ = []  # (x, y) pre-scale
        self.by = {}
        self.deg = Counter()
        self.nm = Counter()
        self.uidc = 0
        self.nti = {r: {th: 0 for th in THEMES[r]} for r in BR}
        self.clusters = []  # dicts
        self.top = {}
        self.seglinks = []  # ((x,y),(x,y), a_id, b_id)

    def rnd(self, a, b):
        return self.rng.uniform(a, b)

    def uid(self, p):
        self.uidc += 1
        return f"n{self.uidc}_{p}"

    def free(self, x, y, m=MIN_DIST):
        md2 = m * m
        for ox, oy in self.occ:
            if (x - ox) ** 2 + (y - oy) ** 2 < md2:
                return False
        return True

    def pick_name(self, pool):
        for n in sorted(pool, key=lambda n: (self.nm[n], self.rng.random())):
            if self.nm[n] < 6:
                self.nm[n] += 1
                return n
        n = f"Вузол ·{self.uidc}"
        self.nm[n] += 1
        return n

    def nname(self, rg, theme):
        p = NN[rg][theme]
        i = self.nti[rg][theme]
        self.nti[rg][theme] = i + 1
        n = p[i % len(p)]
        if self.nm[n] > 0:
            n = f"{n} ·{i + 1}"
        self.nm[n] += 1
        return n

    def power(self, y):
        # C3: weaker at roots, stronger at crown rim
        t = (y - 100) / 1600.0
        t = max(0.0, min(1.0, t))
        if t < 0.25:
            return 1, 2
        if t < 0.55:
            return 2, 3
        return 3, 4

    def desc(self, st):
        out = []
        for k, v in st.items():
            if k not in WIRED:
                continue
            nm = STAT_NAMES.get(k, k)
            if k in ("str", "agi", "faith", "hp", "armor", "mana_regen",
                     "one_path", "free_skills", "block_no_shield"):
                out.append(f"{nm}{'+' if v >= 0 else ''}{v}")
            else:
                out.append(f"{nm}{'+' if v >= 0 else ''}{v}%")
        return ", ".join(out) + "." if out else "—"

    def themed_stats(self, rg, theme, y, notable=False, travel=False, mixed=False):
        base, spr = self.power(y)
        if travel:
            keys = TRAVEL[rg][:]
            if mixed:
                other = [o for o in BR if o != rg][self.rng.randrange(2)]
                keys = keys + TRAVEL[other]
            k = self.rng.choice(keys)
            return {k: self.rng.randint(base, base + spr)}
        pool = THEMES[rg][theme][:]
        if mixed:
            other = [o for o in BR if o != rg][0]
            otheme = self.rng.choice(list(THEMES[other]))
            pool = pool + THEMES[other][otheme]
        n = 2 if notable else (1 if self.rng.random() < 0.7 else 2)
        ks = pool if len(pool) <= n else self.rng.sample(pool, n)
        st = {}
        for i, k in enumerate(ks):
            lo = base + (2 if notable else 0)
            hi = lo + spr + (2 if notable and i == 0 else 0)
            st[k] = st.get(k, 0) + self.rng.randint(lo, hi)
        if notable and self.rng.random() < 0.45:
            k2 = self.rng.choice(pool)
            st[k2] = st.get(k2, 0) + self.rng.randint(1, 2)
        if "skill_cost_pct" in st and st["skill_cost_pct"] > 0:
            st["skill_cost_pct"] = -st["skill_cost_pct"]
        return {k: v for k, v in st.items() if k in WIRED}

    def add(self, nid, name, x, y, typ, st, rg, dsc=None, mind=None):
        mind = MIN_DIST if mind is None else mind
        if not self.free(x, y, mind):
            return None
        st = {k: v for k, v in st.items() if k in WIRED}
        node = {
            "id": nid, "name": name,
            "description": dsc if dsc is not None else self.desc(st),
            "x": x, "y": y,  # pre-scale, converted at export
            "type": typ, "stats": st, "skill": "", "icon": "", "region": rg,
        }
        self.occ.append((x, y))
        self.nodes.append(node)
        self.by[nid] = node
        return nid

    def pos(self, nid):
        n = self.by[nid]
        return n["x"], n["y"]

    def ln(self, a, b, force=False, max_len=None):
        if not a or not b or a == b or a not in self.by or b not in self.by:
            return False
        if self.deg[a] >= MAX_DEG or self.deg[b] >= MAX_DEG:
            return False
        if any(tuple(sorted(L)) == tuple(sorted((a, b))) for L in self.links):
            return False
        ax, ay = self.pos(a)
        bx, by = self.pos(b)
        d = math.hypot(bx - ax, by - ay)
        cap = max_len if max_len is not None else STEP * 1.7
        if not force and d > cap:
            return False
        if d < MIN_DIST * 0.45:
            return False
        # crossings
        for (p, q, u, v) in self.seglinks:
            if {u, v} & {a, b}:
                continue
            if seg_intersect((ax, ay), (bx, by), p, q):
                return False
        self.links.append([a, b])
        self.deg[a] += 1
        self.deg[b] += 1
        self.seglinks.append(((ax, ay), (bx, by), a, b))
        return True

    # ----- sites -----
    def r_site(self, x, y):
        z = self.sil.zone(x, y)
        if z == "crown":
            return 88.0
        if z == "roots":
            return 92.0
        return 80.0

    def sample_sites(self):
        sil = self.sil
        xmin, xmax, ymin, ymax = sil.bbox()
        sites = []  # dicts {x,y,kind,rg,junc,theme,lock}

        def ok_site(x, y, r):
            if not sil.inside(x, y, 0.98):
                return False
            for s in sites:
                if math.hypot(x - s["x"], y - s["y"]) < max(r, s["r"]) * 0.82:
                    return False
            return True

        def add_site(x, y, kind, r=None, rg=None, junc=False, keep=False, theme=None, jitter=True):
            r = r or self.r_site(x, y)
            if not ok_site(x, y, r * 0.85 if kind != "fill" else r):
                if not jitter:
                    return None
                # try small jitter
                for _ in range(12):
                    jx = x + self.rnd(-r * 0.3, r * 0.3)
                    jy = y + self.rnd(-r * 0.3, r * 0.3)
                    if ok_site(jx, jy, r * 0.8):
                        x, y = jx, jy
                        break
                else:
                    if kind == "fill":
                        return None
            if rg is None:
                rg, junc = sil.region(x, y)
            if theme is None:
                theme = self.rng.choice(list(THEMES[rg]))
            s = {"x": x, "y": y, "kind": kind, "rg": rg, "junc": junc,
                 "theme": theme, "r": self.r_site(x, y), "id": len(sites),
                 "keep": keep or kind in ("start", "keystone")}
            sites.append(s)
            return s

        # 3 starts in root fans
        fx = [f[0] for f in sil.fans]
        fy = [f[1] - 70 for f in sil.fans]  # slightly lower in the fan
        add_site(fx[0], max(sil.root_y0 + 40, fy[0]), "start", rg="str")
        add_site(fx[1], max(sil.root_y0 + 20, fy[1] - 20), "start", rg="agi")
        add_site(fx[2], max(sil.root_y0 + 40, fy[2]), "start", rg="faith")

        # fill each root fan so the skirt is a web, not a lone start
        for cx, cy, rx, ry, rg in sil.fans:
            for radf, angs in ((0.46, 5), (0.76, 6)):
                for i in range(angs):
                    ang = sil.phase * 0.3 + i * math.tau / angs
                    x = cx + rx * radf * math.cos(ang)
                    y = cy + ry * radf * math.sin(ang) * 0.95
                    if y < sil.root_y0 + 8:
                        continue
                    add_site(x, y, "fill", r=76, rg=rg, keep=True)

        # 8–9 keystones on the crown rim (upper arc)
        # angles in standard math, y-up: 0=+x, pi/2=+y (crown top-ish depends on center)
        # top of crown is +y from center
        ks_spec = [
            (math.radians(125), "str"),
            (math.radians(145), "str"),
            (math.radians(165), "str"),
            (math.radians(80), "agi"),
            (math.radians(100), "agi"),
            (math.radians(60), "agi"),
            (math.radians(15), "faith"),
            (math.radians(35), "faith"),
            (math.radians(-5), "faith"),
        ]
        # Use first 8, but keep 3 per side when possible: drop one agi mid if 8
        # 3-3-3 is nicer; allow 9 keystones.
        for ang, rg in ks_spec:
            r = sil.crown_r(ang) * 0.90
            x = sil.cx + r * math.cos(ang)
            y = sil.cy + r * math.sin(ang)
            add_site(x, y, "keystone", r=100, rg=rg)

        # Three regional columns through the trunk (sites only — the node
        # graph stays a web via Gabriel loops). Planted BEFORE fill so they stick.
        col = (("str", -0.62), ("agi", 0.0), ("faith", 0.62))
        y = sil.trunk_bot + 16
        while y < sil.trunk_top - 12:
            hw = sil.trunk_hw(y)
            for rg, xf in col:
                add_site(xf * hw * 0.78, y, "fill", r=74, rg=rg, keep=True)
            y += 76
        # shoulders into the crown
        for rg, xf in (("str", -0.72), ("agi", -0.22), ("agi", 0.22), ("faith", 0.72)):
            add_site(xf * sil.crx * 0.50, sil.trunk_top + 8, "fill", r=80, rg=rg, keep=True)

        # soft scaffold in roots + lower/mid crown (mild curves, not spines)
        for rg, x0, amp in (("str", -0.55, 55), ("agi", 0.0, 40), ("faith", 0.55, 55)):
            for t in (0.08, 0.16, 0.70, 0.82, 0.90):
                y = lerp(200, sil.cy + sil.cry * 0.40, t)
                dy = y - sil.cy
                if sil.in_crown(0, y, 1.02) and abs(dy) < sil.cry:
                    hw = sil.crx * math.sqrt(max(0.0, 1 - (dy / sil.cry) ** 2))
                elif sil.in_trunk(0, y, 1.2):
                    hw = sil.trunk_hw(y)
                elif sil.in_roots(x0 * 200, y, 1.1):
                    hw = 320
                else:
                    continue
                x = x0 * hw + amp * math.sin(t * math.pi * 2 + sil.phase + {'str': 1, 'agi': 4, 'faith': 7}[rg] * 0.3)
                add_site(x, y, "fill", rg=rg, keep=True)

        # Poisson / dart throwing, denser in crown
        target = 78
        tries = 0
        max_tries = 16000
        while len(sites) < target and tries < max_tries:
            tries += 1
            if self.rng.random() < 0.58:
                ang = self.rnd(0, math.tau)
                rad = sil.crown_r(ang) * math.sqrt(self.rng.random()) * 0.96
                x = sil.cx + rad * math.cos(ang)
                y = sil.cy + rad * math.sin(ang)
            elif self.rng.random() < 0.50:
                y = self.rnd(sil.trunk_bot, sil.trunk_top)
                x = self.rnd(-1, 1) * sil.trunk_hw(y) * 0.88
            else:
                x = self.rnd(xmin, xmax)
                y = self.rnd(ymin, sil.trunk_bot + 20)
            if sil.inside(x, y, 0.96):
                add_site(x, y, "fill")

        if len(sites) < 84:
            for _ in range(4000):
                x = self.rnd(xmin, xmax)
                y = self.rnd(ymin, ymax)
                if sil.inside(x, y, 0.97):
                    add_site(x, y, "fill")
                if len(sites) >= 90:
                    break

        # Fill holes: grid scan of the mask
        step = 92
        x = xmin + 20
        while x <= xmax - 20:
            y = ymin + 20
            while y <= ymax - 20:
                if sil.inside(x, y, 0.90) and ok_site(x, y, 72):
                    add_site(x, y, "fill", r=76)
                y += step
            x += step

        # Drop isolated fill sites (would become dangling beads)
        def nearest(s0):
            best = 1e9
            for s in sites:
                if s is s0:
                    continue
                d = math.hypot(s0["x"] - s["x"], s0["y"] - s["y"])
                if d < best:
                    best = d
            return best
        sites[:] = [s for s in sites if s["kind"] != "fill" or nearest(s) < 150]

        CAP = 102
        if len(sites) > CAP:
            fill = [s for s in sites if s["kind"] == "fill" and not s.get("keep")]
            fill.sort(key=nearest)  # drop most crowded extras first
            need_drop = len(sites) - CAP
            drop = set()
            for s0 in fill:
                if need_drop <= 0:
                    break
                drop.add(id(s0))
                need_drop -= 1
            sites[:] = [s for s in sites if id(s) not in drop]

        # --- v7.1: fill known crown cavities (centre / right-of-spine / lower-right)
        # Internal coords (y-up). Few sites, small r, mostly agi in the centre hole.
        seeds = [
            (90, 1280, "agi"), (150, 1380, "agi"), (70, 1480, "agi"),
            (200, 1220, "agi"), (130, 1540, "agi"), (40, 1350, "agi"),
            (310, 1160, "faith"), (390, 1080, "faith"), (260, 1240, "agi"),
            # remaining cavities after first fill (centre-right seam, lower-right, left pocket)
            (50, 1600, "agi"), (190, 1520, "agi"), (270, 1480, "faith"),
            (250, 1400, "faith"), (230, 1320, "faith"),
            (-160, 1360, "str"), (-60, 1280, "agi"),
            (360, 1200, "faith"), (420, 1140, "faith"),
        ]
        added = 0
        for x, y, rg in seeds:
            if not sil.inside(x, y, 0.94):
                continue
            if ok_site(x, y, 78):
                th = list(THEMES[rg])[0]
                if add_site(x, y, "fill", r=74, rg=rg, keep=True, theme=th, jitter=False):
                    added += 1
        # grid scan only in the crown, only if still clearly empty
        if added < 8:
            xmin2, xmax2 = -sil.crx + 40, sil.crx - 40
            ymin2, ymax2 = sil.cy - sil.cry + 40, sil.cy + sil.cry - 20
            y = ymin2
            while y <= ymax2 and added < 8:
                x = xmin2
                while x <= xmax2 and added < 8:
                    if sil.in_crown(x, y, 0.90) and ok_site(x, y, 100):
                        rg, _j = sil.region(x, y)
                        # centre cavity is agi
                        if abs(x) < 220 and y > sil.trunk_top + 80:
                            rg = "agi"
                        th = list(THEMES[rg])[0]
                        if add_site(x, y, "fill", r=84, rg=rg, keep=True, theme=th, jitter=False):
                            added += 1
                    x += 90
                y += 90

        # Reindex
        for i, s in enumerate(sites):
            s["id"] = i
        self.sites = sites
        return sites

    def site_graph(self):
        sites = self.sites
        n = len(sites)
        pts = [(s["x"], s["y"]) for s in sites]

        def edge_ok(i, j, slop=1.08):
            ax, ay = pts[i]
            bx, by = pts[j]
            d = dist(pts[i], pts[j])
            if d < 40 or d > 260:
                return False
            steps = max(3, int(d / 14))
            for k in range(1, steps):
                t = k / steps
                x, y = lerp(ax, bx, t), lerp(ay, by, t)
                if not self.sil.inside(x, y, slop):
                    return False
            return True

        # Gabriel
        gab = []
        for i in range(n):
            for j in range(i + 1, n):
                if not edge_ok(i, j, 1.10):
                    continue
                mx = (pts[i][0] + pts[j][0]) / 2
                my = (pts[i][1] + pts[j][1]) / 2
                r2 = (dist(pts[i], pts[j]) / 2) ** 2
                bad = False
                for k in range(n):
                    if k == i or k == j:
                        continue
                    if (pts[k][0] - mx) ** 2 + (pts[k][1] - my) ** 2 < r2 - 1e-4:
                        bad = True
                        break
                if not bad:
                    gab.append((i, j, dist(pts[i], pts[j])))

        # MST on a dense-enough candidate set (kNN + gab)
        cand = set()
        for i, j, d in gab:
            cand.add((i, j, d))
        for i in range(n):
            nb = sorted(((dist(pts[i], pts[j]), j) for j in range(n) if j != i))[:7]
            for d, j in nb:
                a, b = (i, j) if i < j else (j, i)
                if edge_ok(a, b, 1.14):
                    cand.add((a, b, d))

        # Kruskal MST
        parent = list(range(n))

        def find(x):
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x

        def union(a, b):
            ra, rb = find(a), find(b)
            if ra == rb:
                return False
            parent[rb] = ra
            return True

        edges = []
        for i, j, d in sorted(cand, key=lambda e: e[2]):
            if union(i, j):
                edges.append((i, j, d))

        # If MST didn't connect everyone, add nearest connecting in-mask edges
        def comps():
            c = defaultdict(list)
            for i in range(n):
                c[find(i)].append(i)
            return list(c.values())

        for _ in range(20):
            cc = comps()
            if len(cc) == 1:
                break
            best = None
            for a in range(len(cc)):
                for b in range(a + 1, len(cc)):
                    for i in cc[a]:
                        for j in cc[b]:
                            d = dist(pts[i], pts[j])
                            if best is None or d < best[0]:
                                if edge_ok(i, j, 1.22) or d < 320:
                                    best = (d, i, j)
            if not best:
                break
            _d, i, j = best
            if union(i, j):
                edges.append((i, j, _d))

        # Add Gabriel edges for loops, degree cap 2–4, no crossings at site level
        deg = Counter()
        for i, j, _ in edges:
            deg[i] += 1
            deg[j] += 1

        def crosses(i, j):
            a, b = pts[i], pts[j]
            for u, v, _ in edges:
                if len({i, j, u, v}) < 4:
                    continue
                if seg_intersect(a, b, pts[u], pts[v]):
                    return True
            return False

        for i, j, d in sorted(gab, key=lambda e: e[2]):
            if (i, j, d) in edges or (j, i, d) in edges:
                continue
            if deg[i] >= 4 or deg[j] >= 4:
                continue
            if not edge_ok(i, j, 1.08):
                continue
            if crosses(i, j):
                continue
            edges.append((i, j, d))
            deg[i] += 1
            deg[j] += 1

        # A few extra short loops in the crown (still planar, deg<=4)
        extra = []
        for i in range(n):
            for j in range(i + 1, n):
                d = dist(pts[i], pts[j])
                if d > 180:
                    continue
                if not (sites[i]["kind"] != "start" and self.sil.in_crown(sites[i]["x"], sites[i]["y"], 1.05)):
                    continue
                extra.append((i, j, d))
        self.rng.shuffle(extra)
        for i, j, d in extra:
            if deg[i] >= 4 or deg[j] >= 4:
                continue
            if any((e[0] == i and e[1] == j) or (e[0] == j and e[1] == i) for e in edges):
                continue
            if not edge_ok(i, j, 1.06) or crosses(i, j):
                continue
            edges.append((i, j, d))
            deg[i] += 1
            deg[j] += 1

        # Ensure each region has a connected site-subgraph (so a pure path exists).
        from collections import deque as _dq

        def region_of(i):
            return sites[i]["rg"]

        def add_edge(i, j):
            d = dist(pts[i], pts[j])
            if any((e[0] == i and e[1] == j) or (e[0] == j and e[1] == i) for e in edges):
                return False
            if deg[i] >= 5 or deg[j] >= 5:
                return False
            if crosses(i, j) and d > 90:
                return False
            if not edge_ok(i, j, 1.20) and d > 140:
                return False
            edges.append((i, j, d))
            deg[i] += 1
            deg[j] += 1
            return True

        for rg in BR:
            idx = [i for i in range(n) if sites[i]["rg"] == rg or sites[i]["junc"]]
            if not idx:
                continue
            parent = {i: i for i in idx}

            def find(x, parent=parent):
                while parent[x] != x:
                    parent[x] = parent[parent[x]]
                    x = parent[x]
                return x

            for i, j, d in edges:
                if i in parent and j in parent:
                    a, b = find(i), find(j)
                    if a != b:
                        parent[b] = a
            # connect components of this region with the shortest feasible edge
            for _ in range(12):
                comps = {}
                for i in idx:
                    comps.setdefault(find(i), []).append(i)
                if len(comps) <= 1:
                    break
                keys = list(comps)
                best = None
                for a in range(len(keys)):
                    for b in range(a + 1, len(keys)):
                        for i in comps[keys[a]]:
                            for j in comps[keys[b]]:
                                d = dist(pts[i], pts[j])
                                if best is None or d < best[0]:
                                    best = (d, i, j)
                if not best:
                    break
                _d, i, j = best
                if add_edge(i, j):
                    parent[find(j)] = find(i)
                else:
                    # force union even if we could not add (avoid infinite loop)
                    parent[find(j)] = find(i)

        # v7.1: class = relative cost (C1). Cross-region corridors only in
        # the roots / very lower trunk, so the opposite-side top keystone
        # is 10–20 hops farther than your own. Adjacent mid-tree rungs
        # would equalize all three tops.
        Y_CROSS_MAX = 350.0  # y-up; ~export y >= -3500 (roots / collar only)
        pruned = []
        held = []
        for i, j, d in edges:
            my = (sites[i]["y"] + sites[j]["y"]) / 2.0
            if sites[i]["rg"] != sites[j]["rg"] and my > Y_CROSS_MAX:
                held.append((i, j, d))
            else:
                pruned.append((i, j, d))
        # keep the graph connected (should already be, via roots)
        parent = list(range(n))

        def find(x, parent=parent):
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x

        def union(a, b, parent=parent):
            ra, rb = find(a), find(b)
            if ra == rb:
                return False
            parent[rb] = ra
            return True

        for i, j, d in pruned:
            union(i, j)
        # if a component split, add back the lowest (closest to roots) held edge
        held.sort(key=lambda e: (e[0] and sites[e[0]]["y"] + sites[e[1]]["y"], e[2]))
        for i, j, d in held:
            if find(i) != find(j):
                pruned.append((i, j, d))
                union(i, j)
        deg = Counter()
        for i, j, d in pruned:
            deg[i] += 1
            deg[j] += 1
        edges = pruned

        self.site_edges = edges
        self.site_deg = deg
        return edges

    # ----- clusters -----
    def place_clusters(self):
        # sort so starts/keystones first
        order = sorted(self.sites, key=lambda s: 0 if s["kind"] != "fill" else 1)
        id_map = {s["id"]: s for s in self.sites}
        placed = {}
        ks_used = Counter()

        for s in order:
            rg, theme, junc = s["rg"], s["theme"], s["junc"]
            cx, cy = s["x"], s["y"]
            kind = s["kind"]
            cl = {"site": s["id"], "rg": rg, "theme": theme, "junc": junc,
                  "kind": kind, "ring": [], "center": None, "special": None,
                  "cx": cx, "cy": cy}

            if kind == "start":
                sid = START_ID[rg]
                st = {rg: 5}
                name = {"str": "Корінь · Сила", "agi": "Корінь · Спритність", "faith": "Корінь · Віра"}[rg]
                nid = self.add(sid, name, cx, cy, "start", st, rg, dsc="Початок шляху класу.", mind=MIN_DIST)
                if not nid:
                    # force
                    self.occ = [(ox, oy) for ox, oy in self.occ if math.hypot(ox - cx, oy - cy) > 1]
                    nid = self.add(sid, name, cx, cy, "start", st, rg, dsc="Початок шляху класу.", mind=MIN_DIST)
                cl["special"] = nid
                cl["center"] = nid
                ring_n, rad = 4, 28.0
                nodes = self._ring(cx, cy, rad, ring_n, rg, theme, junc, typ="small", travel=True)
                cl["ring"] = nodes
                for a, b in zip(nodes, nodes[1:] + nodes[:1]):
                    self.ln(a, b, max_len=STEP * 1.8)
                # two spokes from start to ring
                if nodes:
                    self.ln(nid, nodes[0], max_len=STEP * 1.8)
                    self.ln(nid, nodes[len(nodes) // 2], max_len=STEP * 1.8)

            elif kind == "keystone":
                idx = ks_used[rg]
                ks_used[rg] += 1
                cand = [k for k in NK if k[1] == rg]
                nm, _rg, st = cand[idx % len(cand)]
                # keystone slightly outward from crown center
                ang = math.atan2(cy - self.sil.cy, cx - self.sil.cx)
                kx = cx + math.cos(ang) * 10
                ky = cy + math.sin(ang) * 10
                kid = self.add(self.uid("ks"), nm, kx, ky, "keystone", dict(st), rg, mind=MIN_DIST)
                if not kid:
                    kid = self.add(self.uid("ks"), nm, cx, cy, "keystone", dict(st), rg, mind=MIN_DIST)
                cl["special"] = kid
                # approach ring inward
                ix = cx - math.cos(ang) * 28
                iy = cy - math.sin(ang) * 28
                nodes = self._ring(ix, iy, 27.0, 4, rg, theme, junc, typ="small", travel=True)
                cl["ring"] = nodes
                cl["center"] = nodes[0] if nodes else kid
                for a, b in zip(nodes, nodes[1:] + nodes[:1]):
                    self.ln(a, b, max_len=STEP * 1.8)
                if nodes:
                    self.ln(kid, nodes[0], max_len=STEP * 2.0)
                    if len(nodes) > 1:
                        self.ln(kid, nodes[1], max_len=STEP * 2.0)

            else:
                z = self.sil.zone(cx, cy)
                # notables more common higher
                t = (cy - 100) / 1600.0
                want_notable = (z == "crown" and self.rng.random() < 0.62) or (
                    z == "trunk" and self.rng.random() < 0.38) or (
                    z == "roots" and self.rng.random() < 0.20)
                if want_notable:
                    size = 5 if z == "crown" else 5
                    rad = 28.0
                    nodes = self._ring(cx, cy, rad, size, rg, theme, junc, typ="small")
                    # notable is ON the ring end (C10) — replace one ring slot
                    # actually: notable slightly inward of one ring node, reached at end
                    if nodes:
                        # put notable at center but only 2 spokes — optional jewel, path goes around
                        st = self.themed_stats(rg, theme, cy, notable=True, mixed=junc)
                        nid = self.add(self.uid("nt"), self.nname(rg, theme), cx, cy, "notable", st, rg,
                                       mind=MIN_DIST)
                        cl["center"] = nid
                        if nid and nodes:
                            self.ln(nid, nodes[0], max_len=STEP * 1.7)
                            self.ln(nid, nodes[1], max_len=STEP * 1.7)
                    cl["ring"] = nodes
                    for a, b in zip(nodes, nodes[1:] + nodes[:1]):
                        self.ln(a, b, max_len=STEP * 1.8)
                else:
                    size = 4 if z != "roots" else self.rng.choice([3, 4])
                    rad = 26.0 if size == 4 else 24.0
                    nodes = self._ring(cx, cy, rad, size, rg, theme, junc, typ="small")
                    cl["ring"] = nodes
                    cl["center"] = nodes[0] if nodes else None
                    for a, b in zip(nodes, nodes[1:] + nodes[:1]):
                        self.ln(a, b, max_len=STEP * 1.8)
                    if size == 4 and len(nodes) == 4 and self.rng.random() < 0.25:
                        self.ln(nodes[0], nodes[2], max_len=STEP * 1.8)

            if not cl["ring"] and not cl["special"]:
                # failed to place — drop site later
                continue
            placed[s["id"]] = cl
            self.clusters.append(cl)

        self.cl_by_site = placed
        return placed

    def _ring(self, cx, cy, rad, n, rg, theme, junc, typ="small", travel=False):
        nodes = []
        base = self.rnd(0, math.tau)
        for i in range(n):
            ang = base + i * (math.tau / n) + self.rnd(-0.10, 0.10)
            x = cx + math.cos(ang) * rad
            y = cy + math.sin(ang) * rad * 0.96
            if typ == "small":
                st = self.themed_stats(rg, theme, y, travel=travel or (typ == "small" and self.rng.random() < 0.35),
                                       mixed=junc)
                if travel:
                    st = self.themed_stats(rg, theme, y, travel=True, mixed=junc)
                nid = self.add(self.uid("sm"), self.pick_name(NS[rg]), x, y, "small", st, rg, mind=MIN_DIST)
            else:
                nid = None
            if nid:
                nodes.append(nid)
            else:
                # try slightly closer
                x = cx + math.cos(ang) * (rad * 0.8)
                y = cy + math.sin(ang) * (rad * 0.8)
                st = self.themed_stats(rg, theme, y, travel=True, mixed=junc)
                nid = self.add(self.uid("sm"), self.pick_name(NS[rg]), x, y, "small", st, rg, mind=MIN_DIST)
                if nid:
                    nodes.append(nid)
        return nodes

    def _ports(self, cl, toward):
        """Ring (and special) nodes closest to a point."""
        ids = list(cl["ring"])
        if cl.get("special") and cl["kind"] != "keystone":
            # don't use keystones as through-ports
            pass
        if cl["kind"] == "start" and cl.get("special"):
            ids = ids  # start is reached via ring; start itself is a port too
            ids = ids + [cl["special"]]
        pts = []
        for nid in ids:
            if nid not in self.by:
                continue
            x, y = self.pos(nid)
            pts.append((dist((x, y), toward), nid))
        pts.sort()
        return [p[1] for p in pts]

    def bezier_points(self, a, b, n):
        ax, ay = a
        bx, by = b
        mx, my = (ax + bx) / 2, (ay + by) / 2
        dx, dy = bx - ax, by - ay
        L = math.hypot(dx, dy) or 1
        # perpendicular bulge 12–20%
        s = self.rnd(0.10, 0.20) * (1 if self.rng.random() < 0.5 else -1)
        cx, cy = mx - dy / L * s * L, my + dx / L * s * L
        # keep control in / near mask
        if not self.sil.inside(cx, cy, 1.12):
            s *= -1
            cx, cy = mx - dy / L * s * L, my + dx / L * s * L
            if not self.sil.inside(cx, cy, 1.16):
                cx, cy = mx, my
        pts = []
        for i in range(1, n + 1):
            t = i / (n + 1)
            # quadratic
            x = (1 - t) ** 2 * ax + 2 * (1 - t) * t * cx + t ** 2 * bx
            y = (1 - t) ** 2 * ay + 2 * (1 - t) * t * cy + t ** 2 * by
            pts.append((x, y))
        return pts

    def connect_clusters(self):
        placed = self.cl_by_site
        for i, j, d in self.site_edges:
            if i not in placed or j not in placed:
                continue
            ca, cb = placed[i], placed[j]
            # choose ports
            tb = (cb["cx"], cb["cy"])
            ta = (ca["cx"], ca["cy"])
            pa = self._ports(ca, tb)
            pb = self._ports(cb, ta)
            if not pa or not pb:
                continue
            a_id = next((p for p in pa if self.deg[p] < MAX_DEG), None)
            b_id = next((p for p in pb if self.deg[p] < MAX_DEG and p != a_id), None)
            if not a_id or not b_id:
                continue
            ax, ay = self.pos(a_id)
            bx, by = self.pos(b_id)
            gap = dist((ax, ay), (bx, by))
            # how many travel nodes
            k = int(round(gap / STEP)) - 1
            k = max(0, min(4, k))
            if k <= 0:
                self.ln(a_id, b_id, force=gap < STEP * 2.1, max_len=STEP * 2.2)
                continue
            pts = self.bezier_points((ax, ay), (bx, by), k)
            mid = pts[len(pts) // 2]
            if ca["rg"] == cb["rg"]:
                rg, junc = ca["rg"], ca["junc"] or cb["junc"]
            else:
                rg, junc = self.sil.region(*mid)
                junc = True
            theme = ca["theme"] if ca["rg"] == rg else cb["theme"]
            chain = [a_id]
            ok = True
            for x, y in pts:
                if not self.free(x, y, MIN_DIST):
                    # nudge
                    found = False
                    for _ in range(8):
                        nx = x + self.rnd(-8, 8)
                        ny = y + self.rnd(-8, 8)
                        if self.free(nx, ny, MIN_DIST) and self.sil.inside(nx, ny, 1.14):
                            x, y = nx, ny
                            found = True
                            break
                    if not found:
                        ok = False
                        break
                st = self.themed_stats(rg, theme, y, travel=True, mixed=junc)
                nid = self.add(self.uid("tr"), self.pick_name(NS[rg]), x, y, "small", st, rg, mind=MIN_DIST)
                if not nid:
                    ok = False
                    break
                chain.append(nid)
            chain.append(b_id)
            if not ok:
                # try a single midpoint, never a long leap
                mx, my = (ax + bx) / 2, (ay + by) / 2
                if gap <= STEP * 2.0:
                    self.ln(a_id, b_id, max_len=STEP * 2.0)
                elif self.free(mx, my, MIN_DIST) and self.sil.inside(mx, my, 1.16):
                    st = self.themed_stats(rg, theme, my, travel=True, mixed=junc)
                    mid = self.add(self.uid("tr"), self.pick_name(NS[rg]), mx, my, "small", st, rg,
                                   mind=MIN_DIST)
                    if mid:
                        self.ln(a_id, mid, force=True, max_len=STEP * 2.0)
                        self.ln(mid, b_id, force=True, max_len=STEP * 2.0)
                continue
            for u, v in zip(chain, chain[1:]):
                if not self.ln(u, v, force=True, max_len=STEP * 2.4):
                    # if a forced mid-link fails on degree/cross, stop
                    break

    def place_core(self):
        # Heart of the tree: trunk–crown junction
        x, y = 0.0, self.sil.trunk_top + 20
        # snap to a free spot
        if not self.free(x, y, MIN_DIST):
            for r in range(10, 60, 8):
                for k in range(8):
                    ang = k * math.tau / 8
                    if self.free(x + r * math.cos(ang), y + r * math.sin(ang), MIN_DIST):
                        x += r * math.cos(ang)
                        y += r * math.sin(ang)
                        break
        st = {"hp_pct": 8, "dmg_pct": 6, "cdr_pct": 4}
        nid = self.add("core_heart", "Серце роду", x, y, "core", st, "agi", mind=MIN_DIST)
        if not nid:
            return
        # link to 2–3 nearest
        others = sorted(self.nodes, key=lambda n: dist((n["x"], n["y"]), (x, y)) if n["id"] != nid else 1e9)
        linked = 0
        for n in others:
            if n["id"] == nid:
                continue
            if self.ln(nid, n["id"], max_len=STEP * 2.0):
                linked += 1
            if linked >= 3:
                break

    # ----- connectivity & metrics -----
    def adj(self):
        a = defaultdict(list)
        for u, v in self.links:
            a[u].append(v)
            a[v].append(u)
        return a

    def hops(self, src, dst, allowed=None):
        """Hop count excluding src, including dst. Start costs 0 in game, every other node 1."""
        if src not in self.by or dst not in self.by:
            return None, []
        adj = self.adj()
        q = deque([src])
        prev = {src: None}
        while q:
            u = q.popleft()
            if u == dst:
                break
            for v in adj[u]:
                if v in prev:
                    continue
                if allowed is not None and v != dst and self.by[v]["region"] not in allowed:
                    continue
                prev[v] = u
                q.append(v)
        if dst not in prev:
            return None, []
        path = []
        cur = dst
        while cur is not None:
            path.append(cur)
            cur = prev[cur]
        path.reverse()
        # cost = number of non-start nodes
        cost = sum(1 for i in path[1:] if self.by[i]["type"] != "start")
        return cost, path

    def pick_tops(self):
        tops = {}
        for rg in BR:
            ks = [n for n in self.nodes if n["type"] == "keystone" and n["region"] == rg]
            if not ks:
                tops[rg] = None
                continue
            # most "outer" keystone of the specialty: up and toward its side
            def score(n):
                if rg == "str":
                    return n["y"] * 1.0 - n["x"] * 0.55
                if rg == "faith":
                    return n["y"] * 1.0 + n["x"] * 0.55
                return n["y"] * 1.15 - abs(n["x"]) * 0.08
            ks.sort(key=score, reverse=True)
            tops[rg] = ks[0]["id"]
        self.top = tops
        return tops

    def reconnect_orphans(self):
        adj = self.adj()
        starts = [START_ID[r] for r in BR if START_ID[r] in self.by]
        seen = set()
        q = deque(starts)
        for s in starts:
            seen.add(s)
        while q:
            u = q.popleft()
            for v in adj[u]:
                if v not in seen:
                    seen.add(v)
                    q.append(v)
        orphans = [n for n in self.nodes if n["id"] not in seen]
        for n in orphans:
            # link to nearest reachable
            nx, ny = n["x"], n["y"]
            cands = sorted(self.nodes, key=lambda o: dist((o["x"], o["y"]), (nx, ny)))
            for o in cands[1:30]:
                if o["id"] not in seen:
                    continue
                if self.ln(n["id"], o["id"], max_len=STEP * 2.6):
                    seen.add(n["id"])
                    break
        # drop still-orphaned smalls (never drop start/keystone/core)
        adj = self.adj()
        seen = set()
        q = deque(starts)
        for s in starts:
            seen.add(s)
        while q:
            u = q.popleft()
            for v in adj.get(u, []):
                if v not in seen:
                    seen.add(v)
                    q.append(v)
        keep = []
        drop = set()
        for n in self.nodes:
            if n["id"] in seen or n["type"] in ("start", "keystone", "core"):
                keep.append(n)
            else:
                drop.add(n["id"])
        if drop:
            self.nodes = keep
            self.by = {n["id"]: n for n in self.nodes}
            self.links = [L for L in self.links if L[0] not in drop and L[1] not in drop]
            self.seglinks = [s for s in self.seglinks if s[2] not in drop and s[3] not in drop]
            self.deg = Counter()
            for a, b in self.links:
                self.deg[a] += 1
                self.deg[b] += 1
            self.occ = [(n["x"], n["y"]) for n in self.nodes]
        return len(drop)

    def add_shortcuts(self, want_reduce=True):
        """Add a few same-region short links to shorten long own-paths, or none."""
        if not want_reduce:
            return 0
        added = 0
        by_rg = defaultdict(list)
        for n in self.nodes:
            if n["type"] == "small":
                by_rg[n["region"]].append(n)
        for rg, arr in by_rg.items():
            self.rng.shuffle(arr)
            for n in arr[:80]:
                if added >= 14:
                    return added
                if self.deg[n["id"]] >= 4:
                    continue
                cands = sorted(arr, key=lambda o: dist((o["x"], o["y"]), (n["x"], n["y"])))[1:8]
                for o in cands:
                    if self.deg[o["id"]] >= 4:
                        continue
                    d = dist((o["x"], o["y"]), (n["x"], n["y"]))
                    if d < MIN_DIST * 1.1 or d > STEP * 1.55:
                        continue
                    if self.ln(n["id"], o["id"], max_len=STEP * 1.6):
                        added += 1
                        break
        return added

    def pad_long_corridors(self, extra=1):
        """Subdivide mid-length links that aren't in a tight wheel, to lengthen paths."""
        if extra <= 0:
            return 0
        # snapshot links
        old = list(self.links)
        added = 0
        # don't subdivide very short (wheel) edges
        for a, b in old:
            if a not in self.by or b not in self.by:
                continue
            ax, ay = self.pos(a)
            bx, by = self.pos(b)
            d = dist((ax, ay), (bx, by))
            if d < STEP * 1.05 or d > STEP * 1.8:
                continue
            # only if this looks like a corridor (both small, not obviously a ring)
            if self.by[a]["type"] != "small" or self.by[b]["type"] != "small":
                continue
            mx, my = (ax + bx) / 2, (ay + by) / 2
            if not self.free(mx, my, MIN_DIST):
                continue
            rg = self.by[a]["region"]
            st = self.themed_stats(rg, "life" if rg == "str" else ("evasion" if rg == "agi" else "support"),
                                   my, travel=True)
            nid = self.add(self.uid("pd"), self.pick_name(NS[rg]), mx, my, "small", st, rg, mind=MIN_DIST)
            if not nid:
                continue
            # replace a-b with a-n-b
            self.links = [L for L in self.links if tuple(sorted(L)) != tuple(sorted((a, b)))]
            self.seglinks = [s for s in self.seglinks if tuple(sorted((s[2], s[3]))) != tuple(sorted((a, b)))]
            self.deg[a] -= 1
            self.deg[b] -= 1
            if self.ln(a, nid, force=True, max_len=STEP * 1.6) and self.ln(nid, b, force=True, max_len=STEP * 1.6):
                added += 1
            else:
                # rollback: restore a-b, drop nid if isolated
                self.ln(a, b, force=True, max_len=STEP * 2.5)
        return added

    def _insert_mid(self, a, b, mind=MIN_DIST):
        if a not in self.by or b not in self.by:
            return None
        ax, ay = self.pos(a)
        bx, by = self.pos(b)
        mx, my = (ax + bx) / 2.0, (ay + by) / 2.0
        # slight perpendicular nudge if occupied
        if not self.free(mx, my, mind):
            dx, dy = bx - ax, by - ay
            L = math.hypot(dx, dy) or 1
            for s in (6, -6, 10, -10, 14, -14):
                tx, ty = mx - dy / L * s, my + dx / L * s
                if self.free(tx, ty, mind) and self.sil.inside(tx, ty, 1.18):
                    mx, my = tx, ty
                    break
            else:
                return None
        rg = self.by[a]["region"]
        theme_key = list(THEMES[rg])[0]
        st = self.themed_stats(rg, theme_key, my, travel=True)
        nid = self.add(self.uid("sp"), self.pick_name(NS[rg]), mx, my, "small", st, rg, mind=mind)
        if not nid:
            return None
        self.links = [L for L in self.links if tuple(sorted(L)) != tuple(sorted((a, b)))]
        self.seglinks = [s for s in self.seglinks if tuple(sorted((s[2], s[3]))) != tuple(sorted((a, b)))]
        # deg was counted for a-b
        if self.deg[a] > 0:
            self.deg[a] -= 1
        if self.deg[b] > 0:
            self.deg[b] -= 1
        ok1 = self.ln(a, nid, force=True, max_len=STEP * 2.2)
        ok2 = self.ln(nid, b, force=True, max_len=STEP * 2.2)
        if not (ok1 and ok2):
            if ok1 or ok2:
                # messy; leave whatever connected
                return nid
            self.ln(a, b, force=True, max_len=STEP * 3.0)
            return None
        return nid

    def prune_high_cross_links(self, ymax=350.0):
        """Drop mid/upper cross-region links so opposite tops stay expensive (C1)."""
        keep = []
        for a, b in self.links:
            if a not in self.by or b not in self.by:
                continue
            if self.by[a]["region"] != self.by[b]["region"]:
                my = (self.by[a]["y"] + self.by[b]["y"]) / 2.0
                if my > ymax:
                    continue
            keep.append([a, b])
        self.links = keep
        self.deg = Counter()
        self.seglinks = []
        for a, b in self.links:
            self.deg[a] += 1
            self.deg[b] += 1
            self.seglinks.append((self.pos(a), self.pos(b), a, b))

    def split_long_links(self, cap=None):
        cap = cap or (STEP * 1.55)
        guard = 0
        while guard < 400:
            guard += 1
            skip = getattr(self, "_split_skip", set())
            long = []
            for a, b in self.links:
                if a in self.by and b in self.by:
                    if tuple(sorted((a, b))) in skip:
                        continue
                    d = dist(self.pos(a), self.pos(b))
                    if d > cap:
                        long.append((d, a, b))
            if not long:
                break
            long.sort(reverse=True)
            d, a, b = long[0]
            if not self._insert_mid(a, b):
                # skip this pair and try the next longest
                self._split_skip = getattr(self, "_split_skip", set())
                self._split_skip.add(tuple(sorted((a, b))))
                # filter: if all remaining long edges are skipped, stop
                rest = [1 for dd, aa, bb in long[1:] if tuple(sorted((aa, bb))) not in self._split_skip]
                if not rest:
                    break
                continue

    def lengthen_own_paths(self, lo=80, hi=88):
        self.pick_tops()
        for rg in BR:
            sid, tid = START_ID[rg], self.top.get(rg)
            if not tid:
                continue
            for _ in range(50):
                cost, path = self.hops(sid, tid, allowed=None)
                if cost is None or cost >= lo:
                    break
                # split the longest corridor-like edge on this path
                best = None
                for u, v in zip(path, path[1:]):
                    if u not in self.by or v not in self.by:
                        continue
                    d = dist(self.pos(u), self.pos(v))
                    if d < STEP * 0.95:
                        continue
                    if best is None or d > best[0]:
                        best = (d, u, v)
                if not best:
                    break
                if not self._insert_mid(best[1], best[2], mind=MIN_DIST):
                    # try the next-longest edges instead of giving up
                    inserted = False
                    for d, u, v in sorted(
                        ((dist(self.pos(a), self.pos(b)), a, b)
                         for a, b in zip(path, path[1:])
                         if a in self.by and b in self.by and dist(self.pos(a), self.pos(b)) >= STEP * 0.85),
                        reverse=True,
                    )[1:8]:
                        if self._insert_mid(u, v, mind=MIN_DIST):
                            inserted = True
                            break
                    if not inserted:
                        break

    def export_nodes(self):
        # convert to v4 coords: y-up -> y-down (negative y is crown / up on screen)
        out = []
        for n in self.nodes:
            m = dict(n)
            m["x"] = round(n["x"] * SCALE, 1)
            m["y"] = round(-n["y"] * SCALE, 1)
            if m["x"] == 0:
                m["x"] = 0.0
            if m["y"] == 0:
                m["y"] = 0.0
            out.append(m)
        return out

    def metrics(self):
        xs = [n["x"] for n in self.nodes]
        ys = [n["y"] for n in self.nodes]
        # link lengths (pre-scale)
        lens = []
        for a, b in self.links:
            if a in self.by and b in self.by:
                lens.append(dist(self.pos(a), self.pos(b)))
        # min node distance
        md = 1e9
        pts = [(n["x"], n["y"]) for n in self.nodes]
        for i in range(len(pts)):
            for j in range(i + 1, len(pts)):
                d = dist(pts[i], pts[j])
                if d < md:
                    md = d
        # crossings
        cross = 0
        segs = [((self.by[a]["x"], self.by[a]["y"]), (self.by[b]["x"], self.by[b]["y"]), a, b)
                for a, b in self.links if a in self.by and b in self.by]
        for i in range(len(segs)):
            for j in range(i + 1, len(segs)):
                a1, b1, u, v = segs[i]
                a2, b2, p, q = segs[j]
                if {u, v} & {p, q}:
                    continue
                if seg_intersect(a1, b1, a2, b2):
                    cross += 1
        # orphans
        adj = self.adj()
        starts = [START_ID[r] for r in BR if START_ID[r] in self.by]
        seen = set(starts)
        q = deque(starts)
        while q:
            u = q.popleft()
            for v in adj.get(u, []):
                if v not in seen:
                    seen.add(v)
                    q.append(v)
        orphans = len(self.nodes) - len(seen)
        # desc mismatch (keystones included — desc must match stats)
        mism = sum(1 for n in self.nodes if n["description"] != self.desc(n["stats"])
                   and n["type"] != "start")
        # start has custom desc, that's ok
        unwired = sum(1 for n in self.nodes for k in n["stats"] if k not in WIRED)
        maxdeg = max(self.deg.values()) if self.deg else 0
        name_max = max(self.nm.values()) if self.nm else 0
        # paths
        self.pick_tops()
        paths = {}
        for rg in BR:
            sid, tid = START_ID[rg], self.top.get(rg)
            own, op = self.hops(sid, tid, allowed=None)
            locked, _lp = self.hops(sid, tid, allowed={rg})
            anyc, ap = own, op
            hyb = {}
            for og in BR:
                if og == rg:
                    continue
                ot = self.top.get(og)
                hc, hp = self.hops(sid, ot, allowed=None)
                hyb[og] = (hc, hp)
            paths[rg] = {"own": own, "own_path": op, "any": anyc, "locked": locked, "hyb": hyb}

        mean_l = sum(lens) / len(lens) if lens else 0
        return {
            "N": len(self.nodes),
            "links": len(self.links),
            "types": dict(Counter(n["type"] for n in self.nodes)),
            "regions": dict(Counter(n["region"] for n in self.nodes)),
            "link_min": min(lens) if lens else 0,
            "link_mean": mean_l,
            "link_max": max(lens) if lens else 0,
            "min_node_dist": md,
            "max_degree": maxdeg,
            "crossings": cross,
            "orphans": orphans,
            "desc_mismatch": mism,
            "name_max_repeat": name_max,
            "unwired": unwired,
            "paths": paths,
            "top": self.top,
            "bbox": (min(xs), max(xs), min(ys), max(ys)),
        }


    def widen_crown(self, factor=1.18, silhouette=1.34):
        """Mild horizontal scale of the existing crown; enlarge the
        silhouette so side space can be filled into a rounder canopy."""
        sil = self.sil
        self._old_crx = sil.crx
        y_lo = sil.trunk_top
        y_hi = sil.cy + sil.cry * 0.25

        def fac(y):
            if y <= y_lo:
                return 1.0
            t = (y - y_lo) / max(1.0, y_hi - y_lo)
            t = max(0.0, min(1.0, t))
            sm = t * t * (3.0 - 2.0 * t)
            return 1.0 + (factor - 1.0) * sm

        for n in self.nodes:
            f = fac(n["y"])
            if f != 1.0:
                n["x"] *= f
        sil.crx = self._old_crx * silhouette
        self.occ = [(n["x"], n["y"]) for n in self.nodes]
        self.seglinks = []
        for a, b in self.links:
            if a in self.by and b in self.by:
                self.seglinks.append((self.pos(a), self.pos(b), a, b))

    def fill_crown_wings(self):
        """Grow compact wheels outward in 3 layers so the new side space
        becomes a filled, rounded bulge rather than a long arm."""
        sil = self.sil
        rng = random.Random(self.seed + 72)

        def region_of(x, y):
            # keep wings on the same side as the existing canopy
            if x < sil.cx - 20:
                return "str"
            if x > sil.cx + 20:
                return "faith"
            return "agi"

        # candidates on a wide ellipse, including lower shoulders (armpits)
        # 0=+x, 90=+y (crown top), 180=-x, 270=-y (trunk)
        cands = []
        for ang_deg in range(10, 171, 7):
            for radf in (0.64, 0.74, 0.83, 0.90, 0.95):
                # skip almost-vertical top (agi already sits there)
                if 80 <= ang_deg <= 100 and radf < 0.85:
                    continue
                ang = math.radians(ang_deg)
                r = sil.crown_r(ang) * radf
                x = sil.cx + r * math.cos(ang)
                y = sil.cy + r * math.sin(ang)
                if y < sil.trunk_top + 20:
                    continue
                if not sil.in_crown(x, y, 0.99):
                    continue
                if abs(x) < self._old_crx * 0.48:
                    continue
                cands.append((x, y, region_of(x, y)))

        def nearest_same(x, y, rg, exclude=()):
            best = None
            for n in self.nodes:
                if n["region"] != rg or n["id"] in exclude:
                    continue
                if self.deg[n["id"]] >= MAX_DEG:
                    continue
                g = dist((x, y), (n["x"], n["y"]))
                if best is None or g < best[0]:
                    best = (g, n)
            return best

        placed = 0
        max_place = 20
        # 3 layers: only attach if close; later rounds can use earlier wheels
        for max_gap in (72, 88, 100):
            rng.shuffle(cands)
            for x, y, rg in cands:
                if placed >= max_place:
                    return
                if not self.free(x, y, 58):
                    continue
                near = nearest_same(x, y, rg)
                if near is None or near[0] > max_gap or near[0] < MIN_DIST * 1.2:
                    continue
                theme = list(THEMES[rg])[rng.randrange(len(THEMES[rg]))]
                ring = self._ring(x, y, 24.0, 4, rg, theme, False, typ="small")
                if len(ring) < 3:
                    continue
                for a, b in zip(ring, ring[1:] + ring[:1]):
                    self.ln(a, b, max_len=STEP * 1.8)
                # attach closest ring node to the nearby existing node
                best = None
                for pid in ring:
                    if self.deg[pid] >= MAX_DEG:
                        continue
                    px, py = self.pos(pid)
                    g = dist((px, py), (near[1]["x"], near[1]["y"]))
                    if best is None or g < best[0]:
                        best = (g, pid)
                if best is None:
                    continue
                gap, port = best
                tgt = near[1]
                px, py = self.pos(port)
                tx, ty = tgt["x"], tgt["y"]
                k = max(0, min(2, int(round(gap / STEP)) - 1))
                if k <= 0:
                    if not self.ln(port, tgt["id"], max_len=STEP * 2.0):
                        continue
                else:
                    chain = [port]
                    ok = True
                    for i in range(1, k + 1):
                        t = i / (k + 1)
                        wx = px + (tx - px) * t
                        wy = py + (ty - py) * t
                        if not self.free(wx, wy, MIN_DIST) or not sil.inside(wx, wy, 1.15):
                            ok = False
                            break
                        st = self.themed_stats(rg, theme, wy, travel=True)
                        nid = self.add(self.uid("wg"), self.pick_name(NS[rg]),
                                       wx, wy, "small", st, rg, mind=MIN_DIST)
                        if not nid:
                            ok = False
                            break
                        chain.append(nid)
                    chain.append(tgt["id"])
                    if not ok:
                        continue
                    for u, v in zip(chain, chain[1:]):
                        self.ln(u, v, force=True, max_len=STEP * 2.2)
                placed += 1


    def thicken_lobe_skirts(self):
        """Grow one or two compact rows under each side lobe, attached
        back into the dense canopy — fills the shoulder without a spur."""
        sil = self.sil
        rng = random.Random(self.seed + 74)
        seeds = [n for n in self.nodes
                 if n["region"] in ("str", "faith")
                 and (sil.cy - 40) <= n["y"] <= (sil.cy + 90)
                 and abs(n["x"]) >= self._old_crx * 0.50]
        placed = 0
        rng.shuffle(seeds)
        for n in seeds:
            for down, out in ((55, 30), (95, 55), (70, 80)):
                if placed >= 8:
                    return
                x = n["x"] + (out if n["x"] > 0 else -out)
                y = n["y"] - down
                if y < sil.trunk_top + 40:
                    continue
                if not sil.inside(x, y, 1.08):
                    continue
                if not self.free(x, y, 58):
                    continue
                # must sit next to at least two existing same-region nodes
                near = [o for o in self.nodes
                        if o["region"] == n["region"]
                        and MIN_DIST * 1.15 <= dist((x, y), (o["x"], o["y"])) <= 95]
                if len(near) < 2:
                    continue
                rg = n["region"]
                theme = list(THEMES[rg])[rng.randrange(len(THEMES[rg]))]
                ring = self._ring(x, y, 24.0, 4, rg, theme, False, typ="small")
                if len(ring) < 3:
                    continue
                for a, b in zip(ring, ring[1:] + ring[:1]):
                    self.ln(a, b, max_len=STEP * 1.8)
                made = 0
                near.sort(key=lambda o: dist((x, y), (o["x"], o["y"])))
                for o in near[:6]:
                    if made >= 2:
                        break
                    if self.deg[o["id"]] >= MAX_DEG:
                        continue
                    best = None
                    for pid in ring:
                        if self.deg[pid] >= MAX_DEG:
                            continue
                        g = dist(self.pos(pid), (o["x"], o["y"]))
                        if MIN_DIST * 1.1 <= g <= 100:
                            if best is None or g < best[0]:
                                best = (g, pid)
                    if best and self.ln(best[1], o["id"], max_len=STEP * 2.0):
                        made += 1
                if made >= 1:
                    placed += 1

    def fill_armpits(self):
        """Fill the concave shoulders under the side lobes so the canopy
        reads rounder, attaching both down to the collar and up to the lobe."""
        sil = self.sil
        rng = random.Random(self.seed + 73)
        pts = [
            (-0.58, 0.12, "str"), (-0.72, 0.22, "str"), (-0.65, 0.34, "str"),
            (0.58, 0.12, "faith"), (0.72, 0.22, "faith"), (0.65, 0.34, "faith"),
        ]
        for xf, yf, rg in pts:
            x = sil.cx + sil.crx * xf
            y = sil.trunk_top + (sil.cy + sil.cry * 0.15 - sil.trunk_top) * yf
            if not sil.inside(x, y, 1.05):
                continue
            if not self.free(x, y, 56):
                continue
            theme = list(THEMES[rg])[rng.randrange(len(THEMES[rg]))]
            ring = self._ring(x, y, 24.0, 4, rg, theme, False, typ="small")
            if len(ring) < 3:
                continue
            for a, b in zip(ring, ring[1:] + ring[:1]):
                self.ln(a, b, max_len=STEP * 1.8)
            others = [n for n in self.nodes if n["region"] == rg and n["id"] not in ring]
            # attach up to two neighbors: one below, one above (or the two nearest)
            attachments = []
            for pid in ring:
                px, py = self.pos(pid)
                for n in others:
                    if self.deg[n["id"]] >= MAX_DEG or self.deg[pid] >= MAX_DEG:
                        continue
                    g = dist((px, py), (n["x"], n["y"]))
                    if MIN_DIST * 1.1 <= g <= 135:
                        attachments.append((g, pid, n))
            attachments.sort()
            used_tgt = set()
            made = 0
            for g, port, tgt in attachments:
                if made >= 2:
                    break
                if tgt["id"] in used_tgt:
                    continue
                if self.deg[port] >= MAX_DEG or self.deg[tgt["id"]] >= MAX_DEG:
                    continue
                px, py = self.pos(port)
                tx, ty = tgt["x"], tgt["y"]
                k = max(0, min(3, int(round(g / STEP)) - 1))
                if k <= 0:
                    if self.ln(port, tgt["id"], max_len=STEP * 2.1):
                        used_tgt.add(tgt["id"])
                        made += 1
                else:
                    chain = [port]
                    ok = True
                    for i in range(1, k + 1):
                        t = i / (k + 1)
                        wx = px + (tx - px) * t
                        wy = py + (ty - py) * t
                        if not self.free(wx, wy, MIN_DIST) or not sil.inside(wx, wy, 1.15):
                            ok = False
                            break
                        st = self.themed_stats(rg, theme, wy, travel=True)
                        nid = self.add(self.uid("ap"), self.pick_name(NS[rg]),
                                       wx, wy, "small", st, rg, mind=MIN_DIST)
                        if not nid:
                            ok = False
                            break
                        chain.append(nid)
                    chain.append(tgt["id"])
                    if not ok:
                        continue
                    good = True
                    for u, v in zip(chain, chain[1:]):
                        if not self.ln(u, v, force=True, max_len=STEP * 2.3):
                            good = False
                            break
                    if good:
                        used_tgt.add(tgt["id"])
                        made += 1

    def integrate_wings(self):
        """Add a second same-region link on new side clusters so they mesh
        into the canopy instead of hanging off a single corridor."""
        crown = [n for n in self.nodes if n["y"] > self.sil.trunk_top - 10]
        added = 0
        for n in crown:
            if n["type"] != "small" or abs(n["x"]) < self._old_crx * 0.45:
                continue
            if self.deg[n["id"]] >= 4:
                continue
            cands = []
            for o in crown:
                if o["id"] == n["id"] or o["region"] != n["region"]:
                    continue
                if self.deg[o["id"]] >= MAX_DEG:
                    continue
                # skip already-adjacent
                g = dist((n["x"], n["y"]), (o["x"], o["y"]))
                if MIN_DIST * 1.15 <= g <= STEP * 1.65:
                    cands.append((g, o))
            cands.sort()
            for g, o in cands[:6]:
                if self.ln(n["id"], o["id"], max_len=STEP * 1.7):
                    added += 1
                    break
            if added >= 24:
                return

    def cap_opposite(self, slack=20):
        """If an opposite top is above own+slack, add a short same-region
        chord that shaves a hop or two without dropping own below 80."""
        def rollback(u, v, snap_links, snap_deg, snap_seg):
            self.links = [list(L) for L in snap_links]
            self.deg = snap_deg.copy()
            self.seglinks = list(snap_seg)

        for _try in range(6):
            m = self.metrics()
            over = []
            for rg in BR:
                own = m["paths"][rg]["own"]
                for og, pair in m["paths"][rg]["hyb"].items():
                    hc, hp = pair
                    if own is None or hc is None or hp is None:
                        continue
                    if rg in ("str", "faith") and og in ("str", "faith") and hc > own + slack:
                        over.append((hc - own - slack, rg, og, hp, own, hc))
            if not over:
                return
            over.sort(reverse=True)
            _, rg, og, hp, own, hc = over[0]
            shaved = False
            for skip in (2, 3):
                for i in range(0, max(0, len(hp) - skip)):
                    u, v = hp[i], hp[i + skip]
                    if u not in self.by or v not in self.by:
                        continue
                    if self.by[u]["region"] != self.by[v]["region"]:
                        continue
                    if self.deg[u] >= MAX_DEG or self.deg[v] >= MAX_DEG:
                        continue
                    d = dist(self.pos(u), self.pos(v))
                    if d < MIN_DIST * 1.1 or d > STEP * 1.7:
                        continue
                    snap_links = [list(L) for L in self.links]
                    snap_deg = self.deg.copy()
                    snap_seg = list(self.seglinks)
                    if not self.ln(u, v, max_len=STEP * 1.7):
                        continue
                    m2 = self.metrics()
                    bad = False
                    for r2 in BR:
                        o2 = m2["paths"][r2]["own"]
                        if o2 is not None and o2 < 80:
                            bad = True
                    if m2["crossings"] > 0:
                        bad = True
                    if bad:
                        rollback(u, v, snap_links, snap_deg, snap_seg)
                        continue
                    shaved = True
                    break
                if shaved:
                    break
            if not shaved:
                return


    def build(self):
        self.sample_sites()
        self.site_graph()
        self.place_clusters()
        self.connect_clusters()
        self.place_core()
        self.reconnect_orphans()
        self.prune_high_cross_links(350.0)
        self.reconnect_orphans()
        self.split_long_links(STEP * 1.55)
        self.lengthen_own_paths(80, 88)
        self.split_long_links(STEP * 1.58)
        # v7.2: same tree, wider / rounder crown, fill the side space
        self.widen_crown(factor=1.18, silhouette=1.34)
        self.split_long_links(STEP * 1.55)
        self.fill_crown_wings()
        self.thicken_lobe_skirts()
        self.integrate_wings()
        self.split_long_links(STEP * 1.58)
        self.prune_high_cross_links(350.0)
        self.reconnect_orphans()
        self.lengthen_own_paths(80, 88)
        self.split_long_links(STEP * 1.58)
        self.cap_opposite(slack=20)
        m = self.metrics()
        owns = [m["paths"][rg]["own"] for rg in BR if m["paths"][rg]["own"] is not None]
        if owns and min(owns) > 95:
            self.add_shortcuts(True)
            self.reconnect_orphans()
            m = self.metrics()
        return m


def tree_dict(g: G):
    return {
        "format": "spohady-perk-tree",
        "version": 4,
        "title": "Древо звитяги",
        "comment": (
            f"v7.2 seed={g.seed}: ширша кругла крона, силует дерева, павутина PoE. "
            "всередині павутина PoE (колеса + короткі стежки)."
        ),
        "regions": REGIONS,
        "class_starts": CLASS_STARTS,
        "nodes": g.export_nodes(),
        "links": g.links,
        "meta": {
            "generator": "generate_perk_tree_v7.py",
            "seed": g.seed,
            "scale": SCALE,
            "needs_wiring": NEEDS_WIRING,
            "top_keystones": g.top,
            "version_tag": "v7.2",
        },
    }


def main(argv=None):
    args = parse(argv)
    refuse(args.out, args.force)
    g = G(args.seed)
    m = g.build()
    data = tree_dict(g)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    # compact report
    p = m["paths"]
    def fmt(rg):
        own = p[rg]["own"]
        hyb = ", ".join(f"{k}:{v[0]}" for k, v in p[rg]["hyb"].items())
        return f"{rg} own={own} hyb[{hyb}]"
    print(
        f"v7.2 seed={args.seed} N={m['N']} links={m['links']} types={m['types']} "
        f"deg={m['max_degree']} orphans={m['orphans']} cross={m['crossings']} "
        f"link={m['link_min']:.1f}/{m['link_mean']:.1f}/{m['link_max']:.1f} "
        f"mindist={m['min_node_dist']:.1f} mism={m['desc_mismatch']} "
        f"unwired={m['unwired']} namemax={m['name_max_repeat']}"
    )
    for rg in BR:
        print(" ", fmt(rg))
    print(" wrote", args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
