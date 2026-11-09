#!/usr/bin/env python3
"""
Генератор Древа звитяги v5.
Геометрія Yggdrasil: коріння(віяла) → стовбур(4 пасми) → перехід → крона(3 гілки)
→ грона(notable+кільце) → keystones + core. Кожен шар явно з'єднаний з попереднім,
тому дерево зв'язне за побудовою (без післяфакт-чистки сиріт).

Силует залежить від seed: пропорції коріння й стовбура, розхил і глибина крони,
позиції грон та еліпс вершин беруться з діапазонів (див. SH). Кількості й формат
незмінні, тому кожен seed дає помітно інше дерево, але тієї ж будови.
"""
import json, math, random, os
from collections import deque, Counter
random.seed(424242)

SCALE    = 10
TARGET   = 840          # ціл. кількість вузлів
MIN_DIST = 150          # мін. відстань (щільні координати, ×SCALE на експорті)

REGIONS = [
    {"id": "str",   "name": "Сила",       "color": "#D8574B"},
    {"id": "agi",   "name": "Спритність",  "color": "#7CBF5A"},
    {"id": "faith", "name": "Віра",        "color": "#E0A526"},
]
CLASS_STARTS = {
    "druzhynnyk": "s_root",
    "strilets":   "a_root",
    "volkhv":     "f_root",
}

STAT_KEYS = {
    "str":   ["str", "dmg_pct", "hp_pct", "armor", "atk_speed_pct", "hp", "lifesteal_pct", "thorns_pct", "block_pct", "dr_pct", "crit_pct", "res_all_pct", "pen_all_pct"],
    "agi":   ["agi", "dmg_pct", "crit_pct", "dodge_pct", "atk_speed_pct", "move_pct", "proj_speed_pct", "crit_dmg_pct", "cdr_pct", "double_hit_pct", "armor_pen_pct"],
    "faith": ["faith", "dmg_pct", "mana_pct", "mana_regen", "effect_dur_pct", "hp_regen_pct", "res_all_pct", "nauz_xp_pct", "skill_cost_pct", "cdr_pct", "aoe_pct"],
}
STAT_NAMES = {
    "str": "Сили", "agi": "Спритності", "faith": "Віри",
    "dmg_pct": "шкоди", "hp_pct": "життя", "armor": "броні", "atk_speed_pct": "швидкості атаки",
    "hp": "життя", "lifesteal_pct": "лічі", "thorns_pct": "шипів", "block_pct": "блоку", "dr_pct": "захисту",
    "crit_pct": "крита", "dodge_pct": "ухилення", "move_pct": "руху", "proj_speed_pct": "снаряда",
    "crit_dmg_pct": "критичної шкоди", "cdr_pct": "відновлення",
    "mana_pct": "чару", "mana_regen": "відновлення чару", "effect_dur_pct": "тривалості",
    "hp_regen_pct": "регенерації", "res_all_pct": "опору", "nauz_xp_pct": "росту наузів", "skill_cost_pct": "вартості",
    "double_hit_pct": "подвійного удару", "armor_pen_pct": "пробиття броні",
    "aoe_pct": "площі", "pen_all_pct": "пробиття",
}

_nodes  = []
_links  = []
_uid_c  = 0
occupied = []   # щільні координати (x,y) вже створених вузлів — контроль відстаней


def space_ok(x, y, mind=16):
    """Чи є принаймні mind щільних одиниць до всіх уже розставлених вузлів?"""
    for ox, oy in occupied:
        if math.hypot(x - ox, y - oy) < mind:
            return False
    return True


def uid(pfx):
    global _uid_c; _uid_c += 1
    return f"n{_uid_c}_{pfx}"

def ri(a, b): return random.randint(a, b)
def rnd(a, b): return random.uniform(a, b)

