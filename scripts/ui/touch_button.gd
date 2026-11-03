## Кругла сенсорна кнопка (атака, навички): підпис, перезарядка, брак чару.
class_name TouchButton
extends Control

var radius := 50.0
var center := Vector2.ZERO
var text := ""
var sub_text := ""
var color := Palette.EMBROIDERY
var cooldown := 0.0      # 0..1, частка перезарядки, що лишилась
var usable := true       # вистачає чару
var empty := false       # у слоті немає навички
var pressed := false
var icon: Texture2D = null
var font_size := 22


func _init(p_radius: float = 50.0, p_color: Color = Palette.EMBROIDERY) -> void:
	radius = p_radius
	color = p_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func place(c: Vector2) -> void:
	center = c
	position = c - Vector2(radius, radius)
	size = Vector2(radius, radius) * 2.0
	queue_redraw()


func hit(p: Vector2, slack: float = 1.15) -> bool:
	return p.distance_to(center) <= radius * slack


func set_pressed(v: bool) -> void:
	if pressed != v:
		pressed = v
		queue_redraw()


func _draw() -> void:
	var c := Vector2(radius, radius)
	var base := color
	if empty:
		base = Palette.PANEL_LIGHT
	elif not usable:
		base = color.darkened(0.55)
	if pressed:
		base = base.lightened(0.2)
	draw_circle(c, radius, Color(base, 0.85))
	if icon != null:
		var tint := Color.WHITE
		if empty:
			tint = Color(1, 1, 1, 0.3)
		elif not usable:
			tint = Color(0.45, 0.45, 0.5, 1.0)
		elif pressed:
			tint = Color(1.25, 1.25, 1.25, 1.0)
		var d := (radius - 3.0) * 2.0
		draw_texture_rect(icon, Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), false, tint)
	draw_arc(c, radius - 2.0, 0.0, TAU, 40, Palette.GOLD if not empty else Palette.TEXT_DIM.darkened(0.3), 4.0)
	draw_arc(c, radius - 10.0, 0.0, TAU, 36, Color(Palette.LINEN, 0.25), 2.0)
	var font := ThemeDB.fallback_font
	if icon != null:
		# з малюнком: лише ціна чару внизу кола
		if sub_text != "":
			var fs3 := int(font_size * 0.72)
			var ts3 := font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3)
			var p3 := Vector2(c.x - ts3.x * 0.5, c.y + radius * 0.74)
			draw_string_outline(font, p3, sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, 6, Palette.NIGHT)
			draw_string(font, p3, sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, Palette.MANA_COLOR.lightened(0.5))
		_draw_cooldown(c)
		return
	var fs := font_size
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var ty := c.y + ts.y * 0.25
	if sub_text != "":
		ty -= 8.0
	var p := Vector2(c.x - ts.x * 0.5, ty)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Palette.NIGHT)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.LINEN)
	if sub_text != "":
		var fs2 := int(fs * 0.7)
		var ts2 := font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		var p2 := Vector2(c.x - ts2.x * 0.5, ty + fs2 + 6.0)
		draw_string_outline(font, p2, sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 4, Palette.NIGHT)
		draw_string(font, p2, sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Palette.MANA_COLOR.lightened(0.4))
	_draw_cooldown(c)


func _draw_cooldown(c: Vector2) -> void:
	if cooldown > 0.0:
		var pts := PackedVector2Array([c])
		var a0 := -PI * 0.5
		var a1 := a0 + TAU * cooldown
		var steps := maxi(3, int(40.0 * cooldown))
		for i in range(steps + 1):
			var a := lerpf(a0, a1, float(i) / float(steps))
			pts.append(c + Vector2(cos(a), sin(a)) * (radius - 3.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
