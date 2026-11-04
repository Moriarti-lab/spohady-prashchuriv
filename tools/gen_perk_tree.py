#!/usr/bin/env python3
"""Генератор Древа звитяги v2 (data/perk_tree.json, формат версії 2).

Це лише помічник розробника: гра читає готовий JSON. Після змін запускайте:
    python3 tools/gen_perk_tree.py            # записує data/perk_tree.json
    python3 tools/gen_perk_tree.py --plot X   # малює перегляд у PNG (потрібен PIL)
    python3 tools/sync_editor_tree.py         # копія для редактора

Будова області (повторюється тричі, кут 120°):
  * старт класу S -> три стартові навички (A, B, C) -> «артерії» углиб до серця;
  * на артеріях ще 5 навичок; біля кожної навички «кущ» із 7 поліпшень (шкода, розмах/дальність, відновлення/чар);
  * між артеріями — мости (дешевий міст лише глибоко, на старті — довгий шлях);
  * зв'язки між областями — лише глибоко (r < 700) і біля серця.
"""
import json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "perk_tree.json")

REGIONS = [
    {"id": "str", "name": "Сила", "color": "#D8574B", "angle": -90.0},
    {"id": "agi", "name": "Спритність", "color": "#7CBF5A", "angle": 30.0},
    {"id": "faith", "name": "Віра", "color": "#3FB9B3", "angle": 150.0},
]
PREFIX = {"str": "s", "agi": "a", "faith": "f"}
CLASS_STARTS = {"druzhynnyk": "s_t0", "strilets": "a_t0", "volkhv": "f_t0"}

R0 = 2000.0
RING = 125.0
ARTERY_PHI = {"A": -32.0, "B": 0.0, "C": 32.0}
LAST_RING = 13

STAT_TEXT = {
    "str": "%s Сили", "agi": "%s Спритності", "faith": "%s Віри",
    "hp": "%s до життя", "hp_pct": "%s%% до життя",
    "mana_pct": "%s%% до чару", "mana_regen": "%s до відновлення чару за секунду",
    "armor": "%s до броні", "dmg_pct": "%s%% до шкоди",
    "atk_speed_pct": "%s%% до швидкості атаки", "crit_pct": "%s%% до шансу крита",
    "move_pct": "%s%% до швидкості руху", "xp_pct": "%s%% до звитяги",
    "lifesteal_pct": "%s%% шкоди повертається життям", "thorns_pct": "%s%% отриманої шкоди вертається ворогові",
    "cdr_pct": "%s%% до швидкості відновлення навичок", "crit_dmg_pct": "%s%% до шкоди крита",
    "hp_regen_pct": "%s%% життя за секунду", "gold_pct": "%s%% до здобичі гривень",
    "drop_pct": "%s%% до шансу здобичі", "dr_pct": "%s%% менше отриманої шкоди",
}
STAT_ORDER = ["str", "agi", "faith", "hp", "hp_pct", "mana_pct", "mana_regen", "armor", "dmg_pct", "atk_speed_pct",
              "crit_pct", "crit_dmg_pct", "cdr_pct", "lifesteal_pct", "thorns_pct", "hp_regen_pct", "dr_pct",
              "move_pct", "gold_pct", "drop_pct", "xp_pct"]
MOD_TEXT = {
    "dmg_pct": "%s%% шкоди", "radius_pct": "%s%% радіуса", "range_pct": "%s%% дальності",
    "cd_pct": "%s%% часу відновлення", "mana_pct": "%s%% вартості Чару", "count": "%s до кількості",
    "duration_pct": "%s%% тривалості", "power_pct": "%s%% сили ефекту", "heal_pct": "%s%% лікування", "stun": "%s с приголомшення",
}


def fnum(v):
    v = round(float(v), 1)
    s = ("%d" % v) if v == int(v) else ("%.1f" % v).replace(".", ",")
    return s


def signed(v):
    return ("+" if v >= 0 else "−") + fnum(abs(v))


def stat_text(stats):
    out = []
    for k in STAT_ORDER:
        if k in stats and stats[k] != 0:
            out.append(STAT_TEXT[k] % signed(stats[k]))
    return ", ".join(out)