# ─── силует: пропорції, похідні від seed ──────────────────────
# Кількості (3 корені, 4 пасми, 3 гілки, 10 грон, 8 вершин) і формат
# лишаються ті самі — міняється лише геометрія, тому кожен seed
# дає помітно інший силует дерева.
SH = {
    "root_spread":  rnd(0.12, 0.70),   # нахил крайніх віял коріння
    "root_fan":     rnd(0.08, 0.14),   # крок вузлів у віялі
    "root_len":     rnd(0.68, 1.35),   # довжина коріння
    "root_gap":     rnd(26, 48),       # відстань між вузлами віяла
    "trunk_h":      rnd(280, 460),     # висота стовбура
    "trunk_steps":  ri(10, 26),        # вузлів у кожній пасмі
    "trunk_w":      rnd(95, 215),      # півширина стовбура
    "trunk_drift":  rnd(-25, 25),      # викривлення стовбура
    "trans_h":      rnd(180, 380),     # висота переходу до крони
    "branch_x":     rnd(280, 820),     # винесення бічних гілок
    "branch_y":     rnd(470, 980),     # глибина основи гілки
    "branch_cnt":   [ri(20, 50), ri(24, 56), ri(20, 50)],
    "branch_r":     rnd(0.70, 1.30),   # радіус дуги гілки
    "branch_sq":    rnd(0.30, 0.50),   # сплющення дуги
    "arc_span":     rnd(0.60, 1.05),   # розхил дуги гілки
    "fruit_jitter": rnd(150, 420),     # розкид грон
    "ring_scale":   rnd(0.75, 1.35),   # радіус кільця грона
    "key_base":     -1700 + rnd(-90, 90),
    "key_rx":       rnd(380, 780),     # півширина еліпса вершин
    "key_ry":       rnd(120, 330),     # висота дуги вершин
    "key_rot":      rnd(0, math.tau),  # поворот кільця
    "core_y":       -1900 + rnd(-80, 80),
    "xmax":         rnd(1150, 1450),   # межа полотна по X
    "ymax":         rnd(1500, 1900),   # межа полотна по Y
    "fill_rx":      rnd(1050, 1500),
    "fill_ry":      rnd(900, 1400),
    "fill_cy":      rnd(200, 470),
    "fill_sy":      rnd(0.65, 1.45),
}
SH["trunk_step"] = SH["trunk_h"] / max(1, SH["trunk_steps"] - 1)
SH["trans_step"] = SH["trans_h"] / 5

def mk_stats(rg, base=2):
    pool = STAT_KEYS[rg]
    s1 = random.choice(pool)
    v1 = ri(base, base + 3)
    s2 = random.choice([k for k in pool if k != s1])
    v2 = ri(base, base + 4)
    d = {s1: v1, s2: v2}
    if random.random() < 0.2:
        s3 = random.choice([k for k in pool if k not in d])
        d[s3] = ri(1, 3)
    return d

def mk_desc(s):
    parts = []
    for k, v in s.items():
        n = STAT_NAMES.get(k, k)
        parts.append(f"{n}+{v}" if k in ("str", "agi", "faith") else f"{n}+{v}%")
    return ", ".join(parts) + "."

def add(nid, name, dsc, x, y, typ, st, rg):
    occupied.append((x, y))  # щільні координати для space_ok
    sx = round(x * SCALE, 1)
    sy = round(y * SCALE, 1)
    if sx == 0: sx = 0.0    # уникати -0.0 (Node deepStrictEqual розрізняє знаки)
    if sy == 0: sy = 0.0
    _nodes.append({"id": nid, "name": name, "description": dsc,
                    "x": sx, "y": sy,
                    "type": typ, "stats": st, "skill": "", "icon": "", "region": rg})

def ln(a, b):
    if a and b and a != b:
        _links.append([a, b])


def _y_diff(a, b):
    na = next(n for n in _nodes if n["id"] == a)
    nb = next(n for n in _nodes if n["id"] == b)
    return na["y"] - nb["y"]


