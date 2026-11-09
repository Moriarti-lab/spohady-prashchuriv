## In-APK редактор Древа: меню → цей екран. Чернетки user://, фон world-space, реєстр статів.
class_name TreeEditorScreen
extends Control

const DRAFT_ID := "default"

var doc: TreeEditorDoc
var _view: TreeEditorView
var _picker: NativeFilePicker
var _status: Label
var _search: LineEdit
var _prop_scroll: ScrollContainer
var _prop_box: VBoxContainer
var _mode_btns: Dictionary = {}
var _action_bar: HBoxContainer
var _bg_panel: VBoxContainer
var _apply_confirm: ConfirmationDialog
var _pending_save_path := ""
var _building_props := false
var embed_mode := false  ## true = вкладка редактора APK (без зміни сцени)
var _session = null  ## EditorSession, optional
var _close_btn: Button = null


func _ready() -> void:
	if not embed_mode:
		FolkTheme.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if doc == null:
		doc = TreeEditorDoc.new()
	_picker = NativeFilePicker.new()
	add_child(_picker)
	_picker.file_picked.connect(_on_picked)
	_build_ui()
	if _session == null:
		var err := TreeDraftStore.load_draft(doc, DRAFT_ID)
		if err != "":
			TreeDraftStore.load_shipped_into(doc)
	_view.bind_doc(doc)
	doc.selection_changed.connect(_on_sel)
	doc.changed.connect(_on_doc_changed)
	call_deferred("_fit_when_sized")
	_set_status("Редактор Древа · зміни в чернетці, сейви героя не чіпаємо")


func bind_session(session) -> void:
	## Перед додаванням у дерево сцени (або одразу після): спільний doc сесії.
	_session = session
	embed_mode = true
	doc = session.tree_doc


