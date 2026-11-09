## Вкладка «GUI»: справжній HUD гри, елементи тягнуться/масштабуються.
class_name EditorTabGui
extends HBoxContainer

const UA_NAMES := {
	"portrait_panel": "Портрет",
	"minimap": "Карта",
	"stick": "Хід",
	"attack": "Удар",
	"potion_hp": "Життя",
	"potion_mana": "Чар",
	"menu": "Меню",
}

var session: EditorSession
var _screen_list: ItemList
var _el_list: ItemList
var _phone_host: Control
var _hud: Hud
var _info: Label
var _selected_el: String = ""
var _selected_screen: String = "hud"
var _drag_id: String = ""
var _resize_id: String = ""
var _drag_last: Vector2 = Vector2.ZERO
var _id_to_node: Dictionary = {}  # id -> Control
var _overlay_frame: Control  # selection outline
var _svp: SubViewport
var _svp_host: SubViewportContainer


func setup(s: EditorSession) -> void:
	session = s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(left)
	left.add_child(EditorChrome.make_label("Екрани", 22, Palette.GOLD))
	_screen_list = ItemList.new()
	_screen_list.custom_minimum_size = Vector2(0, 100)
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
	u.custom_minimum_size = Vector2(56, 52)
	u.pressed.connect(func(): session.layout.undo(); _apply_layout_to_hud())
	tools.add_child(u)
	var r := EditorChrome.make_btn("↷", Palette.PANEL_LIGHT, 18)
	r.custom_minimum_size = Vector2(56, 52)
	r.pressed.connect(func(): session.layout.redo(); _apply_layout_to_hud())
	tools.add_child(r)
	var reset := EditorChrome.make_btn("Скинути HUD", Palette.EMBROIDERY, 16)
	reset.custom_minimum_size = Vector2(140, 52)
	reset.pressed.connect(func():
		session.layout.screens.erase("hud")
		session.layout.ensure_defaults()
		session.layout.push_undo()
		session.layout.changed.emit()
		_rebuild_lists()
		_apply_layout_to_hud())
	tools.add_child(reset)

	_info = EditorChrome.make_label("Тягніть елементи на екрані. Інші екрани з’являться після підключення.", 15, Palette.TEXT_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_vertical = Control.SIZE_SHRINK_END
	_info.custom_minimum_size = Vector2(260, 64)
	left.add_child(_info)

	var canvas_wrap := PanelContainer.new()
	canvas_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.04)
	canvas_wrap.add_theme_stylebox_override("panel", sb)
	add_child(canvas_wrap)

	_phone_host = Control.new()
	_phone_host.clip_contents = true
	_phone_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_wrap.add_child(_phone_host)

	# Hud is CanvasLayer — must live inside SubViewport or it paints over every tab.
	_svp_host = SubViewportContainer.new()
	_svp_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_svp_host.stretch = true
	_svp_host.mouse_filter = Control.MOUSE_FILTER_STOP
	_phone_host.add_child(_svp_host)
	_svp = SubViewport.new()
	_svp.transparent_bg = true
	_svp.handle_input_locally = true
	_svp.gui_disable_input = false
	_svp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_svp_host.add_child(_svp)

	_hud = Hud.new()
	_hud.editor_preview = true
	_hud.layer = 1
	_svp.add_child(_hud)
	_hud.visible = false  # only while GUI tab active

	_overlay_frame = Panel.new()
	_overlay_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ost := StyleBoxFlat.new()
	ost.bg_color = Color(0, 0, 0, 0)
	ost.border_color = Palette.GOLD
	ost.set_border_width_all(3)
	_overlay_frame.add_theme_stylebox_override("panel", ost)
	_overlay_frame.visible = false
	# Overlay on top of viewport container (editor chrome, not inside game layer)
	_phone_host.add_child(_overlay_frame)

	session.layout_changed.connect(func():
		_rebuild_lists()
		_apply_layout_to_hud())
	visibility_changed.connect(func():
		if _svp_host:
			_svp_host.visible = visible
		if _hud:
			_hud.visible = visible
		if visible:
			call_deferred("_after_show")
		else:
			# Belt: hide CanvasLayer when leaving GUI tab
			if _hud:
				_hud.visible = false)
	call_deferred("_after_show")


