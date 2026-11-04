#!/usr/bin/env python3
"""Збирає data/icons.json: icon_id -> {path, label, color}. Якщо файлу ще немає, path = "" (гра покаже заглушку).
Щоб додати арт: поклади PNG у art/icons/<папка>/<icon_id>.png і запусти цей скрипт (або впиши path вручну)."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = ["weapons", "armor", "items", "skills", "passives", "perks", "extra"]

# id: (підпис заглушки, колір, [псевдонім-файл]) ; псевдонім — шлях відносно art/icons
E = {}
def add(i, label, color, alias=None):
    E[i] = (label, color, alias)

# зброя
for i, l in [("w_sword", "Меч"), ("w_greatsword", "Дв.меч"), ("w_axe", "Сокира"), ("w_greataxe", "Дв.сокира"),
             ("w_mace", "Булава"), ("w_hammer", "Молот"), ("w_spear", "Спис"), ("w_dagger", "Кинджал"),
             ("w_bow", "Лук"), ("w_longbow", "Дв.лук"), ("w_crossbow", "Арбалет"), ("w_staff", "Кий"),
             ("w_magic_staff", "Посох"), ("w_wand", "Жезл")]:
    add(i, l, "#9AA3AD")
for i, l in [("sh_round", "Щит"), ("sh_kite", "Щит"), ("sh_sun", "Щит")]:
    add(i, l, "#8B6B45")
# броня й прикраси
for i, l in [("h_leather", "Шапка"), ("h_iron", "Шолом"), ("h_ornate", "Шолом"), ("g_leather", "Рукав."), ("g_chain", "Рукав."),
             ("b_gambeson", "Каптан"), ("b_mail", "Кольч."), ("b_lamellar", "Лати"), ("b_robe", "Балахон"),
             ("f_leather", "Чоботи"), ("f_iron", "Чоботи"), ("r_silver", "Перст."), ("r_ruby", "Перст."), ("r_emerald", "Перст."),
             ("a_sun", "Оберіг"), ("a_wolf", "Ікло"), ("a_crystal", "Оберіг")]:
    add(i, l, "#7A8794")
# речі
for i, l, a in [("potion_hp", "Зілля", "items/potion_hp_small.png"), ("potion_mana", "Зілля", "items/potion_mana_small.png"),
                ("potion_hp_small", "Зілля", None), ("potion_hp_big", "Зілля", None), ("potion_mana_small", "Зілля", None),
                ("potion_mana_big", "Зілля", None), ("coins", "Гривні", None), ("pouch", "Калита", None),
                ("herb", "Трави", None), ("fern_flower", "Квітка", None), ("mushroom", "Гриб", None), ("rusty_key", "Ключ", None),
                ("letter", "Лист", None), ("idol", "Оберіг", None), ("rushnyk", "Рушник", None), ("jug", "Глек", None),
                ("wolf_pelt", "Шкура", None), ("bone_talisman", "Талісман", None)]:
    add(i, l, "#B88A4A", a)
# активні навички
sk = {"sk_power_strike": "Удар", "sk_shield_bash": "Щит", "sk_triple_slash": "Різ", "sk_whirlwind": "Вихор", "sk_battle_cry": "Клич",
      "sk_ground_slam": "Поштовх", "sk_chain_lightning": "Блискавка", "sk_iron_wall": "Стіна", "sk_arrow_volley": "Стріли",
      "sk_piercing_shot": "Постріл", "sk_rapid_shot": "Швидка", "sk_arrow_rain": "Злива", "sk_poison_cloud": "Отрута",
      "sk_wolf_spirit": "Вовк", "sk_stribog_dash": "Ривок", "sk_hunters_trap": "Пастка", "sk_element_wave": "Хвиля",
      "sk_sun_beam": "Промінь", "sk_ice_shards": "Крига", "sk_ancestral_heal": "Поклик", "sk_fire_wave": "Вогонь",
      "sk_raven_swarm": "Круки", "sk_earth_spikes": "Списи", "sk_ancestral_ward": "Захист", "sk_ancestors_wrath": "Гнів"}
for i, l in sk.items():
    add(i, l, "#C8753A")
for g in ["perun", "veles", "dazhbog", "mokosh", "svarog"]:
    add("sk_element_wave_" + g, "Хвиля", "#3FB9B3")
# alias для навичок зі старими іменами файлів
ALIASES = {"sk_power_strike": "skills/power_strike.png", "sk_arrow_volley": "skills/arrow_volley.png",
           "sk_stribog_dash": "skills/stribog_dash.png", "sk_element_wave": "skills/element_wave_perun.png",
           "sk_ancestors_wrath": "passives/pa_crown.png"}
for g in ["perun", "veles", "dazhbog", "mokosh", "svarog"]:
    ALIASES["sk_element_wave_" + g] = "skills/element_wave_%s.png" % g
# пасивки
for i, l in [("pa_strength", "Сила"), ("pa_life", "Життя"), ("pa_faith", "Віра"), ("pa_speed", "Вітер"), ("pa_stone_skin", "Шкіра"),
             ("pa_crit", "Крит"), ("pa_accuracy", "Око"), ("pa_cooldown", "Час"), ("pa_regen", "Лоза"), ("pa_lifesteal", "Кров"),
             ("pa_thorns", "Терен"), ("pa_luck", "Статок"), ("pa_oak", "Дуб"), ("pa_lightning", "Грім"), ("pa_fire", "Жар"),
             ("pa_crown", "Корона")]:
    add(i, l, "#8A6FB0")
# перки (вже були)
for i, l, a in [("perk_region_str", "Сила", "perks/region_str.png"), ("perk_region_agi", "Сприт.", "perks/region_agi.png"),
                ("perk_region_faith", "Віра", "perks/region_faith.png"), ("perk_core", "Серце", "perks/core.png")]:
    add(i, l, "#D8A74B", a)


def main():
    out = {}
    for i, (label, color, alias) in E.items():
        alias = alias or ALIASES.get(i)
        path = ""
        if alias and os.path.exists(os.path.join(ROOT, "art", "icons", alias)):
            path = "res://art/icons/" + alias
        else:
            for d in DIRS:
                if os.path.exists(os.path.join(ROOT, "art", "icons", d, i + ".png")):
                    path = "res://art/icons/%s/%s.png" % (d, i)
                    break
        out[i] = {"path": path, "label": label, "color": color}
    doc = {"format": "spohady-icons", "version": 1,
           "comment": "icon_id -> малюнок. path порожній = арту ще немає (гра малює заглушку з підписом). Формат: docs/icons.md",
           "icons": out}
    with open(os.path.join(ROOT, "data", "icons.json"), "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    miss = [i for i, e in out.items() if not e["path"]]
    print(len(out), "іконок; чекають на арт:", ", ".join(miss))


main()
