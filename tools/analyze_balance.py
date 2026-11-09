#!/usr/bin/env python3
"""
Script 3: Аналіз ваги параметрів і балансу заповнення дерева.
Перевіряє:
  - вага кожного типу бонусу (скільки "сили" дає очко)
  - розподіл по регіонах і висотах
  - баланс: чи не перекошений один регіон
  - чи рівномірно розподілені сильні вузли по висоті
  - чи немає "мертвих" зон або надто сильних ранніх кластерів
  - рекомендації де посилити/послабити
"""
import json, math, sys
from collections import defaultdict, Counter

# ─── завантаження ──────────────────────────────────────────────
if len(sys.argv) < 2:
    print("Використання: python3 analyze_balance.py <perk_tree.json>")
    sys.exit(1)

tree = json.load(open(sys.argv[1], encoding="utf-8"))
nodes = {n["id"]: n for n in tree["nodes"]}
links = tree["links"]
regions = {r["id"]: r["name"] for r in tree["regions"]}

# ─── градація висоти (y > 400 = коріння, 0..400 = стовбур, y < 0 = крона) ────
ATTR_MAP = {"str": "Сила", "agi": "Спритність", "faith": "Віра",
            "dmg_pct": "Шкода%", "hp_pct": "Життя%", "crit_pct": "Крит%",
            "dodge_pct": "Ухилення%", "armor": "Броня", "cdr_pct": "Відновл.%",
            "res_all_pct": "Опір%", "move_pct": "Рух%", "atk_speed_pct": "Швидк.атаки%",
            "lifesteal_pct": "Ліч%", "thorns_pct": "Шипи%", "block_pct": "Блок%",
            "dr_pct": "Захист%", "mana_pct": "Чар%", "mana_regen": "Реген чару",
            "heal_pct": "Лікування%", "effect_dur_pct": "Тривал.%", "proj_speed_pct": "Снаряд%",
            "nauz_xp_pct": "Наузи%", "skill_cost_pct": "Вартість%", "crit_dmg_pct": "Крит.шкода%",
            "pen_all_pct": "Пробиття%", "double_hit_pct": "Подвійн.удар%", "armor_pen_pct": "Пробиття броні%",
            "duration_pct": "Тривалість%", "aoe_pct": "Площа%", "hp": "Життя", "xp_pct": "Звитяга%",
            "drop_pct": "Здобич%"}
Y_ROOT  = 400   # все що вище (більше y) — коріння
Y_TRUNK = 0     # все що нижче (менше y) — крона/вершина

def tier(y):
    y = float(y)
    if y > Y_ROOT:  return "T1_коріння"
    if y > Y_TRUNK: return "T2_стовбур"
    if y > -800:    return "T3_нижня_крона"
    if y > -1500:   return "T4_верхня_крона"
    return "T5_вершина"

# ─── "сила" вузла: конвертація статів у умовні бали ─────────────
# Конвертаційна таблиця: кожен 1% = 1 одиниця, кожен 1 атрибут = 3 одиниці
STAT_POWER = {
    # атрибути — найцінніші
    "str": 3, "agi": 3, "faith": 3,
    # життєві
    "hp": 0.5, "hp_pct": 2,
    # шкода
    "dmg": 2, "dmg_pct": 2,
    "atk_speed_pct": 1.5, "crit_pct": 2, "crit_dmg_pct": 1.5,
    "armor_pen_pct": 1.5, "pen_all_pct": 1.5, "aoe_pct": 1.5,
    # захист
    "armor": 1.5, "dr_pct": 2, "block_pct": 2, "thorns_pct": 1.5,
    # ухилення
    "dodge_pct": 2, "move_pct": 1,
    # ресурс
    "mana_pct": 1.5, "mana_regen": 1.5, "cdr_pct": 2,
    # спеціальні
    "heal_pct": 1.5, "lifesteal_pct": 2, "res_all_pct": 1.5,
    "nauz_xp_pct": 1.5, "nauz_level": 3,
    "xp_pct": 2, "drop_pct": 2, "gold_pct": 2,
    # утиліти
    "proj_speed_pct": 1, "effect_dur_pct": 1, "duration_pct": 1,
    "skill_cost_pct": 1.5, "double_hit_pct": 1.5,
}

def node_power(nid):
    s = nodes[nid]["stats"]
    return sum(abs(float(v)) * STAT_POWER.get(str(k), 1.0) for k, v in s.items())

