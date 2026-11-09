# Редактор Спогадів (editor APK)

Окремий пакет `com.moriartilab.spohady.editor`, лейбл **Редактор Спогадів**.
Той самий Godot-проєкт, вхід через `scenes/boot.tscn` → `OS.has_feature("editor_app")`
(або `SPOHADY_EDITOR=1` / `-- --editor_app` для локальних тестів).

## Вкладки (усі робочі)

| Вкладка | Зміст |
|--------|--------|
| Головна | Стан чернеток, швидкі дії |
| Древо | Повний редактор на `TreeEditorDoc` / `TreeEditorView` |
| GUI | Універсальна розкладка (`LayoutStore`) — зараз **HUD** |
| Генерація | Seed → Древо (дефолтний ассет / Python на ПК) |
| Перевірки | Метрики дерева + touch-checks HUD |
| Тема | `ThemeStore` → `ThemeRuntime` |
| Експорт | Zip-пакунок + `user://overrides/` |

## Дефолтне Древо

`res://data/editor/default_perk_tree.json` — **єдиний** ассет редактора (зараз **v7.3**, seed 424242).
Гра й далі читає `res://data/perk_tree.json` (v4). Підміна дефолту редактора = заміна цього файлу.

## Overrides гри (сейви не чіпаємо)

Пріоритет дерева: `user://overrides/tree.json` → `user://tree_active/perk_tree.json` → shipped.
Також: `user://overrides/ui_layout.json`, `user://overrides/theme.json`.

## Тести

```bash
tests/editor/run_all.sh
```

Скріншоти: `docs/editor_app/screenshots/tab_0.png` … `tab_6.png` (1920×864).

## Експорт

- Гра: preset **Android debug** → `build/spohady-v0.5.5.apk`
- Редактор: preset **Android editor** (`custom_features=editor_app`) → `build/spohady-editor-v0.1.0.apk`

## Що ще не готове (чесно)

- GUI-екрани поза HUD (пауза, інвентар, магазин…) — не в реєстрі; без фейкових кнопок «скоро».
- GDScript-порт генератора v7 на Android для **довільного** seed — нестабільний; на телефоні seed≠424242 → імпорт пакунка з ПК. На ПК Python дає точний результат.
- Повний in-tree UI редактора Древа (панель властивостей як у `TreeEditorScreen`) у вкладці «Древо» зараз через `TreeEditorView` + тулбар; окремий повний екран `tree_editor.tscn` лишається в проєкті.