def nearest_to(x, y, id_filter=None):
    """Найближчий вузол до (x,y) серед існуючих (опц. фільтр за id)."""
    best, bd = None, None
    for n in _nodes:
        if id_filter and n["id"] not in id_filter:
            continue
        d = math.hypot(n["x"] / SCALE - x, n["y"] / SCALE - y)
        if bd is None or d < bd:
            bd, best = d, n["id"]
    return best


# ══════════════════════════════════════════════════════════
# 1. КОРІННЯ — три віяла знизу (y ≈ 600..820)
# ══════════════════════════════════════════════════════════
root_ids = {"str": [], "agi": [], "faith": []}
CX = {k: v * rnd(0.85, 1.12) for k, v in {"str": -300, "agi": 0, "faith": 300}.items()}
for rg, cls in [("str", "druzhynnyk"), ("agi", "strilets"), ("faith", "volkhv")]:
    cx = CX[rg]
    sid = CLASS_STARTS[cls]
    add(sid, "Початок шляху", f"Старт {cls}.", cx, 760, "start", mk_stats(rg, 2), rg)
    root_ids[rg].append(sid)
    for i in range(14):
        ang = {"str": -SH["root_spread"], "agi": 0.0, "faith": SH["root_spread"]}[rg] + (i - 7) * SH["root_fan"]
        dist = (60 + i * SH["root_gap"] + rnd(-10, 10)) * SH["root_len"]
        x = cx + math.sin(ang) * dist
        y = 760 - math.cos(ang) * dist * 0.42 + rnd(-12, 12)
        if not space_ok(x, y, 16):
            continue                        # занадто близько — пропустити
        nid = uid("r")
        add(nid, random.choice(["Жила роду", "Міць предка", "Криця"]), mk_desc(mk_stats(rg, 2)), x, y, "small", mk_stats(rg, 2), rg)
        root_ids[rg].append(nid)
    for i in range(len(root_ids[rg]) - 1):
        ln(root_ids[rg][i], root_ids[rg][i + 1])
# мости між віялами
_i3 = lambda ids: ids[min(3, len(ids) - 1)]
_i7 = lambda ids: ids[min(7, len(ids) - 1)]
ln(_i3(root_ids["str"]), root_ids["agi"][0]); ln(root_ids["agi"][0], _i3(root_ids["faith"]))
ln(_i7(root_ids["str"]), _i7(root_ids["faith"]))
print(f"1. Коріння: {len(_nodes)} вузлів")

# ══════════════════════════════════════════════════════════
# 2. СТОВБУР — 4 поздовжні пасми (y ≈ 200..560)
# ══════════════════════════════════════════════════════════
_w = SH["trunk_w"]
LANE_X  = [-_w, -_w / 3, _w / 3, _w]
LANE_RG = ["str", "agi", "faith", "agi"]
trunk_bot = []   # 1-й вузол кожної пасми (поруч з корінням)
trunk_top = []   # останній вузол кожної пасми (поруч з кроною)

for li, (lx, lr) in enumerate(zip(LANE_X, LANE_RG)):
    chain = []
    for step in range(SH["trunk_steps"]):
        y = 550 - step * SH["trunk_step"]
        x = lx + rnd(-12, 12) + (step / max(1, SH["trunk_steps"] - 1)) * SH["trunk_drift"]
        r = (lr if step < 12 else "agi")
        nid = uid("tr")
        add(nid, random.choice(["Жила роду", "Сплетіння"]), mk_desc(mk_stats(r, 2)), x, y, "small", mk_stats(r, 2), r)
        chain.append(nid)
        if step > 0:
            ln(chain[step - 1], nid)
    trunk_bot.append(chain[0])
    trunk_top.append(chain[-1])
# поперечні мости між пасмами: вузли кожної y-групи з'єднуємо ланцюжком
by_step = {}
for n in _nodes:
    if n["id"].endswith("_tr"):
        by_step.setdefault(round(n["y"] / SCALE / 25), []).append(n["id"])
