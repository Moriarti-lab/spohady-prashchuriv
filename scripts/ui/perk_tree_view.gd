## Намальоване Древо звитяги з JSON: перетягування пальцем, щипок/колесо для масштабу, дотик обирає вузол.
class_name PerkTreeView
extends Control

signal node_selected(id: String)
signal empty_tapped

const ZOOM_MIN := 0.12
const ZOOM_MAX := 1.7
const TAP_SLOP := 14.0
const RADIUS := {"small": 20.0, "notable": 38.0, "keystone": 48.0, "skill": 34.0, "start": 40.0, "core": 56.0}
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
	else:
		selected = ""
		empty_tapped.emit()
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
	# без великих напівпрозорих кіл під корінням
	# зв'язки: кора + відтінок регіону; товстіші в стовбурі, тонші в кроні
	for l in PerkTree.links():
		var a := to_screen(PerkTree.pos(l[0]))
		var b := to_screen(PerkTree.pos(l[1]))
		if not view.has_point(a) and not view.has_point(b):
			continue
		var sa := _state(l[0])
		var sb := _state(l[1])
		var pa := PerkTree.pos(l[0])
		var pb := PerkTree.pos(l[1])
		var mid_x := (pa.x + pb.x) * 0.5
		var mid_y := (pa.y + pb.y) * 0.5
		var trunkness := clampf(1.0 - absf(mid_x) / 220.0, 0.0, 1.0)
		# вище (менший y) → тонше; стовбур у середній смузі — найтовстіший
		var height_t := clampf((1200.0 - mid_y) / 3200.0, 0.0, 1.0)
		var w := lerpf(2.2, 22.0, trunkness * trunkness * (1.0 - height_t * 0.45))
		var bark := Color("4A3224")
		var bark_hi := Color("6B4A35")
		var reg_col := _region_color(l[0]).lerp(_region_color(l[1]), 0.5)
		var col2 := bark.lerp(reg_col, 0.38)
		col2.a = 0.88
		if sa == 2 and sb == 2:
			col2 = bark_hi.lerp(Palette.GOLD, 0.5)
			col2.a = 0.95
			w += 2.0
		elif sa == 2 or sb == 2:
			col2 = bark.lerp(Palette.LINEN, 0.3)
			col2.a = 0.85
			w += 1.0
		# кора: темна підкладка + кольоровий шар
		# товщина стовбура майже не залежить від зуму на mid-zoom
		var zf := clampf(zoom, 0.42, 1.2)
		var ww := maxf(2.0, w * zf * (1.55 if trunkness > 0.5 else 1.15))
		if trunkness > 0.4:
			var under := Color(bark.r, bark.g, bark.b, 0.7)
			_draw_branch(a, b, under, ww * 1.45)
		_draw_branch(a, b, col2, ww)
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



func _region_color(id: String) -> Color:
	var d := PerkTree.get_def(id)
	var rid := str(d.get("region", ""))
	for rg in PerkTree.regions():
		if str(rg.get("id", "")) == rid:
			return Color(str(rg.get("color", "#C9A227")))
	# fallback: attribute mix
	return PerkTree.color_of(id)


func _class_of_region(region_id: String) -> String:
	for c in Gear.CLASS_IDS:
		if str(Gear.class_def(c).get("region", "")) == region_id:
			return c
	return ""



