## Смужка життя / чару / звитяги з написом «значення / максимум».
class_name StatBar
extends Control

var value := 1.0
var max_value := 1.0
var fill_color := Palette.HP_COLOR
var caption := ""
var font_size := 18


func _init(p_color: Color = Palette.HP_COLOR, p_caption: String = "", h: float = 28.0) -> void:
	fill_color = p_color
	caption = p_caption
	custom_minimum_size = Vector2(240, h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(v: float, m: float) -> void:
	value = v
	max_value = maxf(m, 0.001)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Palette.NIGHT
	bg.border_color = Palette.GOLD.darkened(0.15)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	draw_style_box(bg, r)
	var ratio := clampf(value / max_value, 0.0, 1.0)
	if ratio > 0.0:
		var f := StyleBoxFlat.new()
		f.bg_color = fill_color
		f.set_corner_radius_all(6)
		draw_style_box(f, Rect2(Vector2(3, 3), Vector2((size.x - 6.0) * ratio, size.y - 6.0)))
	var txt := "%s %d / %d" % [caption, int(ceil(value)), int(ceil(max_value))]
	var font := ThemeDB.fallback_font
	var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2((size.x - ts.x) * 0.5, (size.y + ts.y) * 0.5 - font.get_descent(font_size))
	draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Palette.NIGHT)
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.LINEN)