for k, grp in by_step.items():
    grp.sort()
    for i in range(len(grp) - 1):
        if abs(_y_diff(grp[i], grp[i + 1])) < 200:
            ln(grp[i], grp[i + 1])
# з'єднати стовбур з корінням: кожен корінь → найближчий низовий вузол стовбура
for rg, cls in [("str", "druzhynnyk"), ("agi", "strilets"), ("faith", "volkhv")]:
    cx = CX[rg]
    tgt = nearest_to(cx, 470, id_filter=set(trunk_bot))
    if tgt:
        ln(root_ids[rg][-1], tgt)
print(f"2. Стовбур: {len(_nodes)} вузлів")

# ══════════════════════════════════════════════════════════
# 3. КРОНА — три гілки (y ≈ -1100..150)
# перехідний ланцюжок + дуга гілки; кожен шар явно з'єднаний
# ══════════════════════════════════════════════════════════
BRANCHES = [
    ("str",   -SH["branch_x"], -SH["branch_y"],                SH["branch_cnt"][0], "agi",
     SH["branch_r"] * rnd(0.85, 1.15)),
    ("agi",   0,               -SH["branch_y"] - rnd(40, 130), SH["branch_cnt"][1], "str",
     SH["branch_r"] * rnd(0.85, 1.15)),
    ("faith",  SH["branch_x"], -SH["branch_y"],                SH["branch_cnt"][2], "agi",
     SH["branch_r"] * rnd(0.85, 1.15)),
]
# останній параметр — регіон "перетину" (мікс), для відповідності 5-й вимозі
branch_nodes = {"str": [], "agi": [], "faith": []}

for rg, bx, by, cnt, mix, rscale in BRANCHES:
    # перехід: 6 вузлів від верхівки стовбура (y≈150) до основи гілки
    prev_id = trunk_top[{"str": 0, "agi": 1, "faith": 2}[rg]]
    for t in range(6):
        y = (550 - SH["trunk_h"]) - t * SH["trans_step"] - rnd(0, 12)
        x = bx * (t / 5) + rnd(-25, 25)
        if not space_ok(x, y, 16):
            continue
        nid = uid("tj")
        add(nid, random.choice(["Гілка", "Пагін"]), mk_desc(mk_stats(rg, 3)), x, y, "small", mk_stats(rg, 3), rg)
        ln(prev_id, nid)
        prev_id = nid
    # дуга гілки: від by вгору назовні
    arc = []
    for i in range(cnt):
        t = i / (cnt - 1) if cnt > 1 else 0
        ang = -math.pi / 2 + (t - 0.5) * (math.pi * SH["arc_span"])
        rad = (90 + t * 780) * rscale + rnd(-15, 15)
        x = bx + math.cos(ang) * rad * 1.25
        y = by + math.sin(ang) * rad * SH["branch_sq"] + rnd(-14, 14)
        x = max(-SH["xmax"], min(SH["xmax"], x)); y = max(-SH["ymax"], min(220, y))
        if not space_ok(x, y, 10):
            continue                        # не зливатися в купу на краях
        nid = uid("br")
        add(nid, random.choice(["Гілка", "Пагін", "Лист"]), mk_desc(mk_stats(rg, 3)), x, y, "small", mk_stats(rg, 3), rg)
        if arc:
            ln(arc[-1], nid)
        else:
            ln(prev_id, nid)
        arc.append(nid)
        branch_nodes[rg].append(nid)
    # кілька внутрішніх поперечок на гілці (тільки якщо достатньо вузлів)
    if len(arc) >= 4:
        for i in range(2, len(arc) - 3, 9):
            ln(arc[i], arc[i + 3])
    print(f"3. Гілка {rg}: {len(arc)} вузлів")
print(f"3. Крона: {len(_nodes)} вузлів")

