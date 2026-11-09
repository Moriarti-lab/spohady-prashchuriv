## Полотно редактора Древа: той самий world↔screen transform, що й PerkTreeView.
## Фон малюється в world-space (t76). Режими: view / move / link / bg.
class_name TreeEditorView
extends Control

signal node_selected(id: String)
signal empty_tapped
signal status(msg: String)

enum Mode { VIEW, MOVE, LINK, BG }

const ZOOM_MIN := 0.012
const ZOOM_MAX := 1.7
const TAP_SLOP := 14.0
const RADIUS := {"small": 14.0, "notable": 22.0, "keystone": 28.0, "skill": 20.0, "start": 24.0, "core": 32.0}

var doc: TreeEditorDoc
var mode: int = Mode.VIEW
var zoom := 0.08
var center := Vector2.ZERO
var _t := 0.0
var _touches := {}
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO
var _press := false
var _press_pos := Vector2.ZERO
var _drag := false
var _moving_id := ""
var _link_from := ""
var _bg_drag := false
var _bg_drag_start := Vector2.ZERO
var _bg_origin_start := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(400, 300)


func bind_doc(d: TreeEditorDoc) -> void:
	doc = d
	if doc:
		doc.changed.connect(queue_redraw)
		doc.selection_changed.connect(func(_id): queue_redraw())
	queue_redraw()


func to_screen(p: Vector2) -> Vector2:
	return (p - center) * zoom + size * 0.5


func to_tree(s: Vector2) -> Vector2:
	return (s - size * 0.5) / zoom + center


func focus_on(id: String, new_zoom: float = -1.0) -> void:
	if doc == null or not doc.nodes.has(id):
		return
	center = doc.pos_of(id)
	if new_zoom > 0.0:
		zoom = clampf(new_zoom, ZOOM_MIN, ZOOM_MAX)
	queue_redraw()


func zoom_at(screen_pt: Vector2, factor: float) -> void:
	var before := to_tree(screen_pt)
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	center = before - (screen_pt - size * 0.5) / zoom
	queue_redraw()


func zoom_center(factor: float) -> void:
	zoom_at(size * 0.5, factor)


func fit_all() -> void:
	if doc == null or doc.nodes.is_empty():
		return
	var mn := Vector2(1e12, 1e12)
	var mx := Vector2(-1e12, -1e12)
	for id in doc.nodes.keys():
		var p := doc.pos_of(id)
		mn = mn.min(p)
		mx = mx.max(p)
	if doc.bg_image != null and doc.bg_visible:
		for c in doc.bg_corners_world():
			mn = mn.min(c)
			mx = mx.max(c)
	var mid := (mn + mx) * 0.5
	var ext := (mx - mn) * 0.5
	center = mid
	var pad := 1.12
	var zx := size.x / maxf(ext.x * pad, 1.0)
	var zy := size.y / maxf(ext.y * pad, 1.0)
	# Не даємо «пляму» з мінімальних кіл: якщо zoom дуже малий — усе одно вміщуємо.
	zoom = clampf(minf(zx, zy), ZOOM_MIN, ZOOM_MAX)
	queue_redraw()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if get_global_rect().has_point(t.position):
				_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
		if _touches.size() == 2:
			_begin_pinch()
		elif _touches.size() < 2:
			_pinch_dist = 0.0
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.has(d.index):
			_touches[d.index] = d.position
			if _touches.size() == 2 and _pinch_dist > 0.0:
				_update_pinch()


func _begin_pinch() -> void:
	var pts: Array = _touches.values()
	_pinch_dist = maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
	_pinch_mid = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	_drag = true


func _update_pinch() -> void:
	var pts: Array = _touches.values()
	var dist := maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
	var mid := ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	var local_mid := mid - global_position
	zoom_at(local_mid, dist / _pinch_dist)
	center -= (mid - _pinch_mid) / zoom
	_pinch_dist = dist
	_pinch_mid = mid


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_at(mb.position, 1.15)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_at(mb.position, 1.0 / 1.15)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = true
				_drag = _touches.size() >= 2
				_press_pos = mb.position
				_moving_id = ""
				_bg_drag = false
				if mode == Mode.MOVE:
					var id := pick(mb.position)
					if id != "":
						_moving_id = id
						doc.select(id)
				elif mode == Mode.BG and doc and not doc.bg_lock:
					_bg_drag = true
					_bg_drag_start = mb.position
					_bg_origin_start = doc.bg_origin
			else:
				if _press and not _drag and _touches.size() < 2:
					_tap(mb.position)
				if _moving_id != "" and doc:
					doc.set_node_pos(_moving_id, doc.pos_of(_moving_id))  # commit undo
				if _bg_drag and doc and not doc.bg_lock:
					doc.set_bg_origin(doc.bg_origin)
				_press = false
				_drag = false
				_moving_id = ""
				_bg_drag = false
			accept_event()
	elif event is InputEventMouseMotion and _press:
		var mm := event as InputEventMouseMotion
		if _touches.size() >= 2:
			return
		if not _drag and mm.position.distance_to(_press_pos) > TAP_SLOP:
			_drag = true
		if _bg_drag and doc and not doc.bg_lock:
			var delta_world := (mm.position - _bg_drag_start) / zoom
			doc.bg_origin = _bg_origin_start - delta_world
			queue_redraw()
		elif _moving_id != "" and mode == Mode.MOVE and doc:
			var world := to_tree(mm.position)
			doc.nodes[_moving_id]["x"] = world.x
			doc.nodes[_moving_id]["y"] = world.y
			queue_redraw()
		elif _drag and mode == Mode.VIEW:
			center -= mm.relative / zoom
			queue_redraw()
		elif _drag and mode != Mode.MOVE and mode != Mode.BG:
			center -= mm.relative / zoom
			queue_redraw()
		elif _drag and mode == Mode.MOVE and _moving_id == "":
			center -= mm.relative / zoom
			queue_redraw()
		elif _drag and mode == Mode.BG and (doc == null or doc.bg_lock):
			center -= mm.relative / zoom
			queue_redraw()
		accept_event()