def mods_text(mods):
    return ", ".join(MOD_TEXT[k] % signed(v) for k, v in mods.items())


# ---------------- Навички (імена й опис без чисел — числа додає гра з Skills.describe) ----------------
SK = {
    "power_strike": ("Могутній удар", "Удар по землі навколо себе: шкодить усім довкола. Площа, невелика шкода.", "area"),
    "shield_bash": ("Удар щитом", "Потужний удар по одному ворогу з приголомшенням. Довге відновлення.", "strike"),
    "triple_slash": ("Потрійний розріз", "Швидка серія з трьох ударів по сектору. Дорожча за Чар.", "multi"),
    "whirlwind": ("Вихор лез", "Кружляєте з мечем: кілька ударів поспіль по всіх довкола.", "area"),
    "battle_cry": ("Бойовий клич", "Посилює шкоду та швидкість атаки на кілька секунд.", "buff"),
    "ground_slam": ("Удар об землю", "Важкий удар, що валить і приголомшує всіх поруч.", "area"),
    "chain_lightning": ("Перунів ланцюг", "Блискавка перескакує між ворогами.", "chain"),
    "iron_wall": ("Залізна стіна", "Тимчасово зменшує отриману шкоду й додає броню.", "buff"),
    "arrow_volley": ("Град стріл", "Віяло стріл по площі. Менша шкода, але багато цілей.", "volley"),
    "piercing_shot": ("Влучний постріл", "Одна потужна стріла, що пробиває ворогів наскрізь.", "pierce"),
    "rapid_shot": ("Швидкий приціл", "Три швидкі стріли поспіль. Дорожча за Чар.", "volley"),
    "arrow_rain": ("Злива стріл", "Стріли падають на ділянку, куди ви цілитесь.", "zone"),
    "poison_cloud": ("Отруйна хмара", "Хмара навколо вас: шкодить і сповільнює ворогів.", "zone"),
    "wolf_spirit": ("Дух вовка", "Швидкість руху, швидкість атаки та викрадання життя.", "buff"),
    "stribog_dash": ("Подих Стрибога", "Ривок уперед із поштовхом ворогів на шляху.", "dash"),
    "hunters_trap": ("Мисливська пастка", "Ставите пастку: за мить вона спрацьовує й надовго приголомшує.", "zone1"),
    "element_wave": ("Хвиля стихії", "Хвиля навколо вас: шкодить усім довкола. Площа.", "area"),
    "sun_beam": ("Сонячний промінь", "Далекий потужний промінь по одному ворогу.", "strike"),
    "ice_shards": ("Крижані уламки", "Три швидкі уламки, що сповільнюють ворогів.", "volley"),
    "ancestral_heal": ("Поклик пращурів", "Лікує вас частиною здоров'я.", "heal"),
    "fire_wave": ("Вогняний вал", "Два вогняні вали перед вами.", "multi"),
    "raven_swarm": ("Круки Мари", "Круки розлітаються на всі боки.", "volley"),
    "earth_spikes": ("Земляні списи", "Списи вриваються з землі в обраному місці й оглушують.", "zone"),
    "ancestral_ward": ("Оберіг пращурів", "Щит, що поглинає шкоду (росте з Віри).", "shield"),
    "ancestors_wrath": ("Гнів пращурів", "Кульмінація Древа: велетенський вибух навколо героя з приголомшенням.", "ultimate"),
}

