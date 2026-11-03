#!/usr/bin/env python3
"""Генератор стартового Древа звитяги (data/perk_tree.json).

Це лише помічник розробника: гра читає готовий JSON. Після змін запускайте:
    python3 tools/gen_perk_tree.py
Редактор дерева (tools/tree-editor/index.html) отримує копію цього JSON командою
    python3 tools/sync_editor_tree.py
"""
import json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

REGIONS = [
    {"id": "str", "name": "Сила", "color": "#D8574B", "angle": -90.0},
    {"id": "agi", "name": "Спритність", "color": "#7CBF5A", "angle": 30.0},
    {"id": "faith", "name": "Віра", "color": "#3FB9B3", "angle": 150.0},
]
PREFIX = {"str": "s", "agi": "a", "faith": "f"}
CLASS_STARTS = {"druzhynnyk": "s_t0", "strilets": "a_t0", "volkhv": "f_t0"}
OTHER = {"str": ["agi", "faith"], "agi": ["faith", "str"], "faith": ["str", "agi"]}

# шаблон області в локальних координатах (u — від центру назовні, v — вбік)
# ключ: (u, v)
TEMPLATE = {
    "t0": (1100, 0), "t1": (990, 0), "t2": (880, 0), "t3": (770, 0), "t4": (660, 0),
    "t5": (550, 0), "t6": (440, 0), "t7": (330, 0), "t8": (220, 0),
    "a1": (960, -125), "a2": (900, -240), "a3": (800, -330),
    "b1": (960, 125), "b2": (900, 240), "b3": (800, 330),
    "c1": (650, -135), "c2": (570, -250), "c3": (460, -330),
    "d1": (650, 135), "d2": (570, 250), "d3": (460, 330),
    "e1": (410, -130), "e2": (310, -215),
    "f1": (410, 130), "f2": (310, 215),
    "g1": (770, -130), "g2": (770, 130),
}
LINKS = [
    ("t0", "t1"), ("t1", "t2"), ("t2", "t3"), ("t3", "t4"), ("t4", "t5"), ("t5", "t6"), ("t6", "t7"), ("t7", "t8"),
    ("t1", "a1"), ("a1", "a2"), ("a2", "a3"),
    ("t1", "b1"), ("b1", "b2"), ("b2", "b3"),
    ("t4", "c1"), ("c1", "c2"), ("c2", "c3"),
    ("t4", "d1"), ("d1", "d2"), ("d2", "d3"),
    ("t6", "e1"), ("e1", "e2"), ("t6", "f1"), ("f1", "f2"),
    ("t3", "g1"), ("t3", "g2"),
]

NAMES = {
    "str": {
        "t0": "Міцні руки", "t1": "Дружинна наука", "t2": "Широкі плечі", "t3": "Серце дружини",
        "t4": "Загартована шкіра", "t5": "Залізний хват", "t6": "Кузня предків", "t7": "Гнів Перуна",
        "t8": "Кам'яна воля", "a1": "Зводи меча", "a2": "Бойовий клич", "a3": "Могутній удар",
        "b1": "Вага сокири", "b2": "Дух поединку", "b3": "Вихор лез", "c1": "Щитова стіна",
        "c2": "Кольчужне плетіння", "c3": "Незламний", "d1": "Лютий порив", "d2": "Кров воїна",
        "d3": "Громовий кулак", "e1": "Біг у кольчузі", "e2": "Витримка", "f1": "Гарт у вогні",
        "f2": "Шрами слави", "g1": "Міцні ноги", "g2": "Тверда хода",
    },
    "agi": {
        "t0": "Влучне око", "t1": "Легка рука", "t2": "Тиха хода", "t3": "Серце мисливця",
        "t4": "Гостре зір", "t5": "Рука без тремтіння", "t6": "Лісова наука", "t7": "Подих Стрибога",
        "t8": "Вітер у спину", "a1": "Натяг тятиви", "a2": "Швидкі пальці", "a3": "Град стріл",
        "b1": "Стежка звіра", "b2": "Мить прицілу", "b3": "Влучний постріл", "c1": "Пір'я на стрілі",
        "c2": "Холодна кров", "c3": "Око яструба", "d1": "Біг по росі", "d2": "Тінь у хащі",
        "d3": "Стрибок вовка", "e1": "Нюх мисливця", "e2": "Гнучкість", "f1": "Сагайдак повний",
        "f2": "Швидка тятива", "g1": "Легка хода", "g2": "Спритні ноги",
    },
    "faith": {
        "t0": "Щире слово", "t1": "Тиха молитва", "t2": "Вогонь капища", "t3": "Серце волхва",
        "t4": "Пам'ять роду", "t5": "Глибока криниця", "t6": "Шепіт пращурів", "t7": "Мокошева нитка",
        "t8": "Вічне джерело", "a1": "Обряд світанку", "a2": "Сила оберегу", "a3": "Хвиля стихії",
        "b1": "Теплий вогонь", "b2": "Дар Дажбога", "b3": "Поклик пращурів", "c1": "Вишиті слова",
        "c2": "Чистий дух", "c3": "Голос богів", "d1": "Хвиля чару", "d2": "Тиха сила",
        "d3": "Світло Дажбога", "e1": "Берегиня", "e2": "Ясна думка", "f1": "Тепло домівки",
        "f2": "Благословення роду", "g1": "Вітер чарів", "g2": "Легка молитва",
    },
}