func pick(screen_pt: Vector2) -> String:
	if doc == null:
		return ""
	var best := ""
	var bd := 1.0e9
	for id in doc.nodes.keys():
		var r := maxf(float(RADIUS.get(str(doc.get_node(id).get("type", "small")), 22.0)) * zoom, 6.0 * maxf(zoom, 0.08)) + 10.0 * maxf(zoom, 0.15)
		var d := to_screen(doc.pos_of(id)).distance_to(screen_pt)
		if d < r and d < bd:
			bd = d
			best = id
	return best


func _tap(p: Vector2) -> void:
	var id := pick(p)
	if mode == Mode.LINK and doc:
		if id == "":
			_link_from = ""
			status.emit("Зв’язок: оберіть перший вузол")
			return
		if _link_from == "":
			_link_from = id
			doc.select(id)
			status.emit("Зв’язок від «%s» — торкніть другий вузол" % id)
			return
		if doc.add_link(_link_from, id):
			status.emit("Зв’язок %s — %s" % [_link_from, id])
		else:
			status.emit("Зв’язок не додано (вже є або той самий)")
		_link_from = ""
		return
	if id != "":
		if doc:
			doc.select(id)
		node_selected.emit(id)
	else:
		if doc:
			doc.select("")
		empty_tapped.emit()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("120E0F"))
	if doc == null:
		return
	var view := Rect2(Vector2.ZERO, size).grow(80.0)
	# Background first (world-space quad)
	if doc.bg_visible and doc.bg_texture != null:
		var tl := to_screen(doc.bg_origin)
		var br := to_screen(doc.bg_origin + doc.bg_size)
		var rect := Rect2(tl, br - tl)
		var mod := Color(1, 1, 1, doc.bg_opacity)
		draw_texture_rect(doc.bg_texture, rect, false, mod)
		if mode == Mode.BG:
			draw_rect(rect, Color(Palette.GOLD, 0.85 if not doc.bg_lock else 0.35), false, 2.0)
	# links
	for l in doc.links:
		if not doc.nodes.has(l[0]) or not doc.nodes.has(l[1]):
			continue
		var a := to_screen(doc.pos_of(l[0]))
		var b := to_screen(doc.pos_of(l[1]))
		if not view.has_point(a) and not view.has_point(b):
			continue
		draw_line(a, b, Color("6B4A35", 0.9), maxf(1.5, 2.5 * zoom), true)
	# nodes
	for id in doc.nodes.keys():
		var p := to_screen(doc.pos_of(id))
		if not view.has_point(p):
			continue
		_draw_node(id, p)


func _draw_node(id: String, p: Vector2) -> void:
	var d: Dictionary = doc.get_node(id)
	var type := str(d.get("type", "small"))
	var r := clampf(float(RADIUS.get(type, 14.0)) * zoom, 2.5, 26.0)
	var col := Color("C9A227")
	var rid := str(d.get("region", ""))
	for rg in doc.regions:
		if str(rg.get("id", "")) == rid:
			col = Color(str(rg.get("color", "#C9A227")))
			break
	draw_circle(p, r + 1.5, Color(Palette.NIGHT, 0.85))
	draw_circle(p, r, col)
	draw_arc(p, r + 1.5, 0.0, TAU, 24, Palette.GOLD if id == doc.selected_id else col.darkened(0.2), 2.5 if id == doc.selected_id else 1.6, true)
	if id == doc.selected_id:
		draw_arc(p, r + 8.0, 0.0, TAU, 28, Color(1, 1, 1, 0.95), 2.5, true)
	if zoom > 0.45 and type != "small":
		var font := ThemeDB.fallback_font
		var nm := str(d.get("name", id))
		var fs := int(clampf(14.0 * zoom + 6.0, 11.0, 20.0))
		var ts := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string_outline(font, p + Vector2(-ts.x * 0.5, r + fs + 2), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Palette.NIGHT)
		draw_string(font, p + Vector2(-ts.x * 0.5, r + fs + 2), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.LINEN)