func _draw_branch(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	# крива «гілка»: контрольна точка зміщена перпендикулярно до відрізка
	var mid := (a + b) * 0.5
	var d := b - a
	var len2 := d.length()
	if len2 < 2.0:
		draw_line(a, b, col, width, true)
		return
	var n := Vector2(-d.y, d.x).normalized()
	# вигин угору (до крони) + невеликий бічний
	var bend := clampf(len2 * 0.18, 10.0, 70.0 * zoom + 12.0)
	var up := -1.0 if (a.y + b.y) * 0.5 > size.y * 0.5 else 1.0
	# у просторі екрана «вгору» = менший y
	var ctrl := mid + n * (bend * 0.35 * signf(n.x + 0.001)) + Vector2(0, -bend * 0.85)
	var steps := clampi(int(len2 / (10.0 / maxf(zoom, 0.2))), 6, 24)
	var prev := a
	for i in range(1, steps + 1):
		var tt := float(i) / float(steps)
		var omt := 1.0 - tt
		var pt := omt * omt * a + 2.0 * omt * tt * ctrl + tt * tt * b
		draw_line(prev, pt, col, width, true)
		prev = pt


func _draw_node(id: String, p: Vector2) -> void:
	var d := PerkTree.get_def(id)
	var type := str(d.get("type", "small"))
	var r := maxf(_node_r(id) * zoom, 5.0)
	var state := _state(id)
	var col := _region_color(id)
	var tex := _icon_for(id)
	# стан: 0 замкнений (приглушений колір регіону), 1 доступний (яскравіше + світіння), 2 відкритий
	var fill: Color
	var ring: Color
	var rw := 2.2
	match state:
		2:
			fill = col
			ring = Palette.GOLD
			rw = 3.8
		1:
			fill = col.lightened(0.12)
			var pulse := 0.55 + 0.45 * sin(_t * 4.2)
			ring = Palette.LINEN.lerp(col.lightened(0.35), pulse)
			rw = 3.6
			# м'яке світіння доступного вузла
			draw_circle(p, r + 8.0 * zoom + 5.0, Color(col, 0.22 + 0.12 * pulse))
		_:
			fill = col.darkened(0.22).lerp(Color("1A1410"), 0.18)
			fill.a = 1.0
			ring = col.darkened(0.35)
			rw = 2.2
	# підкладка / іконка
	draw_circle(p, r + 1.5, Color(Palette.NIGHT, 0.85))
	if tex != null and type != "small":
		var ir := r * 0.86
		var dd := ir * 2.0
		var mod := Color(1, 1, 1, 1) if state == 2 else (Color(0.92, 0.92, 0.92, 1) if state == 1 else Color(0.45, 0.42, 0.4, 1))
		# легкий відтінок регіону під іконкою
		draw_circle(p, r, fill)
		draw_texture_rect(tex, Rect2(p - Vector2(ir, ir), Vector2(dd, dd)), false, mod)
	else:
		draw_circle(p, r, fill)
		if type == "small" and zoom > 0.45 and state > 0:
			var txt := PerkTree.badge(id)
			var fs := int(clampf(r * 0.95, 10.0, 26.0))
			var font := ThemeDB.fallback_font
			var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var tc := Color(1, 1, 1, 0.95 if state == 2 else 0.8)
			draw_string(font, p + Vector2(-ts.x * 0.5, fs * 0.33), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
	draw_arc(p, r + 1.5, 0.0, TAU, 28, ring, maxf(1.4, rw * minf(1.0, zoom + 0.35)), true)
	if type == "keystone" or type == "core":
		draw_arc(p, r + 6.0 * minf(1.0, zoom + 0.25), 0.0, TAU, 28, Color(ring, 0.55), 2.0, true)
	if type == "notable":
		draw_arc(p, r + 4.5 * minf(1.0, zoom + 0.25), 0.0, TAU, 24, Color(col, 0.45 if state > 0 else 0.2), 1.8, true)
	if id == selected:
		draw_arc(p, r + 10.0, 0.0, TAU, 32, Color(1, 1, 1, 0.95), 3.0, true)
	# підпис лише для великих вузлів при сильному зумі
	if zoom > 0.58 and type != "small":
		var font2 := ThemeDB.fallback_font
		var nm := str(d.get("name", ""))
		var fs2 := int(clampf(16.0 * zoom + 6.0, 12.0, 22.0))
		var ts2 := font2.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		var tp := p + Vector2(-ts2.x * 0.5, r + fs2 + 4.0)
		draw_string_outline(font2, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 5, Palette.NIGHT)
		draw_string(font2, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Palette.LINEN if state > 0 else Palette.TEXT_DIM)