# "стеблові" вузли — гарантовано досяжні (корені+стовбур+перехід+гілки)
stem_ids = {n["id"] for n in _nodes}

# ══════════════════════════════════════════════════════════
# 4. ГРОНА — notable + 7 малих кільцем; кожне гроно з'єднане з гілкою
# ══════════════════════════════════════════════════════════
FRUITS = [
    ("str",   -780,  -940, "Кривавий удар",  "kryvavyi_udar",  {"dmg_pct": 15, "hp_pct": 8}),
    ("str",   -560,  -720, "Залізна шкіра",   "zaliza_shkira",  {"armor": 20, "dr_pct": 5}),
    ("str",   -420, -1080, "Пробивач",        "probyvach",      {"pen_all_pct": 15, "dmg_pct": 10}),
    ("agi",    -70, -1120, "Тінь вовка",      "tin_vovka",      {"move_pct": 15, "dodge_pct": 10}),
    ("agi",    140,  -880, "Влучне око",      "vluchne_oko",    {"crit_pct": 12, "crit_dmg_pct": 20}),
    ("agi",    400, -1120, "Град стріл",      "hrad_stril",     {"proj_speed_pct": 20, "atk_speed_pct": 8}),
    ("faith",  540,  -880, "Оберіг",           "oberih",         {"hp_regen_pct": 12, "hp_pct": 8}),
    ("faith",  800, -1040, "Вогонь Сварога",  "vohon_svaroha",  {"dmg_pct": 12, "res_all_pct": 10}),
    ("faith",  430,  -700, "Тиша",            "tysha",          {"skill_cost_pct": -15, "cdr_pct": 15}),
    ("agi",     20,  -620, "Шлях учня",       "shliakh_uchnia", {"nauz_xp_pct": 20, "xp_pct": 15}),
]
fruit_ids = []
for rg, fx, fy, fname, flatin, fst in FRUITS:
    # зсув грона від базової точки: кожен seed дає свій малюнок крони
    fx += rnd(-SH["fruit_jitter"], SH["fruit_jitter"])
    fy += rnd(-SH["fruit_jitter"], SH["fruit_jitter"])
    fx = max(-SH["xmax"] * 0.85, min(SH["xmax"] * 0.85, fx))
    fy = max(-1350, min(-380, fy))
    # підібрати позицію центру, якщо занадто близько до існуючих вузлів
    for dx, dy in [(0, 0), (70, 0), (-70, 0), (0, 70), (0, -70), (50, 50), (-50, -50),
                   (110, 0), (-110, 0), (0, 110), (0, -110)]:
        if space_ok(fx + dx, fy + dy, 16):
            fx += dx; fy += dy
            break
    fnid = f"fruit_{flatin}"
    add(fnid, fname, f"Гроно «{fname}»: {mk_desc(fst)}", fx, fy, "notable", fst, rg)
    fruit_ids.append(fnid)
    rn = ri(6, 9)
    for k in range(rn):
        ang = k / rn * 2 * math.pi
        placed = False
        for rr0 in (88, 110, 70, 130):
            rr = rr0 * SH["ring_scale"]
            x = fx + math.cos(ang) * (rr + rnd(-8, 8))
            y = fy + math.sin(ang) * (rr + rnd(-8, 8))
            if space_ok(x, y, 16):
                nid = f"fr_{fnid}_{k}"
                add(nid, random.choice(["Листок", "Міцна гілка", "Плід"]), mk_desc(mk_stats(rg, 3)), x, y, "small", mk_stats(rg, 3), rg)
                ln(fnid, nid)
                placed = True
                break
        if not placed:
            continue
    # ЯВНИЙ зв'язок грона ↔ найближчий стебловий вузол (гарантія досяжності)
    near = nearest_to(fx, fy, id_filter=stem_ids)
    if near and near != fnid:
        ln(fnid, near)
print(f"4. Грона: {len(_nodes)} вузлів")