func _after_show() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _hud:
		_hud.visible = true
	if _svp_host:
		_svp_host.visible = true
	_map_hud_nodes()
	_rebuild_lists()
	_apply_layout_to_hud()
	_wire_drag()


func _map_hud_nodes() -> void:
	if _hud == null or _hud._root == null:
		return
	_id_to_node = {
		"portrait_panel": _hud._top_panel,
		"minimap": _hud._mini_frame if _hud._mini_frame else _hud._mini,
		"stick": _hud._stick,
		"attack": _hud._attack,
		"potion_hp": _hud._potion_hp,
		"potion_mana": _hud._potion_mana,
		"menu": _hud._submenu,  # shown when open; also portrait is menu trigger
	}
	# Prefer portrait as «Меню» target if submenu hidden — use a fake: keep submenu mapping for size
	# Register for LayoutApply
	for id in _id_to_node.keys():
		var n = _id_to_node[id]
		if n is Control:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_STOP


func _wire_drag() -> void:
	for id in _id_to_node.keys():
		var n = _id_to_node[id]
		if n is Control and not (n as Control).gui_input.is_connected(_on_node_gui.bind(id)):
			(n as Control).gui_input.connect(_on_node_gui.bind(id))


func _rebuild_lists() -> void:
	_screen_list.clear()
	var ids: Array = session.layout.list_screen_ids()
	var sel_i := 0
	for i in range(ids.size()):
		var title := session.layout.screen_title(ids[i])
		_screen_list.add_item(title if title != "" else str(ids[i]))
		if ids[i] == _selected_screen:
			sel_i = i
	if ids.size() > 0:
		_screen_list.select(sel_i)
		_selected_screen = ids[sel_i]
	_el_list.clear()
	var els: Array = session.layout.get_elements(_selected_screen)
	var el_sel := -1
	for i in range(els.size()):
		var el: Dictionary = els[i]
		var id := str(el.get("id", ""))
		var name := str(UA_NAMES.get(id, el.get("text", id)))
		if name == "" or "[" in name or name == id:
			name = UA_NAMES.get(id, id)
		_el_list.add_item(name)
		if id == _selected_el:
			el_sel = i
	if el_sel >= 0:
		_el_list.select(el_sel)


func _apply_layout_to_hud() -> void:
	if _hud == null or _hud._root == null:
		return
	# Size phone host to canvas aspect of layout
	var host := _phone_host.size
	if host.x < 8 or host.y < 8:
		return
	var aspect := session.layout.canvas_w / session.layout.canvas_h
	var pw: float
	var ph: float
	if host.x / host.y > aspect:
		ph = host.y * 0.96
		pw = ph * aspect
	else:
		pw = host.x * 0.96
		ph = pw / aspect
	# Phone frame inside host; SubViewport isolates CanvasLayer
	var origin := Vector2((host.x - pw) * 0.5, (host.y - ph) * 0.5)
	if _svp_host:
		_svp_host.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_svp_host.anchor_right = 0
		_svp_host.anchor_bottom = 0
		_svp_host.position = origin
		_svp_host.size = Vector2(pw, ph)
	if _svp:
		_svp.size = Vector2i(maxi(2, int(pw)), maxi(2, int(ph)))
	if _hud._root:
		_hud._root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_hud._root.position = Vector2.ZERO
		_hud._root.size = Vector2(pw, ph)
		# Temporarily set canvas for layout apply scale
		var store := session.layout
		# Apply using same logic as game but scaled into phone
		var map := {
			"portrait_panel": _hud._top_panel,
			"minimap": _hud._mini,
			"stick": _hud._stick,
			"attack": _hud._attack,
			"potion_hp": _hud._potion_hp,
			"potion_mana": _hud._potion_mana,
			"menu": _hud._submenu,
		}
		# First run default hud layout at phone size
		_hud._layout()
		# Then override from store
		var sx := pw / store.canvas_w
		var sy := ph / store.canvas_h
		for el in store.get_elements("hud"):
			var id := str(el.get("id", ""))
			var node = map.get(id, null)
			if node == null:
				continue
			var r: Rect2 = store.element_rect(el, store.canvas_w, store.canvas_h)
			var pos := Vector2(r.position.x * sx, r.position.y * sy)
			var sz := Vector2(r.size.x * sx, r.size.y * sy)
			if node is TouchStick:
				(node as TouchStick).home = pos + sz * 0.5
				(node as TouchStick).base_center = (node as TouchStick).home
				node.queue_redraw()
			elif node.has_method("place"):
				node.place(pos + sz * 0.5)
			elif node is Control:
				(node as Control).position = pos
				(node as Control).size = sz
			if node is CanvasItem:
				(node as CanvasItem).visible = bool(el.get("visible", true))
		# minimap frame follows mini
		if _hud._mini_frame != null and _hud._mini != null and _hud._mini is Control:
			_hud._mini_frame.position = (_hud._mini as Control).position
			_hud._mini_frame.size = (_hud._mini as Control).size
		_update_selection_frame()


