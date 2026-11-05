# Журнал змін

## 0.5.4.2 (2026-11-05)

- In-APK редактор Древа (меню): режими Огляд/Рух/Зв’язки/Фон, властивості UA, пошук, undo/redo, валідація.
- Чернетки `user://tree_drafts/`; Apply → `user://tree_active/` + `user://tree_backups/`; сейви героя за замовчуванням не чіпаються.
- Реєстр `data/stat_registry.json`; sync HTML `STAT_KEYS`; display_only з міткою «експериментально».
- t76: world-space фон PNG/JPEG, lock/opacity/aspect; імпорт через FileDialog ACCESS_FILESYSTEM + native (SAF на Android — device QA).
- Тести: `tests/tree_editor_test.tscn`; docs: `docs/tree_editor/README.md`.
- Збереження героя: SAVE_VERSION 4 без змін. Shipped tree ~922 вузли без росту.


## 0.5.4.1 (2026-11-05)

- Фікс: науз можна було зняти, але не одягнути — вкладка «Наузи» не мала явного «Одягнути»; `equip_nauz` не перевіряв вимоги/`last_error`.
- UI: гнізда героя + сумка; «Одягнути»→вибір слота; «Зняти»; вкладка «Нитки» з ціллю, гніздами й «Вплести»; вибір за UID.
- Тести: `tests/nauzi_ui_test.tscn` (equip×4, swap, unequip, bag full, req fail, weave bag/equipped, compat, reload).
- Збереження: SAVE_VERSION 4 без змін.

## 0.5.4 (2026-11-05)

- Фікс сумки: на landscape ~1024×473 кнопки дій знову видимі (опис у ScrollContainer, ActionBar закріплено внизу панелі; зайві дії в меню «Ще ▾»).
- Древо: відстані між вузлами ×10; zoom/огляд/редактор під новий простір; без зміни радіусів дотику.
- Україномовні підписи для `radius_pct` / `range_pct` / `duration_pct` у описах.
- Тести: `tests/layout_regression.tscn`; знімки з довгим описом і стартовим зумом Древа.
- Збереження: без змін схеми (SAVE_VERSION 4).

## 0.5.3 (2026-11-05)

- Древо Yggdrasil v4 (~922 вузли), UI панелі Древа, Вода забуття, BBCode-описи.