# профілі поліпшень: три лінії -> (назва лінії, список mods по вузлах)
PROFILES = {
    "area": [("шкода", [{"dmg_pct": 12}, {"dmg_pct": 12}, {"dmg_pct": 20}]), ("розмах", [{"radius_pct": 10}, {"radius_pct": 14}]),
             ("темп", [{"cd_pct": -8}, {"mana_pct": -10}])],
    "strike": [("шкода", [{"dmg_pct": 15}, {"dmg_pct": 15}, {"dmg_pct": 25}]), ("хватка", [{"stun": 0.3}, {"range_pct": 15}]),
               ("темп", [{"cd_pct": -10}, {"mana_pct": -12}])],
    "multi": [("шкода", [{"dmg_pct": 10}, {"dmg_pct": 10}, {"dmg_pct": 18}]), ("серія", [{"count": 1}, {"range_pct": 12}]),
              ("темп", [{"cd_pct": -8}, {"mana_pct": -10}])],
    "volley": [("шкода", [{"dmg_pct": 10}, {"dmg_pct": 10}, {"dmg_pct": 18}]), ("залп", [{"count": 1}, {"count": 1}]),
               ("темп", [{"cd_pct": -8}, {"mana_pct": -10}])],
    "pierce": [("шкода", [{"dmg_pct": 15}, {"dmg_pct": 15}, {"dmg_pct": 30}]), ("приціл", [{"range_pct": 15}, {"cd_pct": -10}]),
               ("чар", [{"mana_pct": -12}, {"mana_pct": -12}])],
    "zone": [("шкода", [{"dmg_pct": 12}, {"dmg_pct": 12}, {"dmg_pct": 20}]), ("діяння", [{"radius_pct": 10}, {"duration_pct": 20}]),
             ("темп", [{"cd_pct": -8}, {"mana_pct": -10}])],
    "zone1": [("шкода", [{"dmg_pct": 15}, {"dmg_pct": 15}, {"dmg_pct": 25}]), ("діяння", [{"radius_pct": 12}, {"stun": 0.4}]),
              ("темп", [{"cd_pct": -10}, {"mana_pct": -12}])],
    "buff": [("сила", [{"power_pct": 12}, {"power_pct": 12}, {"power_pct": 20}]), ("тривалість", [{"duration_pct": 15}, {"duration_pct": 20}]),
             ("темп", [{"cd_pct": -8}, {"mana_pct": -10}])],
    "chain": [("шкода", [{"dmg_pct": 12}, {"dmg_pct": 12}, {"dmg_pct": 20}]), ("ланцюг", [{"count": 1}, {"range_pct": 15}]),
              ("темп", [{"cd_pct": -8}, {"mana_pct": -10}])],
    "heal": [("зцілення", [{"heal_pct": 15}, {"heal_pct": 15}, {"heal_pct": 25}]), ("темп", [{"cd_pct": -8}, {"cd_pct": -10}]),
             ("чар", [{"mana_pct": -10}, {"mana_pct": -12}])],
    "dash": [("розмах", [{"radius_pct": 10}, {"radius_pct": 12}, {"radius_pct": 18}]), ("темп", [{"cd_pct": -8}, {"cd_pct": -10}]),
             ("чар", [{"mana_pct": -10}, {"mana_pct": -12}])],
    "shield": [("міць", [{"power_pct": 12}, {"power_pct": 12}, {"power_pct": 20}]), ("тривалість", [{"duration_pct": 15}, {"duration_pct": 20}]),
               ("темп", [{"cd_pct": -8}, {"mana_pct": -10}])],
}
ROMAN = ["I", "II", "III"]

# навички на артеріях: (артерія, кільце, id)
LAYOUT = {
    "str": [("A", 1, "power_strike"), ("B", 1, "shield_bash"), ("C", 1, "triple_slash"),
            ("A", 4, "whirlwind"), ("C", 4, "battle_cry"), ("B", 6, "iron_wall"), ("A", 8, "ground_slam"), ("C", 8, "chain_lightning")],
    "agi": [("A", 1, "arrow_volley"), ("B", 1, "piercing_shot"), ("C", 1, "rapid_shot"),
            ("A", 4, "arrow_rain"), ("C", 4, "wolf_spirit"), ("B", 6, "hunters_trap"), ("A", 8, "poison_cloud"), ("C", 8, "stribog_dash")],
    "faith": [("A", 1, "element_wave"), ("B", 1, "sun_beam"), ("C", 1, "ice_shards"),
              ("A", 4, "fire_wave"), ("C", 4, "raven_swarm"), ("B", 6, "ancestral_ward"), ("A", 8, "earth_spikes"), ("C", 8, "ancestral_heal")],
}

