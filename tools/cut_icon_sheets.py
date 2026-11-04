#!/usr/bin/env python3
"""Нарізає аркуші іконок (art/sheets/*.jpg, сітка 4x4) на окремі PNG у art/icons/<група>/<icon_id>.png.
Запуск: python3 tools/cut_icon_sheets.py   (з кореня проєкту)"""
import os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = 192
INSET = 9

SHEETS = {
    "weapons": ("sheet_weapons_v1.jpg", "weapons", [
        "w_sword", "w_greatsword", "w_axe", "w_greataxe",
        "w_mace", "w_hammer", "w_spear", "w_dagger",
        "w_bow", "w_longbow", "w_crossbow", "w_staff",
        "w_magic_staff", "sh_round", "sh_kite", "sh_sun"]),
    "armor": ("sheet_armor_v1.jpg", "armor", [
        "h_leather", "h_iron", "h_ornate", "g_leather",
        "g_chain", "b_gambeson", "b_mail", "b_lamellar",
        "f_leather", "f_iron", "r_silver", "r_ruby",
        "r_emerald", "a_sun", "a_wolf", "a_crystal"]),
    "items": ("sheet_items_v1.jpg", "items", [
        "potion_hp_small", "potion_hp_big", "potion_mana_small", "potion_mana_big",
        "coins", "pouch", "herb", "fern_flower",
        "mushroom", "rusty_key", "letter", "idol",
        "rushnyk", "jug", "wolf_pelt", "bone_talisman"]),
    "active": ("sheet_active_v1.jpg", "skills", [
        "sk_whirlwind", "sk_piercing_shot", "sk_ancestral_heal", "sk_ground_slam",
        "sk_triple_slash", "sk_arrow_rain", "sk_fire_wave", "sk_chain_lightning",
        "sk_ice_shards", "sk_poison_cloud", "sk_wolf_spirit", "sk_raven_swarm",
        "sk_sun_beam", "sk_earth_spikes", "sk_shield_bash", "sk_battle_cry"]),
    "passive": ("sheet_passive_v1.jpg", "passives", [
        "pa_strength", "pa_life", "pa_faith", "pa_speed",
        "pa_stone_skin", "pa_crit", "pa_accuracy", "pa_cooldown",
        "pa_regen", "pa_lifesteal", "pa_thorns", "pa_luck",
        "pa_oak", "pa_lightning", "pa_fire", "pa_crown"]),
}


def cells(im, ox=14, oy=8, px=252.0, py=249.0, size=238):
    for j in range(4):
        for i in range(4):
            x = int(round(ox + px * i)); y = int(round(oy + py * j))
            yield i, j, im.crop((x + INSET, y + INSET, x + size - INSET, y + size - INSET))


FIXES = {  # заміни окремих клітинок: файл у art/sheets/fixes -> icon_id і група
    "weapons_02_greatsword.jpg": ("weapons", "w_greatsword"),
    "weapons_03_battle_axe.jpg": ("weapons", "w_axe"),
    "weapons_04_two_handed_axe.jpg": ("weapons", "w_greataxe"),
    "weapons_09_short_bow.jpg": ("weapons", "w_bow"),
    "weapons_10_long_bow.jpg": ("weapons", "w_longbow"),
    "passive_02_life.jpg": ("passives", "pa_life"),
    "passive_03_faith.jpg": ("passives", "pa_faith"),
    "passive_05_stone_skin.jpg": ("passives", "pa_stone_skin"),
    "passive_14_lightning_res.jpg": ("passives", "pa_lightning"),
    "passive_15_fire_res.jpg": ("passives", "pa_fire"),
    "passive_16_ultimate.jpg": ("passives", "pa_crown"),
}
FIX_ZOOM = 0.90  # предмет у заміні займає більше кадру: трохи зменшуємо й підкладаємо тло з країв


def cut_fix(path, out, zoom=FIX_ZOOM):
    im = Image.open(path).convert("RGB")
    w = im.size[0]
    # колір тла: середнє по рамці
    px = [im.getpixel((x, y)) for x in range(0, w, 16) for y in (2, w - 3)] + [im.getpixel((x, y)) for y in range(0, w, 16) for x in (2, w - 3)]
    bg = tuple(int(sum(c[i] for c in px) / len(px)) for i in range(3))
    canvas = Image.new("RGB", (w, w), bg)
    s = int(w * zoom)
    canvas.paste(im.resize((s, s), Image.LANCZOS), ((w - s) // 2, (w - s) // 2))
    canvas.resize((OUT, OUT), Image.LANCZOS).save(out)


def main():
    contact = Image.new("RGB", (4 * 5 * 130, 4 * 130 * 1), (20, 20, 20))
    for key, (fname, group, names) in SHEETS.items():
        im = Image.open(os.path.join(ROOT, "art", "sheets", fname)).convert("RGB")
        d = os.path.join(ROOT, "art", "icons", group)
        os.makedirs(d, exist_ok=True)
        sheet_contact = Image.new("RGB", (4 * 150, 4 * 150), (30, 30, 30))
        for i, j, c in cells(im):
            name = names[j * 4 + i]
            c = c.resize((OUT, OUT), Image.LANCZOS)
            c.save(os.path.join(d, name + ".png"))
            sheet_contact.paste(c.resize((140, 140)), (i * 150 + 5, j * 150 + 5))
        for fn, (g, nid) in FIXES.items():
            if g == group:
                src = os.path.join(ROOT, "art", "sheets", "fixes", fn)
                if os.path.exists(src):
                    cut_fix(src, os.path.join(d, nid + ".png"), 1.0 if group == "weapons" else FIX_ZOOM)
        # контактний аркуш після замін
        for idx, nm in enumerate(names):
            c = Image.open(os.path.join(d, nm + ".png")).convert("RGB").resize((140, 140))
            sheet_contact.paste(c, ((idx % 4) * 150 + 5, (idx // 4) * 150 + 5))
        sheet_contact.save("/tmp/contact_%s.png" % key)
        print(key, len(names))


if __name__ == "__main__":
    main()