func _on_screen_sel(i: int) -> void:
	var ids: Array = session.layout.list_screen_ids()
	if i < 0 or i >= ids.size():
		return
	_selected_screen = ids[i]
	_selected_el = ""
	_rebuild_lists()


func _on_el_sel(i: int) -> void:
	var els: Array = session.layout.get_elements(_selected_screen)
	if i < 0 or i >= els.size():
		return
	_selected_el = str(els[i].get("id"))
	_update_selection_frame()


func _update_selection_frame() -> void:
	var node = _id_to_node.get(_selected_el, null)
	if node == null or not (node is Control):
		_overlay_frame.visible = false
		return
	var c := node as Control
	_overlay_frame.visible = true
	# frame in phone_host space
	var gp := c.get_global_rect()
	var hp := _phone_host.get_global_rect()
	_overlay_frame.position = gp.position - hp.position
	_overlay_frame.size = gp.size


func _on_node_gui(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_selected_el = id
			_drag_id = id
			_drag_last = event.global_position
			_rebuild_lists()
			_update_selection_frame()
			get_viewport().set_input_as_handled()
		else:
			if _drag_id != "":
				session.layout.push_undo()
			_drag_id = ""
	elif event is InputEventMouseMotion and _drag_id == id:
		var delta: Vector2 = event.global_position - _drag_last
		_drag_last = event.global_position
		_move_el(id, delta)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_selected_el = id
			_drag_id = id
			_drag_last = event.position
			_rebuild_lists()
			_update_selection_frame()
		else:
			if _drag_id != "":
				session.layout.push_undo()
			_drag_id = ""
	elif event is InputEventScreenDrag and _drag_id == id:
		_move_el(id, event.relative)
		_drag_last = event.position


func _move_el(id: String, rel_screen: Vector2) -> void:
	var host := _phone_host.size
	if host.x < 8:
		return
	var aspect := session.layout.canvas_w / session.layout.canvas_h
	var pw: float
	var ph: float
	if host.x / host.y > aspect:
		ph = host.y * 0.96
		pw = ph * aspect
	else:
		pw = host.x * 0.96
		ph = pw / aspect
	var sx := session.layout.canvas_w / pw
	var sy := session.layout.canvas_h / ph
	var dx := rel_screen.x * sx
	var dy := rel_screen.y * sy
	var els: Array = session.layout.get_elements(_selected_screen)
	for i in range(els.size()):
		if str(els[i].get("id")) != id:
			continue
		if els[i].get("locked", false):
			_info.text = "«%s» заблоковано." % UA_NAMES.get(id, id)
			return
		var o: Dictionary = els[i].get("o", {}).duplicate()
		o["l"] = float(o.get("l", 0)) + dx
		o["r"] = float(o.get("r", 0)) + dx
		o["t"] = float(o.get("t", 0)) + dy
		o["b"] = float(o.get("b", 0)) + dy
		els[i]["o"] = o
		# keep Ukrainian display name in text
		if str(els[i].get("text", "")) == "" or str(els[i].get("text")) == id:
			els[i]["text"] = UA_NAMES.get(id, id)
		session.layout.set_elements(_selected_screen, els)
		_apply_layout_to_hud()
		_info.text = "%s" % UA_NAMES.get(id, id)
		return


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_apply_layout_to_hud")
