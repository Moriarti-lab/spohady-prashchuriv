## Вкладка «Тема»: кольори панелей/акценту/HP/мана/статів + прев’ю.
class_name EditorTabTheme
extends ScrollContainer

var session: EditorSession
var _preview: ColorRect
var _rows: Dictionary = {}  # key -> ColorPickerButton


func setup(s: EditorSession) -> void:
	session = s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 20)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(body)
	add_child(margin)

	body.add_child(EditorChrome.make_label("Тема", 30, Palette.GOLD))
	body.add_child(EditorChrome.make_label("Зміни автозберігаються. «Застосувати» пише ThemeRuntime для прев’ю в редакторі.", 18, Palette.TEXT_DIM))

	_preview = ColorRect.new()
	_preview.custom_minimum_size = Vector2(0, 72)
	_preview.color = session.theme.panel
	body.add_child(_preview)
	var prev_lbl := EditorChrome.make_label("Прев’ю панелі", 18)
	prev_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(prev_lbl)

	_add_color(body, "panel", "Панель", session.theme.panel)
	_add_color(body, "panel_light", "Панель світла", session.theme.panel_light)
	_add_color(body, "accent", "Акцент / золото", session.theme.accent)
	_add_color(body, "text", "Текст", session.theme.text)
	_add_color(body, "text_dim", "Текст приглушений", session.theme.text_dim)
	_add_color(body, "embroidery", "Вишивка", session.theme.embroidery)
	_add_color(body, "night", "Ніч / фон", session.theme.night)
	_add_color(body, "hp", "Життя", session.theme.hp)
	_add_color(body, "mana", "Чар", session.theme.mana)
	_add_color(body, "stat_str", "Стат: Сила", session.theme.stat_colors.get("str", Color.RED))
	_add_color(body, "stat_agi", "Стат: Спритність", session.theme.stat_colors.get("agi", Color.GREEN))
	_add_color(body, "stat_faith", "Стат: Віра", session.theme.stat_colors.get("faith", Color.YELLOW))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var apply := EditorChrome.make_btn("Застосувати прев’ю", Color("2E7D32"))
	apply.pressed.connect(func():
		_flush()
		session.theme.apply_to_palette()
		session.status.emit("Тему застосовано в ThemeRuntime.", "info"))
	row.add_child(apply)
	var reset := EditorChrome.make_btn("Скинути до дефолту", Palette.EMBROIDERY)
	reset.pressed.connect(func():
		session.theme.reset_to_defaults()
		_reload_pickers()
		session.theme.apply_to_palette()
		session.status.emit("Тему скинуто.", "info"))
	row.add_child(reset)


func _add_color(parent: Node, key: String, title: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := EditorChrome.make_label(title, 20)
	l.custom_minimum_size.x = 220
	row.add_child(l)
	var p := ColorPickerButton.new()
	p.color = col
	p.custom_minimum_size = Vector2(120, 44)
	p.edit_alpha = false
	p.color_changed.connect(func(_c): _flush())
	row.add_child(p)
	_rows[key] = p


func _flush() -> void:
	var t := session.theme
	t.panel = _rows["panel"].color
	t.panel_light = _rows["panel_light"].color
	t.accent = _rows["accent"].color
	t.text = _rows["text"].color
	t.text_dim = _rows["text_dim"].color
	t.embroidery = _rows["embroidery"].color
	t.night = _rows["night"].color
	t.hp = _rows["hp"].color
	t.mana = _rows["mana"].color
	t.stat_colors["str"] = _rows["stat_str"].color
	t.stat_colors["agi"] = _rows["stat_agi"].color
	t.stat_colors["faith"] = _rows["stat_faith"].color
	_preview.color = t.panel
	t.changed.emit()


func _reload_pickers() -> void:
	var t := session.theme
	_rows["panel"].color = t.panel
	_rows["panel_light"].color = t.panel_light
	_rows["accent"].color = t.accent
	_rows["text"].color = t.text
	_rows["text_dim"].color = t.text_dim
	_rows["embroidery"].color = t.embroidery
	_rows["night"].color = t.night
	_rows["hp"].color = t.hp
	_rows["mana"].color = t.mana
	_rows["stat_str"].color = t.stat_colors["str"]
	_rows["stat_agi"].color = t.stat_colors["agi"]
	_rows["stat_faith"].color = t.stat_colors["faith"]
	_preview.color = t.panel
