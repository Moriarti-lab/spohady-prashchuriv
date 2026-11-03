## Віртуальний джойстик (ліворуч унизу). Малює лише вигляд; дотики веде Hud.
class_name TouchStick
extends Control

const BASE_RADIUS := 100.0
const KNOB_RADIUS := 46.0

var base_center := Vector2(180, 560)
var knob_offset := Vector2.ZERO
var active := false
## Місце спокою, коли палець не торкається.
var home := Vector2(180, 560)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(pos: Vector2) -> void:
	active = true
	base_center = pos
	knob_offset = Vector2.ZERO
	queue_redraw()


func drag(pos: Vector2) -> Vector2:
	var off := pos - base_center
	if off.length() > BASE_RADIUS:
		off = off.normalized() * BASE_RADIUS
	knob_offset = off
	queue_redraw()
	return off / BASE_RADIUS


func end() -> void:
	active = false
	knob_offset = Vector2.ZERO
	base_center = home
	queue_redraw()


func _draw() -> void:
	var a := 0.75 if active else 0.5
	draw_circle(base_center, BASE_RADIUS, Color(Palette.NIGHT, 0.45 * a + 0.1))
	draw_arc(base_center, BASE_RADIUS, 0.0, TAU, 40, Color(Palette.GOLD, a), 4.0)
	draw_arc(base_center, BASE_RADIUS - 14.0, 0.0, TAU, 40, Color(Palette.EMBROIDERY, a * 0.8), 3.0)
	# чотири «ромби» напрямків
	for i in range(4):
		var ang := float(i) * PI * 0.5
		var c := base_center + Vector2(cos(ang), sin(ang)) * (BASE_RADIUS - 28.0)
		var pts := PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0)])
		draw_colored_polygon(pts, Color(Palette.LINEN, a * 0.7))
	var k := base_center + knob_offset
	draw_circle(k, KNOB_RADIUS, Color(Palette.EMBROIDERY, 0.85 if active else 0.6))
	draw_arc(k, KNOB_RADIUS, 0.0, TAU, 32, Color(Palette.GOLD, 0.95), 4.0)
	draw_circle(k, KNOB_RADIUS * 0.35, Color(Palette.GOLD, 0.8))
