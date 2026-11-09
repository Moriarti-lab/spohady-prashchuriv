## Оболонка редактора: вкладки Головна/Древо/GUI/Генерація/Перевірки/Тема/Експорт.
extends Control

var session: EditorSession
var _tabs: TabContainer
var _status: Label
var _root_box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fill_viewport()
	get_viewport().size_changed.connect(_fill_viewport)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	session = EditorSession.new()
	session.boot()

	_root_box = VBoxContainer.new()
	_root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_box.add_theme_constant_override("separation", 0)
	add_child(_root_box)

	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(0, 64)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.12, 0.08, 0.07)
	hsb.content_margin_left = 16
	hsb.content_margin_right = 16
	hsb.content_margin_top = 10
	hsb.content_margin_bottom = 10
	header.add_theme_stylebox_override("panel", hsb)
	_root_box.add_child(header)

	var hrow := HBoxContainer.new()
	hrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_theme_constant_override("separation", 16)
	header.add_child(hrow)

	var title := Label.new()
	title.text = "Редактор Спогадів"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Palette.GOLD)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hrow.add_child(title)

	_status = Label.new()
	_status.text = "Готово"
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hrow.add_child(_status)
	session.status.connect(_on_status)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_box.add_child(_tabs)

	_add_tab("Головна", EditorTabHome.new())
	_add_tab("Древо", EditorTabTree.new())
	_add_tab("GUI", EditorTabGui.new())
	_add_tab("Генерація", EditorTabGen.new())
	_add_tab("Перевірки", EditorTabChecks.new())
	_add_tab("Тема", EditorTabTheme.new())
	_add_tab("Експорт", EditorTabExport.new())

	session.theme.apply_to_palette()
	call_deferred("_fill_viewport")
	call_deferred("_debug_sizes")


func _fill_viewport() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.x < 2.0 or vs.y < 2.0:
		vs = Vector2(1024, 473)
	# Anchor full + explicit size so headless / -s harness still lays out.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_right = 0
	anchor_bottom = 0
	position = Vector2.ZERO
	size = vs
	if _root_box:
		_root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root_box.size = vs


func _debug_sizes() -> void:
	print("EDITOR_SIZE ", size, " tabs=", _tabs.size if _tabs else Vector2.ZERO, " tab_count=", _tabs.get_tab_count() if _tabs else -1)


func _add_tab(title: String, tab: Control) -> void:
	tab.name = title
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if tab.has_method("setup"):
		tab.call("setup", session)
	_tabs.add_child(tab)


func _process(delta: float) -> void:
	if session:
		session.tick(delta)


func _on_status(msg: String, level: String) -> void:
	var c := Palette.TEXT_DIM
	if level == "warn":
		c = Palette.GOLD
	elif level == "error":
		c = Palette.EMBROIDERY
	elif level == "info":
		c = Palette.LINEN
	_status.add_theme_color_override("font_color", c)
	_status.text = msg
