## Намальоване Древо звитяги з JSON: перетягування пальцем, щипок/колесо для масштабу, дотик обирає вузол.
class_name PerkTreeView
extends Control

signal node_selected(id: String)

const ZOOM_MIN := 0.12
const ZOOM_MAX := 1.7
const TAP_SLOP := 14.0
const RADIUS := {"small": 22.0, "notable": 31.0, "keystone": 42.0, "skill": 35.0, "start": 38.0, "core": 50.0}
const REGION_ICONS := {"str": "perk_region_str", "agi": "perk_region_agi", "faith": "perk_region_faith"}

var selected := ""
var zoom := 0.5
var center := Vector2.ZERO          # точка дерева в центрі вікна
var _t := 0.0
var _touches := {}                  # index -> позиція (для щипка)
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO
var _press := false
var _press_pos := Vector2.ZERO
var _drag := false
var _icon_cache := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(480, 360)
	clip_contents = true
	focus_mode = Control.FOCUS_NONE


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


# ---------- Перетворення координат ----------

func to_screen(p: Vector2) -> Vector2:
	return (p - center) * zoom + size * 0.5


func to_tree(s: Vector2) -> Vector2:
	return (s - size * 0.5) / zoom + center


func focus_on(id: String, new_zoom: float = -1.0) -> void:
	if not PerkTree.has_node(id):
		return
	center = PerkTree.pos(id)
	if new_zoom > 0.0:
		zoom = clampf(new_zoom, ZOOM_MIN, ZOOM_MAX)
	queue_redraw()


func zoom_at(screen_pt: Vector2, factor: float) -> void:
	var before := to_tree(screen_pt)
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	# точка під пальцем лишається на місці
	center = before - (screen_pt - size * 0.5) / zoom
	queue_redraw()


func zoom_center(factor: float) -> void:
	zoom_at(size * 0.5, factor)


# ---------- Введення ----------

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
	_drag = true   # щипок — не дотик до вузла


func _update_pinch() -> void:
	var pts: Array = _touches.values()
	var dist := maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
	var mid := ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	var local_mid := mid - global_position
	zoom_at(local_mid, dist / _pinch_dist)
	center -= (mid - _pinch_mid) / zoom     # пересування двома пальцями
	_pinch_dist = dist
	_pinch_mid = mid
	queue_redraw()


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
			else:
				if _press and not _drag and _touches.size() < 2:
					_tap(mb.position)
				_press = false
				_drag = false
			accept_event()
	elif event is InputEventMouseMotion and _press:
		var mm := event as InputEventMouseMotion
		if _touches.size() >= 2:
			return
		if not _drag and mm.position.distance_to(_press_pos) > TAP_SLOP:
			_drag = true
		if _drag:
			center -= mm.relative / zoom
			queue_redraw()
		accept_event()


## Вибір вузла за дотиком: найближчий у межах радіуса + запас на палець.
func pick(screen_pt: Vector2) -> String:
	var best := ""
	var bd := 1.0e9
	for id in PerkTree.nodes().keys():
		var r := maxf(_node_r(id) * zoom, 18.0) + 14.0
		var d := to_screen(PerkTree.pos(id)).distance_to(screen_pt)
		if d < r and d < bd:
			bd = d
			best = id
	return best


func _tap(p: Vector2) -> void:
	var id := pick(p)
	if id != "":
		selected = id
		node_selected.emit(id)
		queue_redraw()


# ---------- Малювання ----------

func _node_r(id: String) -> float:
	return float(RADIUS.get(PerkTree.get_def(id).get("type", "small"), 22.0))


func _icon_for(id: String) -> Texture2D:
	var d := PerkTree.get_def(id)
	var key := str(d.get("icon", ""))
	var type := str(d.get("type", "small"))
	var ck := "%s|%s|%s|%s" % [key, type, d.get("region", ""), d.get("skill", "")]
	if _icon_cache.has(ck):
		return _icon_cache[ck]
	var tex: Texture2D = null
	if key != "":
		tex = Icons.texture(key)
	if tex == null:
		if type == "core":
			tex = Icons.texture("perk_core")
		elif type == "skill" and str(d.get("skill", "")) != "":
			tex = Icons.texture(Icons.skill_icon_id(str(d["skill"]), GameState.blessing))
		if tex == null and type in ["notable", "keystone", "start", "skill"]:
			tex = Icons.texture(str(REGION_ICONS.get(str(d.get("region", "")), "")))
	_icon_cache[ck] = tex
	return tex


