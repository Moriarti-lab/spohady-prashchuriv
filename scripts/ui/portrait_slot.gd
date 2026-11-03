## Квадратне місце під портрет. Якщо файл портрета є в res://art/portraits, показує його,
## інакше малює вишитий ромб із літерою (плейсхолдер).
class_name PortraitSlot
extends Control

var texture: Texture2D = null
var accent := Palette.GOLD
var letter := "?"


func _init(sz: Vector2 = Vector2(96, 96)) -> void:
	custom_minimum_size = sz
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Портрет героя: res://art/portraits/hero_<клас>.png (256×256).
func set_portrait(blessing_id: String, class_id: String) -> void:
	texture = FolkTheme.art_texture(FolkTheme.PORTRAIT_DIR + "hero_%s.png" % class_id)
	accent = Blessings.get_def(blessing_id).get("color", Palette.GOLD)
	letter = GameState.hero_name.substr(0, 1).to_upper() if GameState.hero_name != "" else "?"
	queue_redraw()


## Довільне зображення (наприклад, портрет бога).
## fit_height > 0: слот підлаштовується під пропорції малюнка (висота фіксована).
func set_art(path: String, p_accent: Color, p_letter: String, fit_height: float = 0.0) -> void:
	texture = FolkTheme.art_texture(path)
	accent = p_accent
	letter = p_letter
	if texture != null and fit_height > 0.0:
		var aspect := float(texture.get_width()) / float(texture.get_height())
		custom_minimum_size = Vector2(fit_height * aspect + 8.0, fit_height + 8.0)
	elif fit_height > 0.0:
		custom_minimum_size = Vector2(fit_height * 0.75, fit_height)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Palette.NIGHT
	bg.border_color = Palette.GOLD
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	draw_style_box(bg, r)
	if texture != null:
		var inner := r.grow(-4.0)
		var ta := float(texture.get_width()) / float(texture.get_height())
		var dst := inner
		if inner.size.x / inner.size.y > ta:
			dst.size.x = inner.size.y * ta
			dst.position.x += (inner.size.x - dst.size.x) * 0.5
		else:
			dst.size.y = inner.size.x / ta
			dst.position.y += (inner.size.y - dst.size.y) * 0.5
		draw_texture_rect(texture, dst, false)
		var frame := StyleBoxFlat.new()
		frame.draw_center = false
		frame.border_color = Palette.GOLD
		frame.set_border_width_all(3)
		frame.set_corner_radius_all(10)
		draw_style_box(frame, r)
		return
	var c := size * 0.5
	var rad := minf(size.x, size.y) * 0.36
	var d := PackedVector2Array([c + Vector2(0, -rad), c + Vector2(rad, 0), c + Vector2(0, rad), c + Vector2(-rad, 0)])
	draw_colored_polygon(d, Palette.EMBROIDERY.darkened(0.2))
	draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), Palette.GOLD, 3.0)
	draw_circle(c, rad * 0.62, accent.darkened(0.15))
	var font := ThemeDB.fallback_font
	var fs := int(rad * 0.95)
	var ts := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var p := Vector2(c.x - ts.x * 0.5, c.y + ts.y * 0.3)
	draw_string_outline(font, p, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Palette.NIGHT)
	draw_string(font, p, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.LINEN)