# бонуси за ролями. P — головна характеристика області
def stats_for(region, key):
    P = region
    O1, O2 = OTHER[region]
    s = {
        "t0": {P: 2},
        "t1": {P: 2},
        "t2": {P: 2, "hp_pct": 2},
        "t3": {P: 4, "hp_pct": 5},
        "t4": {P: 2, O1: 1},
        "t5": {P: 3},
        "t6": {P: 4, "dmg_pct": 4},
        "t7": {P: 3, O2: 1},
        "t8": None,  # ключовий вузол: нижче
        "a1": {P: 1, "armor": 6} if region == "str" else {P: 1, "crit_pct": 1},
        "a2": {P: 2},
        "b1": {P: 1, "move_pct": 2},
        "b2": {P: 2},
        "c1": {"armor": 12, "hp_pct": 2},
        "c2": {P: 2, "armor": 8},
        "c3": {P: 4, "hp_pct": 6, "armor": 12},
        "d1": {P: 1, "atk_speed_pct": 3},
        "d2": {"hp_pct": 4, P: 1},
        "d3": {P: 4, "dmg_pct": 6},
        "e1": {O1: 2},
        "e2": {P: 2, O1: 1},
        "f1": {O2: 2},
        "f2": {P: 2, O2: 1},
        "g1": {"hp_pct": 3},
        "g2": {"move_pct": 3},
    }[key] if key not in ("a3", "b3") else {P: 3}
    if region == "agi":
        s = dict(s) if s else s
    return s

KEYSTONES = {
    "str": {"hp_pct": 25, "armor": 40, "move_pct": -8},
    "agi": {"move_pct": 15, "atk_speed_pct": 12, "hp_pct": -10},
    "faith": {"mana_pct": 40, "mana_regen": 2, "hp_pct": -10},
}
KEYSTONE_DESC = {
    "str": "Ти стоїш, як дуб. Повільніше, але міцніше.",
    "agi": "Легкий, як вітер, але крихкий.",
    "faith": "Чарівна криниця без дна, а тіло тендітне.",
}
SKILLS = {
    "str": {"a3": "power_strike", "b3": "whirlwind"},
    "agi": {"a3": "arrow_volley", "b3": "piercing_shot"},
    "faith": {"a3": "element_wave", "b3": "ancestral_heal"},
}
NOTABLE = {"t3", "t6", "c3", "d3"}
DESC = {
    "t0": "Початок шляху.", "t3": "Перший великий вузол шляху.", "t6": "Знання, що передаються з роду в рід.",
}


def rot(b_deg, u, v):
    a = math.radians(b_deg)
    return (u * math.cos(a) - v * math.sin(a), u * math.sin(a) + v * math.cos(a))