# ══════════════════════════════════════════════════════════
# 5. KEYSTONES + CORE (вершина); кожен з'єднаний з гронами/гілками
# ══════════════════════════════════════════════════════════
KEYSTONES = [
    ("Один шлях",       "str",   "odyn_shliakh",       {"dmg_pct": 25},         "Лише 1 науз; +25% шкоди, −50% до інших."),
    ("Кривава данина",  "str",   "kryvava_danyna",     {"lifesteal_pct": 3},   "Вбивство лікує 3% життя, −10% макс. життя."),
    ("Смертельна тінь", "agi",   "smertelna_tin",      {"crit_dmg_pct": 30},   "+30% шкоди зі спини; без щита."),
    ("Вільні вміння",   "faith", "vilni_vminnia",      {"cdr_pct": 30},        "−30% перезарядки, −20% чару."),
    ("Серце війни",     "str",   "sertse_vijny",       {"dmg_pct": 20},        "+20% шкоди, −15% броні."),
    ("Серце полювання", "agi",   "sertse_poliuvannia", {"crit_pct": 20},       "+20% криту, −10% життя."),
    ("Серце віри",      "faith", "sertse_viry",        {"dmg_pct": 20},        "+20% сили чару, −15% швидкості."),
    ("Гнів пращурів",   "agi",   "hniv_prawchuriv",    {"aoe_pct": 20},        "5-й удар — вибух, −10% швидкості атаки."),
]
k_ids = []
for i, (name, rg, latin, kst, kdsc) in enumerate(KEYSTONES):
    ang = i / len(KEYSTONES) * 2 * math.pi + SH["key_rot"]
    x = math.cos(ang) * SH["key_rx"] + rnd(-40, 40)
    y = SH["key_base"] - max(0, math.sin(ang)) * SH["key_ry"] + rnd(-30, 30)
    y = max(y, SH["core_y"] - rnd(60, 160))   # не вище серця
    kid = f"key_{latin}"
    add(kid, name, kdsc, x, y, "keystone", kst, rg)
    k_ids.append(kid)
    near = nearest_to(x, y, id_filter=stem_ids)   # зв'язок до досяжного стебла
    if near:
        ln(kid, near)

add("core", "Серце роду", "Тут сходяться всі три шляхи.",
    0, SH["core_y"], "core", {"str": 3, "agi": 3, "faith": 3, "dmg_pct": 8, "hp_pct": 5}, "agi")
for k in k_ids:
    ln(k, "core")
core_stem = nearest_to(0, SH["core_y"], id_filter=stem_ids)
if core_stem:
    ln("core", core_stem)
print(f"5. Вершина: {len(_nodes)} вузлів")

# ══════════════════════════════════════════════════════════
# 6. ЗАПОВНЕННЯ крони — лише до СТЕБЛОВИХ вузлів (гарантія досяжності)
# ══════════════════════════════════════════════════════════
stem_ids = {n["id"] for n in _nodes}
current = len(_nodes)
to_add = max(0, TARGET - current)
added = 0

attempts = 0
while added < to_add and attempts < 30000:
    attempts += 1
    rg = random.choice(["str", "agi", "faith"])
    ang = random.uniform(-math.pi * 0.84, -math.pi * 0.18)
    r = random.uniform(140, 800)
    x = math.cos(ang) * r * 1.5
    y = -math.sin(ang) * r * SH["fill_sy"] - SH["fill_cy"] - random.uniform(0, 260)
    if y > 60: continue                       # тільки крона/верх
    if abs(x / SH["fill_rx"])**2 + abs(y / SH["fill_ry"])**2 > 1.15: continue
    if not space_ok(x, y, 16): continue

    nid = uid("fill")
    add(nid, random.choice(["Гілка", "Листок", "Жила"]), mk_desc(mk_stats(rg, 3)), x, y, "small", mk_stats(rg, 3), rg)
    # єдиний зв'язок → найближчий стебловий вузол (гарантовано досяжний)
    near = nearest_to(x, y, id_filter=stem_ids)
    if near:
        ln(nid, near)
        added += 1
    else:
        # якщо поряд нема стебла — відкинути вузол
        _nodes.pop(); occupied.pop()
