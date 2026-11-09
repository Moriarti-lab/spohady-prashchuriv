# Схема релізу 0.6.0 (кандидат)

**Гілка:** `feature/game-0.6.0` · **PR:** #5 → `main` (без merge, до ОК Сані)  
**Не чіпаємо:** pre-release `editor-v0.1.0-test`, hero saves (окрім штатної міграції `tree_version`).

## Зміст релізу

| Блок | Що |
|------|-----|
| Дерево | v7.3, 945 вузлів, seed 424242, `meta.tree_version=v7.3` |
| Міграція | `PerkTree.tree_id()` + `GameState.tree_version`; одноразове повернення очок; notice на HUD |
| Описи | `gen_descriptions.py --force` + `--check` у CI; F4 — без «Вузол ·N» |
| Підказки | `DescFormat.item_tooltip` + `make_tooltip_card` усюди (сумка/крамниця/loot/наузи/нитки/editor) |
| Іконки | I1: 6 path заповнено; кругла маска скілів |
| HUD | F5 підменю праворуч; F7 плашка вище; F10 кольори статів |
| Редактор | PR #4 у складі; Checks UA; Gen метрики; Theme прев’ю підказок |
| Tools | T1–T3: analyze_*, tree-viewer, ui-layout-editor, `docs/tree_tools.md`, `check_tree_seed.py` |
| Docs | README 0.6.0, CHANGELOG кандидат, todo_next, tree_migration, icons |

## Поза релізом
- LayoutApply для Сумки+ (P3) → 0.6.x  
- Display-only статти → окремий епік  
- GitHub Release / APK publish → після ОК цієї схеми  

## Знімки (phone 1920×864)
`docs/game_0_6_0/screenshots/phone_{inv_tooltip,shop,nauzi,threads,tree_v73,refund_notice,hud_submenu}.png`  
+ картки `phone_card_*.png`, `tooltip_sheet_phone.png`, `loot_popup_phone.png`

## Тести
`bash tests/run_all.sh` — editor + sync + flow + nauzi + layout + sell_cancel + gen_descriptions --check + check_tree_seed + item_tooltip + tree_migration.