func _fit_when_sized() -> void:
	if _view == null:
		return
	# Чекаємо реальний розмір полотна (у вкладці спочатку 0).
	for _i in range(8):
		if _view.size.x > 64.0 and _view.size.y > 64.0:
			break
		await get_tree().process_frame
	_view.fit_all()
	_view.queue_redraw()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.05, 1)
	FolkTheme.fullscreen(bg)
	add_child(bg)

	_view = TreeEditorView.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.offset_top = 78
	_view.offset_right = -320
	_view.offset_bottom = -64
	_view.status.connect(_set_status)
	_view.node_selected.connect(func(id): _rebuild_props())
	add_child(_view)

	# Top bar
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 78
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.09, 0.06, 0.05, 1)
	tsb.border_width_bottom = 2
	tsb.border_color = Color(Palette.GOLD, 0.4)
	tsb.content_margin_left = 8
	tsb.content_margin_right = 8
	tsb.content_margin_top = 6
	tsb.content_margin_bottom = 6
	top.add_theme_stylebox_override("panel", tsb)
	add_child(top)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	top.add_child(head)
	head.add_child(FolkTheme.label("Редактор Древа", 24, Palette.GOLD))
	_search = LineEdit.new()
	_search.placeholder_text = "Пошук за назвою…"
	_search.custom_minimum_size = Vector2(160, 44)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_submitted.connect(_on_search)
	head.add_child(_search)
	for spec in [["Знайти", _do_search], ["↶", func(): doc.undo(); _view.queue_redraw(); _rebuild_props()], ["↷", func(): doc.redo(); _view.queue_redraw(); _rebuild_props()]]:
		var b := Button.new()
		b.text = spec[0]
		FolkTheme.apply_button(b, Palette.PANEL_LIGHT, 18)
		b.custom_minimum_size = Vector2(56, 44)
		b.pressed.connect(spec[1])
		head.add_child(b)
	var close := Button.new()
	close.text = "Закрити"
	FolkTheme.apply_button(close, Palette.EMBROIDERY, 20)
	close.custom_minimum_size = Vector2(110, 48)
	close.pressed.connect(_close)
	head.add_child(close)

	# Mode tools left
	var tools := VBoxContainer.new()
	tools.position = Vector2(8, 88)
	tools.add_theme_constant_override("separation", 6)
	add_child(tools)
	for spec in [[TreeEditorView.Mode.VIEW, "Огляд"], [TreeEditorView.Mode.MOVE, "Рух"], [TreeEditorView.Mode.LINK, "Зв’язки"], [TreeEditorView.Mode.BG, "Фон"]]:
		var b := Button.new()
		b.text = spec[1]
		FolkTheme.apply_button(b, Palette.PANEL_LIGHT, 16)
		b.custom_minimum_size = Vector2(100, 48)
		var m: int = spec[0]
		b.pressed.connect(func() -> void: _set_mode(m))
		tools.add_child(b)
		_mode_btns[m] = b
	for spec in [["+", 1.25], ["−", 0.8]]:
		var zb := Button.new()
		zb.text = spec[0]
		FolkTheme.apply_button(zb, Palette.PANEL_LIGHT, 28)
		zb.custom_minimum_size = Vector2(64, 48)
		var f: float = spec[1]
		zb.pressed.connect(func() -> void: _view.zoom_center(f))
		tools.add_child(zb)
	var fit := Button.new()
	fit.text = "Умістити"
	FolkTheme.apply_button(fit, Palette.PANEL_LIGHT, 16)
	fit.custom_minimum_size = Vector2(100, 44)
	fit.pressed.connect(func() -> void: _view.fit_all())
	tools.add_child(fit)
	_set_mode(TreeEditorView.Mode.VIEW)

	# Right property panel
	var right := PanelContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -320
	right.offset_top = 78
	right.offset_bottom = -64
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.10, 0.07, 0.06, 0.98)
	rsb.border_width_left = 2
	rsb.border_color = Color(Palette.GOLD, 0.35)
	rsb.content_margin_left = 8
	rsb.content_margin_right = 8
	rsb.content_margin_top = 8
	rsb.content_margin_bottom = 8
	right.add_theme_stylebox_override("panel", rsb)
	add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	right.add_child(rv)
	rv.add_child(FolkTheme.label("Властивості", 22, Palette.GOLD))
	_prop_scroll = ScrollContainer.new()
	_prop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(_prop_scroll)
	_prop_box = VBoxContainer.new()
	_prop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_box.add_theme_constant_override("separation", 6)
	_prop_scroll.add_child(_prop_box)

	# Background controls (always under props area via rebuild)
	# Bottom action bar — pinned
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -64
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.09, 0.06, 0.05, 1)
	bsb.border_width_top = 2
	bsb.border_color = Color(Palette.GOLD, 0.4)
	bsb.content_margin_left = 8
	bsb.content_margin_right = 8
	bsb.content_margin_top = 6
	bsb.content_margin_bottom = 6
	bottom.add_theme_stylebox_override("panel", bsb)
	add_child(bottom)
	_action_bar = HBoxContainer.new()
	_action_bar.add_theme_constant_override("separation", 6)
	bottom.add_child(_action_bar)
	for spec in [
		["Зберегти", _save_draft],
		["Перевірити", _validate],
		["Імпорт фото", _import_image],
		["Імпорт JSON", _import_json],
		["Експорт", _export_json],
		["Застосувати", _ask_apply],
	]:
		var b := Button.new()
		b.text = spec[0]
		FolkTheme.apply_button(b, Palette.EMBROIDERY if spec[0] == "Застосувати" else Palette.PANEL_LIGHT, 16)
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		_action_bar.add_child(b)

	_status = FolkTheme.label("", 16, Palette.LINEN)
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -88
	_status.offset_bottom = -64
	_status.offset_left = 110
	_status.offset_right = -330
	add_child(_status)

	_apply_confirm = ConfirmationDialog.new()
	_apply_confirm.title = "Застосувати Древо до гри?"
	_apply_confirm.dialog_text = "Сейви героя не зміняться. Поточне активне Древо збережеться в резервну копію user://tree_backups/. На пристрої змінюється лише user://tree_active/ (не файл у APK)."
	_apply_confirm.confirmed.connect(_do_apply)
	add_child(_apply_confirm)

	_rebuild_props()


func _set_mode(m: int) -> void:
	_view.mode = m
	for k in _mode_btns.keys():
		var b: Button = _mode_btns[k]
		FolkTheme.apply_button(b, Palette.EMBROIDERY if int(k) == m else Palette.PANEL_LIGHT, 16)
	match m:
		TreeEditorView.Mode.VIEW:
			_set_status("Огляд: тягни карту, щипок — масштаб, дотик — вибір")
		TreeEditorView.Mode.MOVE:
			_set_status("Рух: перетягни вузол (огляд панорами — порожнє місце)")
		TreeEditorView.Mode.LINK:
			_set_status("Зв’язки: два дотики по вузлах")
		TreeEditorView.Mode.BG:
			_set_status("Фон: зніми «Замок», щоб рухати шаблон; pan/zoom завжди спільні")


