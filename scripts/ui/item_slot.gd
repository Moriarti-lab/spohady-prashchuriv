## Клітинка сумки або слот спорядження: рамка за рідкістю, малюнок предмета, номер рівня.
class_name ItemSlot
extends Control

signal tapped(slot: ItemSlot)

var index := -1                 # номер у сумці (або -1 для слота спорядження)
var equip_slot := ""            # "weapon" / "armor" / "amulet" / "ring" для слотів спорядження
var item: Dictionary = {}
var selected := false
var caption := ""               # підпис порожнього слота спорядження
var _press_pos := Vector2.ZERO
var _down := false


func _init(sz: float = 84.0) -> void:
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_item(it: Variant) -> void:
	item = it if typeof(it) == TYPE_DICTIONARY else {}
	queue_redraw()


func is_empty() -> bool:
	return item.is_empty()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_down = true
			_press_pos = mb.position
		else:
			if _down and mb.position.distance_to(_press_pos) < 24.0 and Rect2(Vector2.ZERO, size).has_point(mb.position):
				tapped.emit(self)
			_down = false
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var col := Items.rarity_color(item) if not item.is_empty() else Palette.TEXT_DIM.darkened(0.35)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("1A1514") if item.is_empty() else Color("1A1514").lerp(col, 0.18)
	bg.border_color = col if not item.is_empty() else Palette.PANEL_LIGHT
	bg.set_border_width_all(3 if not item.is_empty() else 2)
	bg.set_corner_radius_all(8)
	draw_style_box(bg, r)
	if selected:
		var sel := StyleBoxFlat.new()
		sel.draw_center = false
		sel.border_color = Color.WHITE
		sel.set_border_width_all(4)
		sel.set_corner_radius_all(9)
		draw_style_box(sel, r.grow(1.0))
	var c := size * 0.5
	if item.is_empty():
		if equip_slot != "":
			_draw_glyph(equip_slot, "", c, minf(size.x, size.y) * 0.28, Color(Palette.TEXT_DIM, 0.35))
			if caption != "":
				_text(caption, Vector2(size.x * 0.5, size.y - 8.0), 15, Palette.TEXT_DIM, true)
		return
	var slot := Items.slot_of(item)
	var kind := ""
	if slot == "weapon":
		kind = str(Items.weapon_def(item).get("kind", "melee"))
	_draw_glyph(slot, kind, c + Vector2(0, -3), minf(size.x, size.y) * 0.3, col.lightened(0.1))
	_text("%d" % int(item.get("ilvl", 1)), Vector2(size.x - 8.0, size.y - 7.0), 16, col.lightened(0.25), false, true)


func _text(t: String, p: Vector2, fs: int, col: Color, centered: bool = false, right: bool = false) -> void:
	var font := ThemeDB.fallback_font
	var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := p
	if centered:
		pos.x -= ts.x * 0.5
	elif right:
		pos.x -= ts.x
	draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Palette.NIGHT)
	draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Простий значок предмета, намальований лініями (шрифт не має потрібних символів).
func _draw_glyph(slot: String, kind: String, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(3.0, r * 0.18)
	match slot:
		"weapon":
			match kind:
				"arrow":
					var pts := PackedVector2Array()
					for i in range(13):
						var a := lerpf(-PI * 0.5, PI * 0.5, float(i) / 12.0)
						pts.append(c + Vector2(cos(a) * r * 0.55 - r * 0.25, sin(a) * r))
					draw_polyline(pts, col, w, true)
					draw_line(pts[0], pts[12], Color(col, 0.7), maxf(1.5, w * 0.4), true)
					draw_line(c + Vector2(-r * 0.3, 0), c + Vector2(r * 0.9, 0), col, w * 0.7, true)
				"magic":
					draw_line(c + Vector2(-r * 0.7, r), c + Vector2(r * 0.4, -r * 0.6), col, w, true)
					draw_circle(c + Vector2(r * 0.55, -r * 0.8), r * 0.3, col)
				_:
					draw_line(c + Vector2(-r * 0.75, r * 0.75), c + Vector2(r * 0.75, -r * 0.8), col, w * 1.3, true)
					draw_line(c + Vector2(-r * 0.15, r * 0.15) + Vector2(-r * 0.28, -r * 0.28), c + Vector2(-r * 0.15, r * 0.15) + Vector2(r * 0.28, r * 0.28), col, w, true)
					draw_line(c + Vector2(-r * 0.75, r * 0.75), c + Vector2(-r * 0.95, r * 0.95), col.darkened(0.2), w * 1.5, true)
		"armor":
			var sh := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.8, r * 0.1), c + Vector2(0, r), c + Vector2(-r * 0.8, r * 0.1)])
			draw_colored_polygon(sh, Color(col, 0.35))
			draw_polyline(PackedVector2Array([sh[0], sh[1], sh[2], sh[3], sh[4], sh[0]]), col, w, true)
			draw_line(c + Vector2(0, -r * 0.8), c + Vector2(0, r * 0.9), Color(col, 0.7), w * 0.6, true)
		"amulet":
			draw_arc(c + Vector2(0, -r * 0.2), r * 0.85, PI * 1.05, PI * 1.95, 20, Color(col, 0.7), w * 0.6, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.1), c + Vector2(r * 0.4, r * 0.55), c + Vector2(0, r), c + Vector2(-r * 0.4, r * 0.55)]), col)
		_:
			draw_arc(c + Vector2(0, r * 0.15), r * 0.65, 0.0, TAU, 24, col, w * 1.2, true)
			draw_circle(c + Vector2(0, -r * 0.55), r * 0.25, col)