# пули значень для звичайних вузлів: (назва, іконка, бонуси на кільці 1)
POOL = {
    "str": [("Дужі руки", "pa_strength", {"str": 2}), ("Тверда шкіра", "pa_stone_skin", {"armor": 6}), ("Міцне здоров'я", "pa_life", {"hp": 18}),
            ("Дубова міць", "pa_oak", {"hp_pct": 2, "str": 1}), ("Кривава жага", "pa_lifesteal", {"lifesteal_pct": 0.6}),
            ("Терновий вінець", "pa_thorns", {"thorns_pct": 4}), ("Живлюща лоза", "pa_regen", {"hp_regen_pct": 0.2}),
            ("Лють", "pa_strength", {"dmg_pct": 2}), ("Гарт", "pa_stone_skin", {"dr_pct": 1}),
            ("Витривалість", "pa_life", {"hp": 10, "armor": 3}), ("Бойовий запал", "pa_strength", {"str": 1, "dmg_pct": 1.5})],
    "agi": [("Легка хода", "pa_speed", {"move_pct": 2}), ("Влучне око", "pa_accuracy", {"crit_pct": 0.8}), ("Спритні пальці", "pa_speed", {"agi": 2}),
            ("Швидкий удар", "pa_speed", {"atk_speed_pct": 2}), ("Вдача мисливця", "pa_luck", {"gold_pct": 4, "drop_pct": 2}),
            ("Холодний розрахунок", "pa_crit", {"crit_dmg_pct": 6}), ("Вітер у спину", "pa_speed", {"move_pct": 1.5, "agi": 1}),
            ("Око яструба", "pa_accuracy", {"agi": 1, "crit_pct": 0.6}), ("Звіриний нюх", "pa_luck", {"drop_pct": 3}),
            ("Часолік", "pa_cooldown", {"cdr_pct": 1.5}), ("Гнучкість", "pa_oak", {"hp": 10, "agi": 1})],
    "faith": [("Тиха молитва", "pa_faith", {"faith": 2}), ("Джерело Мари", "pa_regen", {"mana_regen": 0.3}), ("Глибокий чар", "pa_faith", {"mana_pct": 3}),
              ("Перунова іскра", "pa_lightning", {"dmg_pct": 2}), ("Жар Сварога", "pa_fire", {"dmg_pct": 1.5, "crit_dmg_pct": 3}),
              ("Плин часу", "pa_cooldown", {"cdr_pct": 1.5}), ("Захист пращурів", "pa_stone_skin", {"armor": 4, "dr_pct": 0.8}),
              ("Мудрість", "pa_luck", {"xp_pct": 2}), ("Дух Дуба", "pa_oak", {"hp_pct": 2, "faith": 1}),
              ("Світло Дажбога", "pa_life", {"hp_regen_pct": 0.2, "hp": 8}), ("Сяйво", "pa_crown", {"faith": 1, "mana_regen": 0.2})],
}
# значущі вузли (notable) — по одному на кожне «зображення» на артерію: (назва, іконка, бонуси)
NOTABLES = {
    "str": [("Кузня предків", "pa_strength", {"str": 5, "armor": 12}), ("Шрами слави", "pa_life", {"hp": 60, "hp_regen_pct": 0.3}),
            ("Громовий кулак", "pa_lightning", {"dmg_pct": 7, "crit_dmg_pct": 10}), ("Кам'яна воля", "pa_stone_skin", {"dr_pct": 3, "armor": 18}),
            ("Дух поединку", "pa_thorns", {"thorns_pct": 12, "str": 3}), ("Кров воїна", "pa_lifesteal", {"lifesteal_pct": 2, "hp_pct": 4})],
    "agi": [("Лісова наука", "pa_oak", {"agi": 5, "hp": 40}), ("Подих лісу", "pa_speed", {"move_pct": 6, "atk_speed_pct": 4}),
            ("Тінь у хащі", "pa_crit", {"crit_pct": 3, "crit_dmg_pct": 14}), ("Рука без тремтіння", "pa_accuracy", {"crit_pct": 2.5, "agi": 3}),
            ("Багатий слід", "pa_luck", {"gold_pct": 10, "drop_pct": 6}), ("Час мисливця", "pa_cooldown", {"cdr_pct": 4, "atk_speed_pct": 3})],
    "faith": [("Мудрість предків", "pa_faith", {"faith": 5, "xp_pct": 4}), ("Священний вогонь", "pa_fire", {"dmg_pct": 6, "crit_dmg_pct": 10}),
              ("Ріка Чару", "pa_regen", {"mana_pct": 8, "mana_regen": 0.8}), ("Громова пісня", "pa_lightning", {"dmg_pct": 7, "cdr_pct": 3}),
              ("Світло в темряві", "pa_life", {"hp_regen_pct": 0.6, "hp_pct": 4}), ("Вінець волхва", "pa_crown", {"faith": 3, "cdr_pct": 4})],
}
KEYSTONES = {
    "str": [("Незламний", "pa_stone_skin", {"hp_pct": 18, "armor": 30, "move_pct": -5}, "Ціна: ви трохи повільніші."),
            ("Жага крові", "pa_lifesteal", {"lifesteal_pct": 5, "dmg_pct": 10, "hp_pct": -10}, "Ціна: менше життя.")],
    "agi": [("Мисливець", "pa_crit", {"crit_pct": 10, "crit_dmg_pct": 40, "hp_pct": -10}, "Ціна: менше життя."),
            ("Вітроходець", "pa_speed", {"move_pct": 15, "atk_speed_pct": 12, "armor": -15}, "Ціна: менше броні.")],
    "faith": [("Джерело Мари", "pa_regen", {"mana_pct": 30, "mana_regen": 1.5, "hp_pct": -8}, "Ціна: менше життя."),
              ("Потік часу", "pa_cooldown", {"cdr_pct": 14, "dmg_pct": 8, "armor": -10}, "Ціна: менше броні.")],
}
CENTRE_KEY = [("Кров пращурів", "perk_core", {"str": 6, "agi": 6, "faith": 6, "hp_pct": 8}),
              ("Дух роду", "perk_core", {"dmg_pct": 8, "crit_pct": 4, "cdr_pct": 6}),
              ("Воля роду", "perk_core", {"mana_pct": 12, "dr_pct": 4, "xp_pct": 8})]


