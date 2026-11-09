## Вкладка «Тема»: кольори панелей/акценту/HP/мана/статів + живе прев’ю.
class_name EditorTabTheme
extends ScrollContainer

var session: EditorSession
var _preview_host: PanelContainer
var _prev_title: Label
var _prev_btn: Button
var _prev_stats: HBoxContainer
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
	body.add_child(EditorChrome.make_label(
		"Зміни автозберігаються. «Застосувати» оновлює кольори в редакторі й прев’ю нижче.",
		18, Palette.TEXT_DIM))

	_preview_host = PanelContainer.new()
	_preview_host.custom_minimum_size = Vector2(0, 140)
	body.add_child(_preview_host)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	_preview_host.add_child(pv)
	var pad := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(m, 12)
	pv.add_child(pad)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	pad.add_child(inner)
	_prev_title = EditorChrome.make_label("Прев’ю панелі · Редактор Спогадів", 22, Palette.GOLD)
	inner.add_child(_prev_title)
	_prev_btn = EditorChrome.make_btn("Кнопка зразка", Palette.GOLD, 18)
	_prev_btn.custom_minimum_size = Vector2(180, 44)
	inner.add_child(_prev_btn)
	_prev_stats = HBoxContainer.new()
	_prev_stats.add_theme_constant_override("separation", 12)
	inner.add_child(_prev_stats)
	for pair in [["Сила", "str"], ["Спритність", "agi"], ["Віра", "faith"], ["Життя", "hp"], ["Чар", "mana"]]:
		var sl := Label.new()
		sl.text = pair[0]
		sl.add_theme_font_size_override("font_size", 18)
		sl.set_meta("stat_key", pair[1])
		_prev_stats.add_child(sl)

	_add_color(body, "panel", "Панель", session.theme.panel)
	_add_color(body, "panel_light", "Панель світла", session.theme.panel_light)
	_add_color(body, "accent", "Акцент / золото", session.theme.accent)
	_add_color(body, "text", "Текст", session.theme.text)
	_add_color(body, "text_dim", "Текст приглушений", session.theme.text_dim)
	_add_color(body, "embroidery", "Вишивка", session.theme.embroidery)
	_add_color(body, "night", "Ніч / фон", session.theme.night)
	_add_color(body, "hp", "Життя", session.theme.hp)
	_add_color(body, "mana", "Чар", session.theme.mana)
	_add_color(body, "stat_str", "Стат: Сила", session.theme.stat_colors.get("str", Color("C62828")))
	_add_color(body, "stat_agi", "Стат: Спритність", session.theme.stat_colors.get("agi", Color("2E7D32")))
	_add_color(body, "stat_faith", "Стат: Віра", session.theme.stat_colors.get("faith", Color("E0A526")))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var apply := EditorChrome.make_btn("Застосувати прев’ю", Color("2E7D32"))
	apply.pressed.connect(func():
		_flush()
		session.theme.apply_to_palette()
		_refresh_preview()
		session.status.emit("Тему застосовано до прев’ю.", "info"))
	row.add_child(apply)
	var reset := EditorChrome.make_btn("Скинути до дефолту", Palette.EMBROIDERY)
	reset.pressed.connect(func():
		session.theme.reset_to_defaults()
		_reload_pickers()
		session.theme.apply_to_palette()
		_refresh_preview()
		session.status.emit("Тему скинуто.", "info"))
	row.add_child(reset)
	_refresh_preview()


func _add_color(parent: Node, key: String, title: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := EditorChrome.make_label(title, 20)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = 240
	row.add_child(l)
	var p := ColorPickerButton.new()
	p.color = col
	p.custom_minimum_size = Vector2(160, 52)
	p.edit_alpha = false
	# Touch: larger picker popup
	p.get_picker().custom_minimum_size = Vector2(360, 420)
	p.color_changed.connect(func(_c):
		_flush()
		_refresh_preview())
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
	t.changed.emit()


func _refresh_preview() -> void:
	var t := session.theme
	var sb := StyleBoxFlat.new()
	sb.bg_color = t.panel
	sb.border_color = t.accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_preview_host.add_theme_stylebox_override("panel", sb)
	_prev_title.add_theme_color_override("font_color", t.accent)
	FolkTheme.apply_button(_prev_btn, t.accent, 18)
	for child in _prev_stats.get_children():
		var key := str(child.get_meta("stat_key", ""))
		var c := t.text
		if key == "str":
			c = t.stat_colors.get("str", Color("C62828"))
		elif key == "agi":
			c = t.stat_colors.get("agi", Color("2E7D32"))
		elif key == "faith":
			c = t.stat_colors.get("faith", Color("E0A526"))
		elif key == "hp":
			c = t.hp
		elif key == "mana":
			c = t.mana
		child.add_theme_color_override("font_color", c)


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
	_refresh_preview()