print(f"6. Заповнення: +{added} → {len(_nodes)} вузлів")

# ─── страховка: приєднати відірвані вузли (якщо геометрія зіграла зле) ──
def ensure_connected():
    pos = {n["id"]: (n["x"], n["y"]) for n in _nodes}
    ids = set(pos)
    adj = {i: [] for i in ids}
    for a, b in _links:
        if a in ids and b in ids:
            adj[a].append(b); adj[b].append(a)
    reach = set(); q = deque(s for s in CLASS_STARTS.values() if s in ids)
    while q:
        c = q.popleft()
        if c in reach: continue
        reach.add(c)
        for nb in adj[c]:
            q.append(nb)
    while len(reach) < len(ids):
        u, r, bd = None, None, None
        for cand in ids - reach:
            cu = pos[cand]
            for r2 in reach:
                cr = pos[r2]
                d = math.hypot(cu[0] - cr[0], cu[1] - cr[1])
                if bd is None or d < bd:
                    u, r, bd = cand, r2, d
        ln(u, r)
        adj[u].append(r); adj[r].append(u)
        q = deque([u])
        while q:
            c = q.popleft()
            if c in reach: continue
            reach.add(c)
            for nb in adj[c]:
                q.append(nb)

ensure_connected()

# ─── дедуплікація зв'язків ──────────────────────────────────
seen = set(); uniq = []
for a, b in _links:
    k = tuple(sorted([a, b]))
    if k not in seen:
        seen.add(k); uniq.append(list(k))
_links[:] = uniq

# ─── валідація: досяжність і степінь ──────────────────────
ids_s = {n["id"] for n in _nodes}
adj = {i: [] for i in ids_s}
for a, b in _links:
    if a in ids_s and b in ids_s:
        adj[a].append(b); adj[b].append(a)

starts_ok = [s for s in CLASS_STARTS.values() if s in ids_s]
reach = set(); q = deque(starts_ok)
while q:
    c = q.popleft()
    if c in reach: continue
    reach.add(c)
    for nb in adj.get(c, []):
        if nb not in reach: q.append(nb)
orphan = ids_s - reach
deg = [len(v) for v in adj.values()]

# мінімальна відстань у експортованих координатах
xs = [n["x"] for n in _nodes]; ys = [n["y"] for n in _nodes]
min_d = min(math.hypot(xs[i]-xs[j], ys[i]-ys[j])
            for i in range(len(_nodes)) for j in range(i+1, len(_nodes)) if i != j)

from collections import Counter
print("\n=== РЕЗУЛЬТАТ ===")
print(f"Вузлів: {len(_nodes)}, Зв'язків: {len(_links)}")
print(f"Досяжних: {len(reach)}, Сиріт: {len(orphan)}, середній степінь: {sum(deg)/max(1,len(deg)):.2f}, min відстань: {min_d:.0f}")
print(f"Типи: {dict(Counter(n['type'] for n in _nodes))}")
print(f"Регіони: {dict(Counter(n['region'] for n in _nodes))}")

tree = {
    "format": "spohady-perk-tree",
    "version": 4,
    "title": "Древо звитяги",
    "comment": "v5-розкладка у форматі v4: коріння→стовбур→крона→грона→вершина. Зв'язне за побудовою.",
    "regions": REGIONS,
    "class_starts": CLASS_STARTS,
    "nodes": _nodes,
    "links": _links,
}
out = "/root/projects/spohady/tools/tree-viewer/out/perk_tree_424242.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(tree, f, ensure_ascii=False, indent=2)
print(f"\n✓ Збережено → {out}")