def scaled(stats, ring, power=1.0):
    out = {}
    f = (1.0 + 0.11 * (ring - 1)) * power
    for k, v in stats.items():
        x = v * f
        if abs(v) >= 5 or k in ("hp", "armor", "str", "agi", "faith"):
            x = round(x)
            if x == 0:
                x = 1 if v > 0 else -1
        else:
            x = round(x, 1)
            if x == 0:
                x = 0.1 if v > 0 else -0.1
        out[k] = x
    return out


def polar(center_deg, r, phi_deg):
    th = math.radians(center_deg + phi_deg)
    return (r * math.cos(th), r * math.sin(th))


class Builder:
    def __init__(self):
        self.nodes = []
        self.links = []
        self.ids = {}

    def add(self, nid, name, desc, pos, typ, stats=None, skill="", icon="", region="", **extra):
        n = {"id": nid, "name": name, "description": desc, "x": int(round(pos[0])), "y": int(round(pos[1])), "type": typ,
             "stats": stats or {}, "skill": skill, "icon": icon, "region": region}
        for k, v in extra.items():
            n[k] = v
        self.nodes.append(n)
        self.ids[nid] = n
        return nid

    def link(self, a, b):
        assert a in self.ids and b in self.ids, (a, b)
        self.links.append([a, b])