func _set_status(msg: String) -> void:
	if _status:
		_status.text = msg


func _close() -> void:
	if embed_mode:
		_set_status("Чернетку збережено в редакторі.")
		if _session:
			_session.autosave()
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_sel(_id: String) -> void:
	_rebuild_props()


func _on_doc_changed() -> void:
	if not _building_props:
		# lightweight: don't rebuild every pan of bg; only when selection fields matter
		pass


func _do_search() -> void:
	_on_search(_search.text)


func _on_search(q: String) -> void:
	var hits: Array = doc.search(q)
	if hits.is_empty():
		_set_status("Нічого не знайдено")
		return
	doc.select(str(hits[0]))
	_view.focus_on(str(hits[0]), maxf(_view.zoom, 0.4))
	_set_status("Знайдено %d · показую «%s»" % [hits.size(), hits[0]])
	_rebuild_props()


func _save_draft() -> void:
	var err := TreeDraftStore.save_draft(doc, DRAFT_ID)
	_set_status("Збережено чернетку" if err == "" else err)


func _validate() -> void:
	var errs: Array = doc.validate()
	if errs.is_empty():
		_set_status("Перевірка: помилок немає (%d вузлів)" % doc.nodes.size())
	else:
		_set_status("Перевірка: %d повідомлень · %s" % [errs.size(), str(errs[0])])
		print("TreeEditor validate:")
		for e in errs:
			print("  ", e)


func _import_image() -> void:
	_pending_save_path = "image"
	_picker.pick_image()
	_set_status("Пікер зображення… %s" % _picker.last_platform_note)


func _import_json() -> void:
	_pending_save_path = "json_import"
	_picker.pick_json()


func _export_json() -> void:
	# Always also write a reliable user:// export; native save is best-effort
	var path := "user://tree_drafts/%s/export_tree.json" % DRAFT_ID
	var err := TreeDraftStore.export_tree_json(doc, path)
	_set_status("Експортовано" if err == "" else err)
	_pending_save_path = "json_export"
	_picker.save_json_as("perk_tree.json")


func _on_picked(path: String) -> void:
	match _pending_save_path:
		"image":
			var err := TreeDraftStore.import_image_bytes_to_doc(doc, path, DRAFT_ID)
			_set_status("Фон імпортовано" if err == "" else err)
			_view.queue_redraw()
			_rebuild_props()
		"json_import":
			var err2 := TreeDraftStore.import_tree_json(doc, path)
			_set_status("JSON імпортовано" if err2 == "" else err2)
			_view.fit_all()
			_rebuild_props()
		"json_export":
			var err3 := TreeDraftStore.export_tree_json(doc, path)
			# If Android content:// write works via FileAccess
			if err3 != "":
				# fallback already in user://
				_set_status("Збереження: %s · є локальна копія" % err3)
			else:
				_set_status("Експортовано: %s" % path)
		_:
			_set_status("Обрано: %s" % path)
	_pending_save_path = ""


func _ask_apply() -> void:
	_apply_confirm.popup_centered()


func _do_apply() -> void:
	var verrs: Array = doc.validate()
	for e in verrs:
		if str(e).begins_with("ПОМИЛКА:"):
			_set_status("Застосування скасовано: %s" % e)
			return
	var err := TreeDraftStore.apply_to_game(doc)
	_set_status("Застосовано до гри" if err == "" else err)


