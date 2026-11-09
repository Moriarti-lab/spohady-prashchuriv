## Вкладка «GUI»: універсальний редактор розкладки (екран → елементи за id).
class_name EditorTabGui
extends HBoxContainer

var session: EditorSession
var _screen_list: ItemList
var _el_list: ItemList
var _canvas: Control
var _phone: Control
var _info: Label
var _selected_el: String = ""
var _selected_screen: String = "hud"
var _drag_id: String = ""
var _drag_off: Vector2 = Vector2.ZERO
var _handles: Dictionary = {}  # id -> Panel


func setup(s: EditorSession) -> void:
	session = s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 260
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(left)
	left.add_child(EditorChrome.make_label("Екрани", 22, Palette.GOLD))
	_screen_list = ItemList.new()
	_screen_list.custom_minimum_size = Vector2(0, 120)
	_screen_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen_list.item_selected.connect(_on_screen_sel)
	left.add_child(_screen_list)
	left.add_child(EditorChrome.make_label("Елементи", 22, Palette.GOLD))
	_el_list = ItemList.new()
	_el_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_el_list.item_selected.connect(_on_el_sel)
	left.add_child(_el_list)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	left.add_child(tools)
	var u := EditorChrome.make_btn("↶", Palette.PANEL_LIGHT, 18)
	u.custom_minimum_size = Vector2(48, 44)
	u.pressed.connect(func(): session.layout.undo(); _rebuild())
	tools.add_child(u)
	var r := EditorChrome.make_btn("↷", Palette.PANEL_LIGHT, 18)
	r.custom_minimum_size = Vector2(48, 44)
	r.pressed.connect(func(): session.layout.redo(); _rebuild())
	tools.add_child(r)
	var reset := EditorChrome.make_btn("Скинути HUD", Palette.EMBROIDERY, 16)
	reset.pressed.connect(func():
		session.layout.screens.erase("hud")
		session.layout.ensure_defaults()
		session.layout.push_undo()
		session.layout.changed.emit()
		_rebuild())
	tools.add_child(reset)

	_info = EditorChrome.make_label("Перетягніть блок на полотні. Інші екрани з’являться після реєстрації.", 16, Palette.TEXT_DIM)
	left.add_child(_info)

	# Canvas
	var canvas_wrap := PanelContainer.new()
	canvas_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.07)
	canvas_wrap.add_theme_stylebox_override("panel", sb)
	add_child(canvas_wrap)

	_canvas = Control.new()
	_canvas.clip_contents = true
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.gui_input.connect(_on_canvas_input)
	canvas_wrap.add_child(_canvas)

	_phone = ColorRect.new()
	_phone.color = Color(0.12, 0.1, 0.1)
	_canvas.add_child(_phone)

	session.layout_changed.connect(_rebuild)
	_canvas.resized.connect(func(): call_deferred("_rebuild_canvas"))
	visibility_changed.connect(func():
		if visible:
			call_deferred("_rebuild"))
	call_deferred("_rebuild")


func _rebuild() -> void:
	_screen_list.clear()
	var ids: Array = session.layout.list_screen_ids()
	var sel_i := 0
	for i in range(ids.size()):
		_screen_list.add_item("%s — %s" % [ids[i], session.layout.screen_title(ids[i])])
		if ids[i] == _selected_screen:
			sel_i = i
	if ids.size() > 0:
		_screen_list.select(sel_i)
		_selected_screen = ids[sel_i]
	_rebuild_elements()
	_rebuild_canvas()


func _rebuild_elements() -> void:
	_el_list.clear()
	var els: Array = session.layout.get_elements(_selected_screen)
	var sel_i := -1
	for i in range(els.size()):
		var el: Dictionary = els[i]
		var mark := "" if el.get("visible", true) else " (схований)"
		_el_list.add_item("%s [%s]%s" % [el.get("id"), el.get("type"), mark])
		if str(el.get("id")) == _selected_el:
			sel_i = i
	if sel_i >= 0:
		_el_list.select(sel_i)