def main():
    nodes = []
    links = []
    pos = {}
    for reg in REGIONS:
        rid = reg["id"]
        pfx = PREFIX[rid]
        for key, (u, v) in TEMPLATE.items():
            nid = f"{pfx}_{key}"
            x, y = rot(reg["angle"], u, v)
            pos[nid] = (x, y)
            st = stats_for(rid, key)
            typ = "small"
            skill = ""
            if key == "t0":
                typ = "start"
            elif key == "t8":
                typ = "keystone"
                st = KEYSTONES[rid]
            elif key in SKILLS[rid]:
                typ = "skill"
                skill = SKILLS[rid][key]
            elif key in NOTABLE:
                typ = "notable"
            node = {
                "id": nid, "name": NAMES[rid][key],
                "description": KEYSTONE_DESC[rid] if key == "t8" else DESC.get(key, ""),
                "x": round(x), "y": round(y), "type": typ,
                "stats": dict(st), "skill": skill, "icon": "", "region": rid,
            }
            nodes.append(node)
        for a, b in LINKS:
            links.append([f"{pfx}_{a}", f"{pfx}_{b}"])
        links.append([f"{pfx}_t8", "core"])
    nodes.append({
        "id": "core", "name": "Серце роду",
        "description": "Тут сходяться всі три шляхи: Сила, Спритність і Віра.",
        "x": 0, "y": 0, "type": "core",
        "stats": {"str": 3, "agi": 3, "faith": 3, "dmg_pct": 8}, "skill": "", "icon": "", "region": "core",
    })
    # мости між областями: від d3 однієї до c3 наступної, гібридні вузли
    bridge_names = [
        ["Воїн і лучник", "Погляд і удар", "Кров і вітер", "Влучна сила"],
        ["Подих лісу", "Шепіт і стріла", "Лісова стежка", "Тихий лук"],
        ["Оберіг-щит", "Вогонь чаклуна", "Віра і сталь", "Дух дружини"],
    ]
    pairs = [("str", "agi"), ("agi", "faith"), ("faith", "str")]
    for i, (ra, rb) in enumerate(pairs):
        a = f"{PREFIX[ra]}_d3"
        b = f"{PREFIX[rb]}_c3"
        (ax, ay), (bx, by) = pos[a], pos[b]
        dist = math.hypot(bx - ax, by - ay)
        n = max(2, round(dist / 120.0) - 1)
        n = min(n, len(bridge_names[i]))
        chain = [a]
        for k in range(1, n + 1):
            t = k / (n + 1)
            x, y = ax + (bx - ax) * t, ay + (by - ay) * t
            nid = f"x_{PREFIX[ra]}{PREFIX[rb]}_{k}"
            sa = ra if k <= (n + 1) / 2 else rb
            ob = rb if sa == ra else ra
            st = {sa: 2, ob: 1} if k % 2 else {sa: 1, ob: 1, "crit_pct": 1} if k == 2 else {sa: 2, ob: 2}
            if k == (n + 1) // 2 + 0 and n >= 3:
                pass
            nodes.append({
                "id": nid, "name": bridge_names[i][k - 1], "description": "", "x": round(x), "y": round(y),
                "type": "small", "stats": st, "skill": "", "icon": "", "region": "mixed",
            })
            pos[nid] = (x, y)
            chain.append(nid)
        chain.append(b)
        for p, q in zip(chain, chain[1:]):
            links.append([p, q])
    # мінімальна відстань між вузлами
    ids = [n["id"] for n in nodes]
    bad = []
    for i in range(len(nodes)):
        for j in range(i + 1, len(nodes)):
            d = math.hypot(nodes[i]["x"] - nodes[j]["x"], nodes[i]["y"] - nodes[j]["y"])
            if d < 85:
                bad.append((nodes[i]["id"], nodes[j]["id"], round(d)))
    if bad:
        print("УВАГА, вузли надто близько:", bad, file=sys.stderr)
    data = {
        "format": "spohady-perk-tree",
        "version": 1,
        "title": "Древо звитяги (стартове)",
        "comment": "Формат описано в docs/perk_tree_format.md. Координати x, y: у «умовних пікселях», центр (0, 0).",
        "regions": [{"id": r["id"], "name": r["name"], "color": r["color"], "angle": r["angle"]} for r in REGIONS],
        "class_starts": CLASS_STARTS,
        "nodes": nodes,
        "links": links,
    }
    out = os.path.join(ROOT, "data", "perk_tree.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("вузлів:", len(nodes), "зв'язків:", len(links), "->", out)


if __name__ == "__main__":
    main()