func _rebuild_props() -> void:
	_building_props = true
	for c in _prop_box.get_children():
		c.queue_free()
	# Background section always
	_prop_box.add_child(FolkTheme.label("Фон-шаблон (t76)", 18, Palette.GOLD))
	_add_check("Показувати фон", doc.bg_visible, func(v: bool) -> void: doc.bg_visible = v; doc.changed.emit(); _view.queue_redraw())
	_add_check("Замок позиції/розміру", doc.bg_lock, func(v: bool) -> void: doc.bg_lock = v; _set_status("Замок фону: %s (pan/zoom вільні)" % ("так" if v else "ні")))
	_add_check("Зберігати пропорції", doc.bg_preserve_aspect, func(v: bool) -> void: doc.bg_preserve_aspect = v)
	_add_slider("Прозорість", doc.bg_opacity, 0.0, 1.0, func(v: float) -> void: doc.bg_opacity = v; _view.queue_redraw())
	_add_spin("Ширина (world)", doc.bg_size.x, 10.0, 50000.0, func(v: float) -> void: doc.set_bg_width(v); _view.queue_redraw())
	_add_spin("Висота (world)", doc.bg_size.y, 10.0, 50000.0, func(v: float) -> void: doc.set_bg_height(v); _view.queue_redraw())
	_add_spin("X початку", doc.bg_origin.x, -100000.0, 100000.0, func(v: float) -> void: if not doc.bg_lock: doc.bg_origin.x = v; _view.queue_redraw())
	_add_spin("Y початку", doc.bg_origin.y, -100000.0, 100000.0, func(v: float) -> void: if not doc.bg_lock: doc.bg_origin.y = v; _view.queue_redraw())
	var bginfo := FolkTheme.label(
		"Зображення: %s" % ("є %dx%d" % [doc.bg_pixel_size.x, doc.bg_pixel_size.y] if doc.bg_image else "немає — «Імпорт фото»"),
		14, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	_prop_box.add_child(bginfo)

	_prop_box.add_child(FolkTheme.label("Вузол", 18, Palette.GOLD))
	if doc.selected_id == "" or not doc.nodes.has(doc.selected_id):
		_prop_box.add_child(FolkTheme.label("Оберіть вузол на карті", 16, Palette.TEXT_DIM))
		_building_props = false
		return
	var id := doc.selected_id
	var n: Dictionary = doc.get_node(id)
	_prop_box.add_child(FolkTheme.label("id: %s" % id, 14, Palette.LINEN))
	_add_line("Назва", str(n.get("name", "")), func(t: String) -> void: doc.set_node_field(id, "name", t))
	_add_area("Опис", str(n.get("description", "")), func(t: String) -> void: doc.set_node_field(id, "description", t))
	_add_line("Тип", str(n.get("type", "small")), func(t: String) -> void: doc.set_node_field(id, "type", t))
	_add_line("Регіон", str(n.get("region", "")), func(t: String) -> void: doc.set_node_field(id, "region", t))
	_add_line("Іконка", str(n.get("icon", "")), func(t: String) -> void: doc.set_node_field(id, "icon", t))
	_prop_box.add_child(FolkTheme.label("Характеристики (реєстр)", 16, Palette.GOLD))
	var st: Dictionary = n.get("stats", {})
	if typeof(st) != TYPE_DICTIONARY:
		st = {}
	for sk in StatRegistry.tree_node_ids():
		var cur := float(st.get(sk, 0))
		var lab := StatRegistry.editor_label(sk)
		var key: String = sk
		var nid: String = id
		_add_spin(lab, cur, -500.0, 500.0, func(v: float) -> void: doc.set_node_stat(nid, key, v), 14)
	_building_props = false


func _add_check(text: String, value: bool, cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.toggled.connect(cb)
	_prop_box.add_child(c)


func _add_slider(text: String, value: float, mn: float, mx: float, cb: Callable) -> void:
	_prop_box.add_child(FolkTheme.label(text, 14, Palette.LINEN))
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(0, 28)
	s.value_changed.connect(cb)
	_prop_box.add_child(s)


func _add_spin(text: String, value: float, mn: float, mx: float, cb: Callable, font_sz: int = 14) -> void:
	var row := HBoxContainer.new()
	var lb := FolkTheme.label(text, font_sz, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.custom_minimum_size = Vector2(0, 28)
	row.add_child(lb)
	var sp := SpinBox.new()
	sp.min_value = mn
	sp.max_value = mx
	sp.step = 1.0
	sp.value = value
	sp.custom_minimum_size = Vector2(100, 36)
	sp.value_changed.connect(cb)
	row.add_child(sp)
	_prop_box.add_child(row)


func _add_line(text: String, value: String, cb: Callable) -> void:
	_prop_box.add_child(FolkTheme.label(text, 14, Palette.TEXT_DIM))
	var le := LineEdit.new()
	le.text = value
	le.custom_minimum_size = Vector2(0, 40)
	le.text_submitted.connect(cb)
	le.focus_exited.connect(func() -> void: cb.call(le.text))
	_prop_box.add_child(le)


func _add_area(text: String, value: String, cb: Callable) -> void:
	_prop_box.add_child(FolkTheme.label(text, 14, Palette.TEXT_DIM))
	var te := TextEdit.new()
	te.text = value
	te.custom_minimum_size = Vector2(0, 72)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.focus_exited.connect(func() -> void: cb.call(te.text))
	_prop_box.add_child(te)