def node_points(nid):
    t = nodes[nid]["type"]
    return {"small": 1, "notable": 4, "keystone": 8, "core": 12, "start": 0}.get(t, 1)

def attr_sum(nid):
    return sum(nodes[nid]["stats"].get(a, 0) for a in ("str", "agi", "faith"))

# ─── аналіз по регіонах ─────────────────────────────────────────
print("=" * 70)
print("СКРИПТ 3: БАЛАНС ТА ВАГА ПАРАМЕТРІВ")
print("=" * 70)

# --- 1. Розподіл вузлів по регіонах та типах ---
print("\n── 1. Розподіл вузлів по регіонах ──")
reg_count = Counter()   # (лічильник заповнюється в циклі нижче)
reg_power = defaultdict(float)
reg_points = defaultdict(int)
reg_types  = defaultdict(Counter)

for n in nodes.values():
    r = n["region"]
    reg_count[r] += 1
    reg_power[r] += node_power(n["id"])
    reg_points[r] += node_points(n["id"])
    reg_types[r][n["type"]] += 1

total_nodes = len(nodes)
total_power = sum(reg_power.values())
total_pts   = sum(reg_points.values())

print(f"\n{'Регіон':<12} {'Вузлів':>6} {'%':>5} {'Сила':>8} {'%':>5} {'Очки':>6} {'Очок/node':>9}")
print("-" * 60)
for r in ["str", "agi", "faith"]:
    cnt = reg_count.get(r, 0)
    pwr = reg_power.get(r, 0)
    pts = reg_points.get(r, 0)
    print(f"{regions[r]:<12} {cnt:>6} {cnt*100/total_nodes:>5.1f} "
          f"{pwr:>8.1f} {pwr*100/max(1,total_power):>5.1f} "
          f"{pts:>6} {pts/max(1,cnt):>9.2f}")

print(f"\nВсього: {total_nodes} вузлів, сумарна сила={total_power:.0f}, очок={total_pts}")

# --- 2. Розподіл по типах ---
print("\n── 2. Розподіл по типах вузлів ──")
type_power = defaultdict(float)
type_pts   = defaultdict(int)
for n in nodes.values():
    t = n["type"]
    type_power[t] += node_power(n["id"])
    type_pts[t]   += node_points(n["id"])

for t in ["small", "notable", "keystone", "core", "start"]:
    cnt = sum(1 for n in nodes.values() if n["type"] == t)
    print(f"  {t:<8}: {cnt:>4} вузлів, сила={type_power.get(t,0):>6.1f}, очок={type_pts.get(t,0):>5}")

# --- 3. Баланс статів по регіонах ---
print("\n── 3. Середні стати по регіонах ──")
reg_attrs = defaultdict(lambda: defaultdict(float))
for n in nodes.values():
    r = n["region"]
    for k, v in n["stats"].items():
        if k in ("str", "agi", "faith"):
            reg_attrs[r][k] += float(v)

for r in ["str", "agi", "faith"]:
    attrs = reg_attrs[r]
    total_attrs = sum(attrs.values())
    print(f"  {regions[r]}: str={attrs['str']:.0f}  agi={attrs['agi']:.0f}  faith={attrs['faith']:.0f}  (сума={total_attrs:.0f})")

# --- 4. Аналіз по висоті (tier) ---
print("\n── 4. Розподіл по висоті (Tier) ──")
tier_nodes  = Counter()
tier_power  = defaultdict(float)
tier_notable = defaultdict(int)

for n in nodes.values():
    t = tier(n["y"])
    tier_nodes[t] += 1
    tier_power[t]  += node_power(n["id"])
    if n["type"] == "notable":
        tier_notable[t] += 1

for t in ["T1_коріння", "T2_стовбур", "T3_нижня_крона", "T4_верхня_крона", "T5_вершина"]:
    cnt = tier_nodes.get(t, 0)
    pwr = tier_power.get(t, 0)
    nt  = tier_notable.get(t, 0)
    print(f"  {t:<20}: {cnt:>4} вузлів, сила={pwr:>7.1f}, notable={nt}")

# --- 5. Чи немає "мертвих" зон? Перевірка досяжності ---
print("\n── 5. Перевірка мертвих зон ──")
from collections import deque
starts_list = list(tree["class_starts"].values())
adj_g = defaultdict(list)
for a, b in links:
    if a in nodes and b in nodes:
        adj_g[a].append(b); adj_g[b].append(a)

