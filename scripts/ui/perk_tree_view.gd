## Намальоване радіальне Древо: торкнись вузла, щоб обрати його.
class_name PerkTreeView
extends Control

signal node_selected(id: String)

const NODE_R := 30.0
const KEY_R := 37.0

var selected := ""
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(560, 560)
	clip_contents = true


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _center() -> Vector2:
	return size * 0.5


func _radius() -> float:
	return minf(size.x, size.y) * 0.5 - 84.0


func node_pos(id: String) -> Vector2:
	return _center() + PerkTree.unit_pos(id) * _radius()


func _node_color(d: Dictionary) -> Color:
	var parts: Array = []
	for st in ["str", "agi", "faith"]:
		if d.has(st):
			parts.append(Palette.STAT_COLORS[st])
	if parts.is_empty():
		return Palette.GOLD
	var c: Color = parts[0]
	for i in range(1, parts.size()):
		c = c.lerp(parts[i], 0.5)
	return c


func _gui_input(event: InputEvent) -> void:
	var p := Vector2.ZERO
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		p = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	else:
		return
	var best := ""
	var bd := 52.0
	for id in PerkTree.NODES.keys():
		var d := node_pos(id).distance_to(p)
		if d < bd:
			bd = d
			best = id
	if best != "":
		selected = best
		node_selected.emit(best)
		accept_event()
		queue_redraw()


func _draw() -> void:
	var c := _center()
	var R := _radius()
	# фон: коло й сектори
	draw_circle(c, R + 44.0, Color(Palette.NIGHT, 0.55))
	draw_arc(c, R + 44.0, 0.0, TAU, 72, Palette.GOLD.darkened(0.3), 3.0)
	draw_arc(c, R * 0.72, 0.0, TAU, 60, Color(Palette.LINEN, 0.08), 2.0)
	draw_arc(c, R * 0.45, 0.0, TAU, 48, Color(Palette.LINEN, 0.08), 2.0)
	var font := ThemeDB.fallback_font
	for sl in PerkTree.SECTOR_LABELS:
		var ang := deg_to_rad(float(sl["a"]))
		var lp := c + Vector2(cos(ang), sin(ang)) * (R + 56.0)
		var txt: String = sl["text"]
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		var col: Color = Palette.STAT_COLORS[sl["stat"]]
		var cx := cos(ang)
		var tp := lp - Vector2(ts.x * 0.5, -ts.y * 0.25)
		if cx > 0.3:
			tp.x = lp.x - 8.0
		elif cx < -0.3:
			tp.x = lp.x - ts.x + 8.0
		draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Palette.NIGHT)
		draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col.lightened(0.25))
	# зв'язки
	for id in PerkTree.NODES.keys():
		var a := node_pos(id)
		for other in PerkTree.NODES[id]["links"]:
			if other < id and PerkTree.NODES[other]["links"].has(id):
				continue
			var b := node_pos(other)
			var ua := GameState.is_unlocked(id)
			var ub := GameState.is_unlocked(other)
			if ua and ub:
				draw_line(a, b, Palette.GOLD, 7.0)
			elif ua or ub:
				draw_line(a, b, Palette.LINEN.darkened(0.2), 4.0)
			else:
				draw_line(a, b, Color(Palette.TEXT_DIM, 0.35), 3.0)
	# вузли
	for id in PerkTree.NODES.keys():
		_draw_node(id, font)


func _draw_node(id: String, font: Font) -> void:
	var d: Dictionary = PerkTree.NODES[id]
	var p := node_pos(id)
	var r := KEY_R if d.get("key", false) else NODE_R
	var unlocked := GameState.is_unlocked(id)
	var avail := GameState.can_unlock(id)
	var base := _node_color(d)
	var fill: Color
	if unlocked:
		fill = base
	elif avail:
		fill = base.darkened(0.55)
	else:
		fill = Palette.PANEL_LIGHT.darkened(0.2)
	draw_circle(p, r, fill)
	var ring := Palette.GOLD if unlocked else (Palette.LINEN if avail else Palette.TEXT_DIM.darkened(0.45))
	var rw := 5.0 if unlocked else 3.0
	if avail:
		rw = 3.0 + 2.0 * (0.5 + 0.5 * sin(_t * 5.0))
	draw_arc(p, r, 0.0, TAU, 28, ring, rw)
	if id == selected:
		draw_arc(p, r + 8.0, 0.0, TAU, 32, Palette.EMBROIDERY.lightened(0.3), 4.0)
	var icon := FolkTheme.art_texture(FolkTheme.ICON_DIR + "perks/%s.png" % id)
	if icon != null:
		draw_texture_rect(icon, Rect2(p - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), false)
		return
	var txt_col := Palette.LINEN if (unlocked or avail) else Palette.TEXT_DIM
	if d.has("skill"):
		_draw_star(p, r * 0.62, Palette.GOLD if (unlocked or avail) else Palette.TEXT_DIM)
	elif id == "core":
		draw_circle(p, r * 0.5, Palette.GOLD if unlocked else Palette.GOLD.darkened(0.4))
		for i in range(8):
			var ang := TAU * float(i) / 8.0
			draw_line(p + Vector2(cos(ang), sin(ang)) * r * 0.6, p + Vector2(cos(ang), sin(ang)) * r * 0.85, Palette.GOLD, 3.0)
	else:
		var total := 0
		for st in ["str", "agi", "faith"]:
			total += int(d.get(st, 0))
		var txt := "+%d" % total
		var fs := 22
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tp := p + Vector2(-ts.x * 0.5, ts.y * 0.3)
		draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Palette.NIGHT)
		draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt_col)


func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var rr := r if i % 2 == 0 else r * 0.45
		var ang := -PI * 0.5 + TAU * float(i) / 10.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array(pts + PackedVector2Array([pts[0]])), Palette.NIGHT, 2.0)
