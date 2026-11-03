# Куди класти малюнки (2D)

Гра сама підхопить файл, щойно він з'явиться за потрібною назвою. Нічого перепрограмовувати не треба:
поки файлу немає, показується простий плейсхолдер. Формат — **PNG з прозорістю**, кольоровий простір sRGB.

| Папка | Файл | Розмір | Де показується |
|---|---|---|---|
| `art/icons/skills/` | `power_strike.png`, `arrow_volley.png`, `element_wave.png`, `stribog_dash.png` | 256×256 | кнопки навичок біля кнопки удару |
| `art/icons/perks/` | `<id вузла>.png`, наприклад `s1.png`, `a3.png`, `core.png` (усі id — у `scripts/data/perk_tree.gd`) | 128×128 | вузли Древа звитяги |
| `art/portraits/` | `hero_druzhynnyk.png`, `hero_strilets.png`, `hero_volkhv.png` | 256×256 | портрет героя у верхньому лівому куті |
| `art/portraits/` | `blessing_perun.png`, `blessing_veles.png`, `blessing_stribog.png`, `blessing_dazhbog.png`, `blessing_mokosh.png`, `blessing_svarog.png` | 512×512 | вибір благословення |
| `art/portraits/` | `class_druzhynnyk.png`, `class_strilets.png`, `class_volkhv.png` | 512×512 | вибір класу |
| `art/ui/` | (резерв) рамки, фони, орнаменти | за потреби | поки не підключено |

Іконки малюйте так, щоб центральні 80% були значущими: у грі їх обрізає кругла кнопка.