reach_all = set()
q = deque([s for s in starts_list if s in nodes])
while q:
    c = q.popleft()
    if c in reach_all: continue
    reach_all.add(c)
    for nb in adj_g[c]:
        if nb not in reach_all: q.append(nb)

orphan = [n["id"] for n in nodes.values() if n["id"] not in reach_all]
print(f"  Досяжних з стартів: {len(reach_all)}/{total_nodes} ({len(reach_all)*100//total_nodes}%)")
if orphan:
    print(f"  ⚠ МЕРТВІ вузли ({len(orphan)}): {orphan[:5]}...")
else:
    print("  ✓ Жодного мертвого вузла")

# --- 6. Чи сильні early-вузли не надто потужні? ---
print("\n── 6. Рання сила (T1+T2) vs пізня сила (T4+T5) ──")
early = sum(tier_power[t] for t in ["T1_коріння", "T2_стовбур"])
late  = sum(tier_power[t] for t in ["T4_верхня_крона", "T5_вершина"])
mid   = sum(tier_power[t] for t in ["T3_нижня_крона"])
total_p = sum(tier_power.values())
print(f"  Рання (T1+T2): {early:.0f} од. ({early*100/max(1,total_p):.1f}%)")
print(f"  Середня (T3): {mid:.0f} од. ({mid*100/max(1,total_p):.1f}%)")
print(f"  Пізня  (T4+T5): {late:.0f} од. ({late*100/max(1,total_p):.1f}%)")
if early > late:
    print(f"  ⚠ Рання сила переважає пізню — можливо надто легко взяти сильні бонуси")
elif late > early * 1.5:
    print(f"  ⚠ Пізня сила значно переважає — білд до пізніх шарів занадто слабкий")
else:
    print(f"  ✓ Співвідношення раннє/пізнє збалансоване")

# --- 7. Головні стати: який % дерева вони займають ---
print("\n── 7. Розподіл ключових статів ──")
stat_total = defaultdict(float)
stat_node_count = defaultdict(int)
for n in nodes.values():
    for k, v in n["stats"].items():
        stat_total[k] += abs(float(v))
        if abs(float(v)) > 0:
            stat_node_count[k] += 1

top_stats = sorted(stat_total.items(), key=lambda x: -x[1])[:15]
print(f"  {'Стат':<20} {'Сума':>8} {'Вузлів':>6} {'% вузлів':>8}")
for k, v in top_stats:
    nc = stat_node_count.get(k, 0)
    print(f"  {ATTR_MAP.get(k,k):<20} {v:>8.1f} {nc:>6} {nc*100/total_nodes:>7.1f}%")

# --- 8. Рекомендації ---
print("\n── 8. Рекомендації ──")
recommendations = []

# баланс регіонів
max_reg = max(reg_count.values())
min_reg = min(reg_count.values())
imbalance = max_reg - min_reg
if imbalance > total_nodes * 0.10:
    recommendations.append(f"⚠ Регіони розбалансовані: розмах={imbalance} вузлів. Рекомендація: додати вузлів у менший регіон.")
else:
    recommendations.append(f"✓ Регіони збалансовані (розмах={imbalance})")

# розподіл special nodes
keystone_count = sum(1 for n in nodes.values() if n["type"] == "keystone")
if keystone_count < 6:
    recommendations.append(f"⚠ Keystone вузлів замало ({keystone_count}). Рекомендація: додати 2-4 keystones у крону.")
else:
    recommendations.append(f"✓ Keystones: {keystone_count} — достатньо.")

# ранні потужні кластери
early_notables = sum(tier_notable[t] for t in ["T1_коріння", "T2_стовбур"])
if early_notables > 3:
    recommendations.append(f"⚠ Забагато notable у корінні/стовбурі ({early_notables}). Рекомендація: перенести їх у крону.")
else:
    recommendations.append(f"✓ Notable у корінні/стовбурі: {early_notables} — помірно.")

# мертві зони
if orphan:
    recommendations.append(f"⚠ {len(orphan)} мертвих вузлів. Рекомендація: перевірити зв'язки цих вузлів.")
else:
    recommendations.append("✓ Мертвих зон немає.")

for rec in recommendations:
    print(f"  {rec}")

print("\n✓ Аналіз балансу завершено")