def build():
    b = Builder()
    ring_r = [R0 - RING * k for k in range(LAST_RING + 1)]
    gates = {}
    frontier = {}
    kst = {}
    for reg in REGIONS:
        rid = reg["id"]
        p = PREFIX[rid]
        ang = reg["angle"]
        pool = POOL[rid]
        notes = list(NOTABLES[rid])
        keys = list(KEYSTONES[rid])
        # старт
        b.add(p + "_t0", {"str": "Міцні руки", "agi": "Влучне око", "faith": "Тиха молитва"}[rid],
              "Початок шляху класу. Звідси ведуть три стартові навички — оберіть одну на початку гри.",
              polar(ang, R0, 0), "start", {rid: 2}, icon="perk_region_" + rid, region=rid)
        b.ids[p + "_t0"]["description"] = "Початок шляху: " + stat_text({rid: 2}) + ". Звідси ведуть три стартові навички."
        hubs = {}  # (artery, ring) -> skill id
        for art, ring, sk in LAYOUT[rid]:
            hubs[(art, ring)] = sk
        artery_ids = {"A": [], "B": [], "C": []}
        pi = {"A": 0, "B": 4, "C": 8}   # зсув у пулі, щоб артерії відрізнялись
        note_i = {"A": 0, "B": 2, "C": 4}
        n_counter = 0
        for art in "ABC":
            phi = ARTERY_PHI[art]
            prev = p + "_t0"
            for k in range(1, LAST_RING + 1):
                # артерія злегка звужується до центру
                pphi = phi * (0.62 + 0.38 * min(1.0, (k - 1) / 3.0)) * (1.0 - 0.28 * (k / LAST_RING)) + (1.0 if k % 2 else -1.0) * (0.4 if art == 'B' else 1.0)
                pos = polar(ang, ring_r[k], pphi)
                nid = "%s_%s%d" % (p, art.lower(), k)
                if (art, k) in hubs:
                    sk = hubs[(art, k)]
                    name, blurb, prof = SK[sk]
                    starter = k == 1
                    d = "Відкриває навичку «%s»: %s" % (name, blurb)
                    if starter:
                        d = "Стартова навичка (одна з трьох на вибір, безкоштовно). " + d
                    extra = {}
                    if starter:
                        extra["starter"] = True
                    b.add(nid, name, d, pos, "skill", {}, skill=sk, icon="sk_" + sk, region=rid, **extra)
                    hubs[(art, k)] = (sk, nid, pos, pphi)
                else:
                    nt = (k % 4 == 3)
                    if k == 12 and art != "B":
                        nt = True
                    if nt:
                        nm, ic, base = notes[note_i[art] % len(notes)]
                        note_i[art] += 1
                        st = scaled(base, k, 1.0)
                        typ = "notable"
                    else:
                        nm, ic, base = pool[pi[art] % len(pool)]
                        pi[art] += 1
                        st = scaled(base, k)
                        typ = "small"
                    b.add(nid, nm, stat_text(st) + ".", pos, typ, st, icon=ic, region=rid)
                b.link(prev, nid)
                prev = nid
                artery_ids[art].append(nid)
        # стартові навички вже на кільці 1; артерії з'єднані зі стартом (prev = _t0 при k=1)
        # ключові вузли на артеріях A і C (кільце 10) — замінюємо звичайні
        for (art, k), kd in zip((("A", 10), ("C", 10)), keys):
            nid = "%s_%s%d" % (p, art.lower(), k)
            nm, ic, st, price = kd
            n = b.ids[nid]
            n.update({"name": nm, "type": "keystone", "stats": st, "icon": ic,
                      "description": stat_text(st) + ". " + price})
        # мости між артеріями
        def bridge(name, ring, a1, a2, tag):
            ph = (ARTERY_PHI[a1] + ARTERY_PHI[a2]) / 2 * (1.0 - 0.28 * ring / LAST_RING)
            nm, ic, base = pool[pi["B"] % len(pool)]
            pi["B"] += 1
            st = scaled(base, ring)
            nid = "%s_x%s" % (p, tag)
            b.add(nid, nm, stat_text(st) + ".", polar(ang, ring_r[ring] - 20, ph), "small", st, icon=ic, region=rid)
            b.link("%s_%s%d" % (p, a1.lower(), ring), nid)
            b.link(nid, "%s_%s%d" % (p, a2.lower(), ring))
        bridge("x1", 2, "A", "B", "1")
        bridge("x2", 2, "B", "C", "2")
        bridge("x3", 10, "A", "B", "3")
        bridge("x4", 11, "B", "C", "4")
        bridge("x5", 5, "B", "C", "5") if False else None
        # зовнішні сліди глибоко -> межі областей (єдині місця зв'язку між областями)
        fr = {}
        for side, art, sg in (("L", "A", -1), ("R", "C", 1)):
            prev = "%s_%s%d" % (p, art.lower(), 11)
            for ring, key, phi_f, dr_ in ((11, "M", sg * 40.0, 0), (11, "F", sg * 54.0, 0), (12, "F", sg * 53.0, -10)):
                nm_, ic, base = pool[pi["A"] % len(pool)]
                pi["A"] += 1
                st = scaled(base, ring, 1.1)
                nid = "%s_e%s%d%s" % (p, side.lower(), ring, key)
                b.add(nid, nm_, stat_text(st) + ".", polar(ang, ring_r[ring] + dr_, phi_f), "small", st, icon=ic, region=rid)
                b.link(prev, nid)
                prev = nid
                if key == "F":
                    fr[(side, ring)] = nid
        # відгалуження (необов'язкові відростки із сильним вузлом на кінці)
        for art, ring in (("A", 2), ("A", 6), ("C", 2), ("C", 6)):
            base_id = "%s_%s%d" % (p, art.lower(), ring)
            bn = b.ids[base_id]
            sdir = -1.0 if art == "A" else 1.0
            pphi_ = math.degrees(math.atan2(bn["y"], bn["x"])) - ang
            th = math.radians(ang + pphi_)
            tv = (-math.sin(th), math.cos(th))
            uv = (-math.cos(th), -math.sin(th))
            dx, dy = sdir * tv[0] + 0.3 * uv[0], sdir * tv[1] + 0.3 * uv[1]
            ln = math.hypot(dx, dy)
            dx, dy = dx / ln, dy / ln
            prev = base_id
            for si in range(2):
                pos2 = (bn["x"] + dx * 84.0 * (si + 1), bn["y"] + dy * 84.0 * (si + 1))
                if si == 1:
                    nm_, ic, base = notes[note_i["B"] % len(notes)]
                    note_i["B"] += 1
                    st = scaled(base, ring + 2, 1.0)
                    typ = "notable"
                else:
                    nm_, ic, base = pool[pi["B"] % len(pool)]
                    pi["B"] += 1
                    st = scaled(base, ring + 1)
                    typ = "small"
                nid = "%s_p%s%d%d" % (p, art.lower(), ring, si)
                b.add(nid, nm_, stat_text(st) + ".", pos2, typ, st, icon=ic, region=rid)
                b.link(prev, nid)
                prev = nid
        frontier[rid] = fr
        # ключовий вузол у серці області та ворота
        kp = polar(ang, 190.0, 0)
        nm, ic, base = CENTRE_KEY[REGIONS.index(reg)]
        st = scaled(base, 1, 1.0)
        kid = "%s_k" % p
        b.add(kid, nm, stat_text(st) + ".", kp, "keystone", st, icon="perk_region_" + rid, region="core")
        for art in "ABC":
            b.link("%s_%s%d" % (p, art.lower(), LAST_RING), kid)
        kst[rid] = kid
        # кущі поліпшень
        for (art, ring), h in hubs.items():
            sk, nid, pos, pphi = h
            name, blurb, prof = SK[sk]
            sd = {"A": -1.0, "B": 1.0, "C": 1.0}[art]
            th = math.radians(ang + pphi)
            tvec = (-math.sin(th), math.cos(th))   # у бік зростання кута
            uvec = (-math.cos(th), -math.sin(th))  # досередини
            dirs = [(sd, -0.6), (-sd, -0.2), (sd, 0.3)]
            if rid == "faith":
                pass
            lines = PROFILES[prof]
            for li, (lname, steps) in enumerate(lines):
                a, c = dirs[li]
                dx = a * tvec[0] + c * uvec[0]
                dy = a * tvec[1] + c * uvec[1]
                ln = math.hypot(dx, dy)
                dx, dy = dx / ln, dy / ln
                prev = nid
                for si, mods in enumerate(steps):
                    pos2 = (pos[0] + dx * 82.0 * (si + 1), pos[1] + dy * 82.0 * (si + 1))
                    uid = "%s_u%d%d" % (nid, li, si)
                    last = si == len(steps) - 1 and len(steps) == 3
                    label = "%s · %s %s" % (name, lname, ROMAN[si] if len(steps) > 1 else "")
                    label = label.strip()
                    b.add(uid, label, "%s: %s." % (name, mods_text(mods)), pos2, "notable" if last else "small",
                          {}, icon="", region=rid, mod_skill=sk, mods=mods)
                    b.link(prev, uid)
                    prev = uid
    # зв'язки між областями — лише глибоко
    order = [r["id"] for r in REGIONS]
    for i, rid in enumerate(order):
        nxt = order[(i + 1) % 3]
        # права сторона цієї області (R) біля лівої (L) наступної (кути: +54 і -54 після повороту на 120°)
        for ring in (11, 12):
            b.link(frontier[rid][("R", ring)], frontier[nxt][("L", ring)])
        # біля серця: ключові вузли з'єднані через «вузол кута»
        jp = polar(REGIONS[i]["angle"] + 60.0, 215.0, 0)
        jid = "j_%d" % i
        st = {"str": 1, "agi": 1, "faith": 1}
        b.add(jid, "Перехрестя роду", stat_text(st) + ".", jp, "small", st, icon="pa_crown", region="core")
        b.link(kst[rid], jid)
        b.link(jid, kst[nxt])
    # серце
    core_stats = {"str": 12, "agi": 12, "faith": 12, "dmg_pct": 15, "crit_pct": 5, "cdr_pct": 8, "hp_pct": 10}
    b.add("core", "Серце роду", "Тут сходяться Сила, Спритність і Віра. " + stat_text(core_stats) +
          ". Відкриває кульмінаційну навичку «Гнів пращурів»: велетенський вибух навколо героя.",
          (0, 0), "core", core_stats, skill="ancestors_wrath", icon="sk_ancestors_wrath", region="core")
    for rid in order:
        b.link("core", kst[rid])
    return b


