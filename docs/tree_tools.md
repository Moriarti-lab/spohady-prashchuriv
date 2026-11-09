# Інструменти Древа

| Інструмент | Призначення |
|------------|-------------|
| `tools/generate_perk_tree_v7.py` / GDScript gen | Генерація v7 (еталон seed 424242) |
| `tools/gen_descriptions.py` | Описи вузлів зі `stats` (`--check` у CI) |
| `tools/analyze_distances.py` | Мін. відстані між вузлами |
| `tools/analyze_paths.py` | Шляхи / зв’язність |
| `tools/analyze_balance.py` | Баланс статів по регіонах |
| `tools/tree-viewer/` | Офлайн-перегляд + анімація |
| `tools/ui-layout-editor/` | Офлайн-редактор розкладки UI |
| `tools/tree-editor/` | HTML-редактор Древа (вбудований default = корабельне) |

**Важливо:** аналізатори й viewer **не** перезаписують `data/perk_tree.json`. Генератор v7 за замовчуванням пише в OUT поза `data/` (див. README у tree-viewer).
