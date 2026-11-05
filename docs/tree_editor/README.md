# Компонент: Редактор Древа звитяги

Нативний редактор у APK (меню «Редактор Древа») + HTML-редактор для ПК (`tools/tree-editor/`).  
Спільна схема JSON: [`docs/perk_tree_format.md`](../perk_tree_format.md).  
Спільний реєстр характеристик: [`data/stat_registry.json`](../../data/stat_registry.json), каталог: [`docs/tree_stat_catalogue.json`](../tree_stat_catalogue.json).  
План/аудит: [`docs/tree_editor_plan.md`](../tree_editor_plan.md).

## Що вміє in-APK редактор (0.5.4.2)

- Перегляд ~922 вузлів: pan / pinch / колесо / «Умістити», режими **Огляд · Рух · Зв’язки · Фон**.
- Вибір вузла → панель властивостей (укр.) + бонуси з реєстру.
- Ключі з `mechanics: display_only` підписані як **«експериментально / без ефекту в бою»** — редактор **не** підключає нові бойові формули.
- Пошук, undo/redo, перевірка (унікальні id, зв’язки, ключі stats, class_starts, острови).
- Чернетки: `user://tree_drafts/<id>/tree.json` + `project.json` + `bg.png` — **окремо від сейвів героя**.
- **Застосувати**: лише явно, з резервною копією в `user://tree_backups/`, результат у `user://tree_active/perk_tree.json` (override поверх shipped `res://`). Сейви героя не чіпаються. Файл усередині APK не перезаписується.
- Імпорт/експорт JSON; експорт також дублюється в `user://tree_drafts/.../export_tree.json`.

### Фон-шаблон (t76)

- Зображення в **тому ж world transform**, що вузли (`screen = (world - center) * zoom + viewport/2`).
- Opacity, width/height, preserve-aspect, origin, **замок** позиції/розміру (не блокує спільний pan/zoom), visibility.
- Імпорт копіює байти в чернетку (`bg.png`); повторне відкриття **не** залежить від тимчасового URI.
- Даунскейл longest side > 2048 px при імпорті.

## Android: вибір фото з телефону

Документований пайплайн Godot **4.7**:

1. `FileDialog.access = ACCESS_FILESYSTEM`
2. `FileDialog.use_native_dialog = true`
3. Фільтри з розширеннями **і** MIME (`image/png,image/jpeg`)
4. На Android нативний діалог використовує **SAF** і може повернути `content://…`
5. Читання через `FileAccess.open(uri)` → негайна **копія** в `user://tree_drafts/…/bg.png`

Джерела: [FileDialog 4.7](https://docs.godotengine.org/en/4.7/classes/class_filedialog.html) (note про Android + ACCESS_FILESYSTEM); SAF у Godot 4.x (`FileAccess` з URI).

| Середовище | Статус перевірки |
|------------|------------------|
| Linux desktop / headless CI | Імпорт з `res://` і звичайних шляхів — **покрито автотестами** |
| Фізичний Android | **Потрібна ручна перевірка** на пристрої з 0.5.4.2 APK: Редактор → «Імпорт фото» → галерея/файли → зберегти чернетку → закрити гру → знову відкрити редактор і переконатися, що фон на місці. |

Якщо на конкретному девайсі пікер не відкривається: переконайтесь, що діалог у дереві сцени (у нас так), `ACCESS_FILESYSTEM` + `use_native_dialog`. **Не** потрібні небезпечні permission-хаки для SAF URI. Якщо native feature відсутня — Godot може відкатись на custom FileDialog (обмежений доступ); це слід зафіксувати в issue з моделлю Android.

## ПК (HTML)

```bash
# відкрити tools/tree-editor/index.html у браузері
python3 tools/sync_editor_tree.py --check
python3 tools/sync_stat_registry.py --check
node tools/test_editor.js
```

## Тести

```bash
bash tests/run_all.sh
# окремо:
godot --path . res://tests/tree_editor_test.tscn
```

## Обмеження

- Немає генератора нових сотень вузлів; shipped tree не роздувається цим релізом.
- Apply на телефоні = user override, не патч APK.
- WebP залежить від збірки рушія; офіційно цілимось у **PNG/JPEG**.
- Фізичний SAF-пікер — device-only QA (див. таблицю вище).