func _state(id: String) -> int:
	# 2 — відкрито, 1 — можна взяти (сусід відкритого), 0 — закрито
	if GameState.is_unlocked(id):
		return 2
	for nb in PerkTree.neighbors(id):
		if GameState.is_unlocked(str(nb)):
			return 1
	return 0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("120E0F"))
	var view := Rect2(Vector2.ZERO, size).grow(80.0)
	# м'які плями регіонів
	for rg in PerkTree.regions():
		var rid := str(rg.get("id", ""))
		var col := Color(str(rg.get("color", "#888888")))
		var st := PerkTree.class_start(_class_of_region(rid))
		if st != "":
			var sp := to_screen(PerkTree.pos(st) * 0.62)
			draw_circle(sp, 620.0 * zoom, Color(col, 0.05))
			draw_circle(sp, 380.0 * zoom, Color(col, 0.05))
	# зв'язки
	for l in PerkTree.links():
		var a := to_screen(PerkTree.pos(l[0]))
		var b := to_screen(PerkTree.pos(l[1]))
		if not view.has_point(a) and not view.has_point(b):
			continue
		var sa := _state(l[0])
		var sb := _state(l[1])
		var col2 := Color(Palette.TEXT_DIM, 0.28)
		var w := 3.0
		if sa == 2 and sb == 2:
			col2 = Palette.GOLD
			w = 5.0
		elif sa == 2 or sb == 2:
			col2 = Color(Palette.LINEN, 0.7)
			w = 4.0
		draw_line(a, b, col2, maxf(1.5, w * zoom * 1.3), true)
	# вузли
	for id in PerkTree.nodes().keys():
		var p := to_screen(PerkTree.pos(id))
		if not view.has_point(p):
			continue
		_draw_node(id, p)
	# підписи регіонів
	var font := ThemeDB.fallback_font
	for rg in PerkTree.regions():
		var rid := str(rg.get("id", ""))
		var st := PerkTree.class_start(_class_of_region(rid))
		if st == "":
			continue
		var sp2 := to_screen(PerkTree.pos(st) + PerkTree.pos(st).normalized() * 120.0)
		var fs := int(clampf(34.0 * zoom + 10.0, 16.0, 40.0))
		var txt := str(rg.get("name", ""))
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tp := sp2 - Vector2(ts.x * 0.5, 0)
		draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Palette.NIGHT)
		draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(str(rg.get("color", "#cccccc"))).lightened(0.2))


func _class_of_region(region_id: String) -> String:
	for c in Gear.CLASS_IDS:
		if str(Gear.class_def(c).get("region", "")) == region_id:
			return c
	return ""


func _draw_node(id: String, p: Vector2) -> void:
	var d := PerkTree.get_def(id)
	var type := str(d.get("type", "small"))
	var r := maxf(_node_r(id) * zoom, 6.0)
	var state := _state(id)
	var col := PerkTree.color_of(id)
	var tex := _icon_for(id)
	var dim := 1.0 if state > 0 else 0.45
	if tex != null:
		var ir := r * 0.88   # значок на ~12% менший за коло: кінчики не зрізаються маскою
		var dd := ir * 2.0
		draw_circle(p, r + 2.0, Color(Palette.NIGHT, 0.9))
		draw_texture_rect(tex, Rect2(p - Vector2(ir, ir), Vector2(dd, dd)), false, Color(dim, dim, dim, 1.0) if state > 0 else Color(0.38, 0.38, 0.42, 1.0))
	else:
		var fill := col.darkened(0.15) if state == 2 else Palette.PANEL_LIGHT.lerp(col, 0.2)
		if state == 0:
			fill = Palette.PANEL.lerp(col, 0.12)
		draw_circle(p, r, fill)
		if type == "small" and zoom > 0.42:
			var txt := PerkTree.badge(id)
			var fs := int(clampf(r * 0.95, 11.0, 28.0))
			var font := ThemeDB.fallback_font
			var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(font, p + Vector2(-ts.x * 0.5, fs * 0.33), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95 if state > 0 else 0.45))
	# обідок за станом
	var ring := Palette.TEXT_DIM.darkened(0.3)
	var rw := 2.5
	if state == 2:
		ring = Palette.GOLD
		rw = 4.0
	elif state == 1:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		ring = Palette.LINEN.lerp(Palette.TURQUOISE.lightened(0.3), pulse)
		rw = 3.5
	draw_arc(p, r + 1.5, 0.0, TAU, 28, ring, maxf(1.5, rw * minf(1.0, zoom + 0.4)), true)
	if type == "keystone":
		draw_arc(p, r + 6.0 * minf(1.0, zoom + 0.3), 0.0, TAU, 28, Color(ring, 0.6), 2.0, true)
	if id == selected:
		draw_arc(p, r + 9.0, 0.0, TAU, 32, Color(1, 1, 1, 0.95), 3.0, true)
	# назва під значущими вузлами
	if zoom > 0.55 and type != "small":
		var font2 := ThemeDB.fallback_font
		var nm := str(d.get("name", ""))
		var fs2 := int(clampf(15.0 + zoom * 6.0, 14.0, 22.0))
		var ts2 := font2.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		var tp := p + Vector2(-ts2.x * 0.5, r + fs2 + 6.0)
		draw_string_outline(font2, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 5, Palette.NIGHT)
		draw_string(font2, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Palette.LINEN if state > 0 else Palette.TEXT_DIM)
