## Вкладка «Генерація»: seed → Древо (Python на ПК / GDScript на телефоні).
class_name EditorTabGen
extends ScrollContainer

var session: EditorSession
var _seed: LineEdit
var _progress: ProgressBar
var _log: Label
var _busy: bool = false


func setup(s: EditorSession) -> void:
	session = s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 20 if m != "margin_top" else 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(body)
	add_child(margin)

	body.add_child(EditorChrome.make_label("Генерація Древа v7", 30, Palette.GOLD))
	body.add_child(EditorChrome.make_label(
		"Алгоритм v7 (tools/generate_perk_tree_v7.py). Seed 424242 миттєво підставляє дефолтний ассет (зараз v7.3). На ПК інші seed рахує Python. На телефоні інші seed поки імпортуйте пакунком з ПК (GDScript-порт ще доводиться).",
		18, Palette.TEXT_DIM))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	row.add_child(EditorChrome.make_label("Seed:", 22))
	_seed = EditorChrome.make_line("424242")
	_seed.text = "424242"
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed.custom_minimum_size.x = 200
	row.add_child(_seed)

	var run := EditorChrome.make_btn("Згенерувати", Color("2E7D32"))
	run.pressed.connect(_on_run)
	row.add_child(run)
	var def := EditorChrome.make_btn("Дефолтний ассет", Palette.EMBROIDERY)
	def.pressed.connect(func():
		session.load_default_tree()
		_log.text = "Підставлено data/editor/default_perk_tree.json")
	row.add_child(def)

	_progress = ProgressBar.new()
	_progress.min_value = 0
	_progress.max_value = 1
	_progress.value = 0
	_progress.custom_minimum_size = Vector2(0, 28)
	body.add_child(_progress)

	_log = EditorChrome.make_label("", 18, Palette.LINEN)
	body.add_child(_log)


func _on_run() -> void:
	if _busy:
		return
	var txt := _seed.text.strip_edges()
	if not txt.is_valid_int():
		_log.add_theme_color_override("font_color", Palette.EMBROIDERY)
		_log.text = "Seed має бути цілим числом."
		return
	var seed := int(txt)
	_busy = true
	_log.add_theme_color_override("font_color", Palette.LINEN)
	_log.text = "Генерація…"
	_progress.value = 0
	var ok := session.generate_tree(seed, func(frac, msg):
		_progress.value = float(frac)
		_log.text = str(msg))
	_busy = false
	if ok:
		_progress.value = 1
		var d := session.tree_doc.to_tree_dict()
		_log.text = "Готово: %d вузлів, %d зв’язків (джерело: %s)." % [
			session.tree_doc.nodes.size(), session.tree_doc.links.size(), session.gen_source]
	else:
		_log.add_theme_color_override("font_color", Palette.EMBROIDERY)
		_log.text = session.last_error
