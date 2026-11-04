# Подяки та ліцензії

## Код і ресурси гри
Код, частина 3D-моделей (низькополігональні будівлі, тварини, ефекти — збираються кодом) і редактор Древа створені всередині проєкту.

## 2D-малюнки
Усі 2D-малюнки в `art/` (портрети героїв, богів і класів, зображення ворогів, іконки навичок і перків,
смужки вишивки й дерев'яна рамка) **зроблені власником проєкту за допомогою ШІ**. Для гри їх лише зменшено,
обрізано та очищено від світлого тла скриптом `tools/prepare_art.py`.

## Іконки v0.3 (аркуші ШІ-арту власника)
Іконки зброї, броні й прикрас, речей, активних навичок і пасивок — **арт власника проєкту, створений за допомогою ШІ**.
Вихідні аркуші 4×4 лежать у `art/sheets/` (`sheet_weapons_v1`, `sheet_armor_v1`, `sheet_items_v1`, `sheet_active_v1`,
`sheet_passive_v1`, а також окремі заміни в `art/sheets/fixes/`). Нарізає їх `tools/cut_icon_sheets.py`
у `art/icons/*/<icon_id>.png`; реєстр `data/icons.json` збирає `tools/gen_icons_json.py`.

## Іконки v0.4
Іконки `w_wand`, `b_robe`, `sk_iron_wall`, `sk_rapid_shot`, `sk_hunters_trap`, `sk_ancestral_ward` — згенеровані ШІ для проєкту в стилі наявних.

## Сторонні набори (усі — CC0, суспільне надбання)
| Набір | Автор | Посилання | Де в грі |
|---|---|---|---|
| KayKit — Adventurers (Character Pack) | Kay Lousberg | <https://kaylousberg.itch.io/kaykit-adventurers> | герої (Дружинник = Knight, Стрілець = Rogue_Hooded, Волхв = Mage), мешканці села (Barbarian, Mage, Knight, Rogue), анімації |
| KayKit — Skeletons (Character Pack) | Kay Lousberg | <https://kaylousberg.itch.io/kaykit-skeletons> | нежить у Чорних курганах і печері, Кощій, Чорнокнижник |
| KayKit — Fantasy Weapons Bits | Kay Lousberg | <https://kaylousberg.itch.io/fantasy-weapons-bits> | 3D-зброя в руках героя за типом предмета |
| Kenney — Impact Sounds, Interface Sounds, RPG Audio, Music Jingles | Kenney (kenney.nl) | <https://kenney.nl/assets/impact-sounds>, <https://kenney.nl/assets/interface-sounds>, <https://kenney.nl/assets/rpg-audio>, <https://kenney.nl/assets/music-jingles> | удари, кліки, монети, підбір, скриня, завдання |

Ліцензійні файли лежать поруч: `models/kaykit/LICENSE_*.txt`, `models/weapons/LICENSE.txt`.
Файли KayKit узято з офіційних публікацій автора (дзеркала на GitHub з тим самим CC0-файлом ліцензії).

## Звук і музика
- Амбієнт локацій (село, ліс, твань, руїни, степ, печера), магія, рев босів, смерть, рівень, портал, попередження,
  спокійна й бойова музика — **синтезовані власним скриптом** `tools/gen_audio.py` (CC0, без чужих семплів).
- Решта звуків — Kenney (CC0), див. таблицю вище. Усе — OGG, моно, 22 кГц.

## Рушій
- **Godot Engine 4.7.2** — ліцензія MIT. © Juan Linietsky, Ariel Manzur та спільнота Godot.
  <https://godotengine.org/license>
- Шрифт за замовчуванням, що вбудований у Godot (Open Sans) — ліцензія Apache 2.0 / SIL OFL.
  Він містить кирилицю.

## Якщо додаватимете сторонні ресурси
Записуйте сюди: назву, автора, джерело (посилання), ліцензію (бажано CC0) і де використано.