def main():
    b = build()
    data = {
        "format": "spohady-perk-tree", "version": 2, "title": "Древо звитяги",
        "comment": "Формат описано в docs/perk_tree_format.md. Координати x, y: у «умовних пікселях», центр (0, 0).",
        "regions": REGIONS, "class_starts": CLASS_STARTS, "nodes": b.nodes, "links": b.links,
    }
    # однакова послідовність ключів вузла (як у normalizeNode редактора)
    order = ["id", "name", "description", "x", "y", "type", "stats", "skill", "icon", "region", "starter", "mod_skill", "mods"]
    nodes = []
    for n in b.nodes:
        o = {k: n[k] for k in order if k in n}
        nodes.append(o)
    data["nodes"] = nodes
    # перевірка відстаней
    pts = [(n["id"], n["x"], n["y"]) for n in nodes]
    bad = 0
    for i in range(len(pts)):
        for j in range(i + 1, len(pts)):
            d = math.hypot(pts[i][1] - pts[j][1], pts[i][2] - pts[j][2])
            if d < 60:
                bad += 1
                print("близько (%.0f): %s %s" % (d, pts[i][0], pts[j][0]))
    if "--plot" in sys.argv:
        plot(data, sys.argv[sys.argv.index("--plot") + 1])
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    types = {}
    for n in nodes:
        types[n["type"]] = types.get(n["type"], 0) + 1
    print("вузлів %d, зв'язків %d, типи %s, колізій %d" % (len(nodes), len(b.links), types, bad))


def plot(data, path):
    from PIL import Image, ImageDraw
    S = 0.45
    W = 2400
    im = Image.new("RGB", (W, W), (18, 14, 15))
    dr = ImageDraw.Draw(im)
    pos = {n["id"]: (W / 2 + n["x"] * S * 1.0, W / 2 + n["y"] * S * 1.0) for n in data["nodes"]}
    for a, c in data["links"]:
        dr.line([pos[a], pos[c]], fill=(90, 90, 90), width=2)
    col = {"str": (216, 87, 75), "agi": (124, 191, 90), "faith": (63, 185, 179), "core": (240, 200, 90)}
    rad = {"small": 5, "notable": 8, "keystone": 12, "skill": 11, "start": 12, "core": 16}
    for n in data["nodes"]:
        x, y = pos[n["id"]]
        r = rad[n["type"]]
        c = col[n["region"]]
        if n.get("mod_skill"):
            c = tuple(int(v * 0.6) for v in c)
        dr.ellipse([x - r, y - r, x + r, y + r], fill=c, outline=(255, 255, 255) if n["type"] in ("skill", "keystone", "core") else None)
    im.save(path)


if __name__ == "__main__":
    main()
