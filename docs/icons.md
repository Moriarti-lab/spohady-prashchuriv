# Іконки (v0.3)

Реєстр: `data/icons.json` — `icon_id → {path, label, color}` (102 записи). Код: `scripts/data/icons.gd`.
Якщо файлу малюнка немає, гра малює кольорову заглушку з коротким написом (`label`, `color`), тому відсутній арт нічого не ламає.

## Як додати або замінити іконку без зміни коду
1. Поклади PNG (sRGB, прозоре тло, 256×256) у `art/icons/<папка>/<icon_id>.png`. Гра шукає в папках `weapons`, `armor`, `items`, `skills`, `passives`, `perks`, `extra` та в корені `art/icons/`.
2. Або впиши власний `path` у `data/icons.json`.
3. Центральні ~80% малюнка мають бути значущими: кругла маска (слоти навичок, вузли Древа) обрізає краї.

## Префікси icon_id
`w_*` зброя · `sh_*` щити · `h_*` шоломи · `g_*` рукавиці · `b_*` тулуб · `f_*` взуття · `r_*` персні · `a_*` амулети · `potion_*`, `coins`, `pouch` · `herb`, `fern`, `mushroom`, `rushnyk`, `letter`, `idol`, `jug`, `bone`, `wolf`, `rusty` (квестові речі й трофеї) · `sk_*` активні навички · `pa_*` пасивки Древа · `perk_*` області й центр.

## Чекають на арт (v0.3.0)
`w_wand` (жезл волхва), `b_robe` (риза), `sk_iron_wall`, `sk_rapid_shot`, `sk_hunters_trap`, `sk_ancestral_ward`.
Решта 96 іконок із реєстру мають малюнки.

## Інструменти
`tools/cut_icon_sheets.py` нарізає аркуші 4×4 з `art/sheets/`; `tools/gen_icons_json.py` збирає реєстр.

## 0.6.0

Заповнено `path` для: `w_wand`, `b_robe`, `sk_iron_wall`, `sk_rapid_shot`, `sk_hunters_trap`, `sk_ancestral_ward`. Іконки скілів — кругла маска, прозоре тло.
