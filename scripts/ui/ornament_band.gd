## Смужка вишивки (ромби й хрестики): прикраса заголовків і панелей.
class_name OrnamentBand
extends Control

var color_a := Palette.EMBROIDERY
var color_b := Palette.GOLD
var cell := 18.0


func _init(h: float = 22.0) -> void:
	custom_minimum_size.y = h
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var h := size.y
	var cy := h * 0.5
	var r := minf(cell * 0.5, h * 0.5) - 1.0
	var n := int(size.x / cell)
	var x0 := (size.x - float(n) * cell) * 0.5
	for i in range(n):
		var cx := x0 + (float(i) + 0.5) * cell
		var d := PackedVector2Array([Vector2(cx, cy - r), Vector2(cx + r, cy), Vector2(cx, cy + r), Vector2(cx - r, cy)])
		draw_colored_polygon(d, color_a)
		draw_circle(Vector2(cx, cy), r * 0.28, color_b)
	draw_line(Vector2(0, 1), Vector2(size.x, 1), color_b, 2.0)
	draw_line(Vector2(0, h - 1), Vector2(size.x, h - 1), color_b, 2.0)