func _rebuild_canvas() -> void:
	for h in _handles.values():
		if is_instance_valid(h):
			h.queue_free()
	_handles.clear()
	var cw := maxf(_canvas.size.x, 100.0)
	var ch := maxf(_canvas.size.y, 100.0)
	var aspect := session.layout.canvas_w / session.layout.canvas_h
	var pw: float
	var ph: float
	if cw / ch > aspect:
		ph = ch * 0.92
		pw = ph * aspect
	else:
		pw = cw * 0.92
		ph = pw / aspect
	_phone.position = Vector2((cw - pw) * 0.5, (ch - ph) * 0.5)
	_phone.size = Vector2(pw, ph)

	var sx := pw / session.layout.canvas_w
	var sy := ph / session.layout.canvas_h
	for el in session.layout.get_elements(_selected_screen):
		if not el.get("visible", true):
			continue
		var id := str(el.get("id"))
		var r: Rect2 = session.layout.element_rect(el, session.layout.canvas_w, session.layout.canvas_h)
		var p := Panel.new()
		p.position = _phone.position + Vector2(r.position.x * sx, r.position.y * sy)
		p.size = Vector2(maxf(r.size.x * sx, 24), maxf(r.size.y * sy, 24))
		var st := StyleBoxFlat.new()
		var selected := id == _selected_el
		st.bg_color = Color(session.theme.accent, 0.35 if selected else 0.22)
		st.border_color = session.theme.accent if selected else session.theme.text_dim
		st.set_border_width_all(2 if selected else 1)
		st.set_corner_radius_all(6)
		p.add_theme_stylebox_override("panel", st)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		var lbl := Label.new()
		lbl.text = str(el.get("text", id))
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Palette.LINEN)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(lbl)
		p.gui_input.connect(_on_handle_input.bind(id))
		_canvas.add_child(p)
		_handles[id] = p


func _on_screen_sel(i: int) -> void:
	var ids: Array = session.layout.list_screen_ids()
	if i < 0 or i >= ids.size():
		return
	_selected_screen = ids[i]
	_selected_el = ""
	_rebuild_elements()
	_rebuild_canvas()


func _on_el_sel(i: int) -> void:
	var els: Array = session.layout.get_elements(_selected_screen)
	if i < 0 or i >= els.size():
		return
	_selected_el = str(els[i].get("id"))
	_rebuild_canvas()


func _on_handle_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_selected_el = id
			_drag_id = id
			var h: Control = _handles.get(id)
			_drag_off = event.position
			_rebuild_elements()
			_rebuild_canvas()
			get_viewport().set_input_as_handled()
		else:
			if _drag_id != "":
				session.layout.push_undo()
			_drag_id = ""
	elif event is InputEventMouseMotion and _drag_id == id:
		_move_el(id, event.relative)
		get_viewport().set_input_as_handled()


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# deselect if click empty
		pass
	# redraw on resize
	if event is InputEventMouseMotion and _drag_id != "":
		pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_rebuild_canvas")


func _move_el(id: String, rel: Vector2) -> void:
	var pw: float = _phone.size.x
	var ph: float = _phone.size.y
	if pw < 1 or ph < 1:
		return
	var sx := session.layout.canvas_w / pw
	var sy := session.layout.canvas_h / ph
	var dx := rel.x * sx
	var dy := rel.y * sy
	var els: Array = session.layout.get_elements(_selected_screen)
	for i in range(els.size()):
		if str(els[i].get("id")) != id:
			continue
		if els[i].get("locked", false):
			_info.text = "«%s» заблоковано." % id
			return
		var o: Dictionary = els[i].get("o", {}).duplicate()
		o["l"] = float(o.get("l", 0)) + dx
		o["r"] = float(o.get("r", 0)) + dx
		o["t"] = float(o.get("t", 0)) + dy
		o["b"] = float(o.get("b", 0)) + dy
		els[i]["o"] = o
		session.layout.set_elements(_selected_screen, els)
		_rebuild_canvas()
		_info.text = "%s → l=%.0f t=%.0f" % [id, o["l"], o["t"]]
		return
