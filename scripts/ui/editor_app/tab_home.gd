## Вкладка «Головна»: стан чернеток, швидкі дії.
class_name EditorTabHome
extends ScrollContainer

var session: EditorSession
var _body: VBoxContainer
var _stats: Label
var _status: Label


func setup(s: EditorSession) -> void:
	session = s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_body)
	add_child(margin)

	_body.add_child(EditorChrome.make_label("Редактор Спогадів", 34, Palette.GOLD))
	_body.add_child(EditorChrome.make_label(
		"Робочий інструмент: Древо, HUD, тема, генерація, перевірки й пакунок для гри. Чернетки в user://editor_drafts/ — сейви героя не чіпаємо.",
		18, Palette.TEXT_DIM))
	_body.add_child(EditorChrome.hsep())

	_stats = EditorChrome.make_label("", 20)
	_body.add_child(_stats)

	_status = EditorChrome.make_label("", 18, Palette.TEXT_DIM)
	_body.add_child(_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var b1 := EditorChrome.make_btn("Завантажити дефолтне Древо", Palette.EMBROIDERY)
	b1.pressed.connect(func():
		session.load_default_tree()
		refresh())
	row.add_child(b1)
	var b2 := EditorChrome.make_btn("Зберегти чернетки зараз", Color("2E7D32"))
	b2.pressed.connect(func():
		session.autosave()
		refresh())
	row.add_child(b2)
	var b3 := EditorChrome.make_btn("Застосувати в гру (overrides)", Palette.GOLD)
	b3.pressed.connect(func():
		session.install_to_game()
		refresh())
	row.add_child(b3)

	_body.add_child(EditorChrome.hsep())
	_body.add_child(EditorChrome.make_label("Вкладки", 26, Palette.GOLD))
	_body.add_child(EditorChrome.make_label(
		"• Древо — повний редактор вузлів/зв’язків\n• GUI — розкладка HUD (якорі, розміри, z-order)\n• Генерація — seed → нове Древо на пристрої\n• Перевірки — метрики дерева + торкання пальцем\n• Тема — кольори UI й статів\n• Експорт — пакунок zip + імпорт\n\nІнші GUI-екрани (пауза, інвентар, магазин…) — ще не в реєстрі; з’являться як дані, без переписування оболонки.",
		18, Palette.LINEN))

	session.status.connect(func(msg, level):
		var c := Palette.LINEN if level == "info" else (Palette.GOLD if level == "warn" else Palette.EMBROIDERY)
		_status.add_theme_color_override("font_color", c)
		_status.text = msg)
	session.tree_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if session == null:
		return
	var n: int = session.tree_doc.nodes.size()
	var l: int = session.tree_doc.links.size()
	var meta = session.tree_doc.to_tree_dict().get("meta", {})
	var tag := str(meta.get("version_tag", "?"))
	var seed := str(meta.get("seed", "?"))
	_stats.text = "Древо: %d вузлів, %d зв’язків · seed %s · %s · джерело: %s\nЕкрани розкладки: %s\nЧернетка брудна: %s" % [
		n, l, seed, tag, session.gen_source,
		", ".join(PackedStringArray(session.layout.list_screen_ids())),
		"так" if session.dirty else "ні",
	]
