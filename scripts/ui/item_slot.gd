## Клітинка сумки або слот спорядження: рамка за рідкістю, малюнок предмета, номер рівня.
class_name ItemSlot
extends Control

signal tapped(slot: ItemSlot)

var index := -1                 # номер у сумці (або -1 для слота спорядження)
var equip_slot := ""            # main / off / head / hands / body / feet / ring1 / ring2 / amulet
var item: Dictionary = {}
var selected := false
var caption := ""               # підпис порожнього слота спорядження
var ghost: Dictionary = {}      # дворучна зброя в іншій руці: тьмяний відбиток у цьому слоті
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
	var area := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	if item.is_empty():
		if not ghost.is_empty():
			Icons.draw(self, Items.icon_of(ghost), area, "", 0.14, Color(1, 1, 1, 0.3))
			_text("2 руки", Vector2(size.x * 0.5, size.y - 8.0), 15, Palette.TEXT_DIM, true)
			return
		if equip_slot != "":
			var sid := Items.slot_icon(equip_slot)
			var tex := Icons.texture(sid)
			if tex != null:
				draw_texture_rect(tex, area.grow(-size.x * 0.16), false, Color(1, 1, 1, 0.22))
			if caption != "":
				_text(caption, Vector2(size.x * 0.5, size.y - 8.0), 15, Palette.TEXT_DIM, true)
		return
	Icons.draw(self, Items.icon_of(item), area, Items.TYPE_NAMES.get(Items.type_of(item), "?"), 0.14)
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
