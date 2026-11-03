## Спільні стилі інтерфейсу: тепла народна палітра, вишиті орнаменти.
class_name FolkTheme

const ICON_DIR := "res://art/icons/"
const PORTRAIT_DIR := "res://art/portraits/"
const UI_DIR := "res://art/ui/"


static func panel_style(bg: Color = Palette.PANEL, border: Color = Palette.GOLD, bw: int = 3, radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func apply_button(b: Button, base: Color = Palette.EMBROIDERY, font_size: int = 28) -> void:
	b.add_theme_stylebox_override("normal", panel_style(base, Palette.GOLD, 3, 12))
	b.add_theme_stylebox_override("hover", panel_style(base.lightened(0.12), Palette.GOLD, 3, 12))
	b.add_theme_stylebox_override("pressed", panel_style(base.darkened(0.2), Palette.LINEN, 3, 12))
	b.add_theme_stylebox_override("disabled", panel_style(Palette.PANEL_LIGHT, Palette.TEXT_DIM.darkened(0.4), 2, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Palette.LINEN)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.LINEN)
	b.add_theme_color_override("font_disabled_color", Palette.TEXT_DIM.darkened(0.3))
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 64.0)


static func label(text: String, size: int = 24, color: Color = Palette.LINEN,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.NIGHT)
	l.add_theme_constant_override("outline_size", 3 if size >= 22 else 2)
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static var _frame_cache := {}


## Дерев'яна рамка з арту (9-patch). scale — у скільки разів зменшити кути (щоб не з'їдали екран).
static func frame_style(scale: float = 0.5, fill: Color = Color(0, 0, 0, 0)) -> StyleBox:
	var key := "%s|%s" % [scale, fill.to_html()]
	if _frame_cache.has(key):
		return _frame_cache[key]
	var tex := art_texture(UI_DIR + "frame_wood.png")
	var out: StyleBox
	if tex == null:
		out = panel_style(Palette.PANEL, Palette.GOLD, 3, 14)
	else:
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var w := int(round(img.get_width() * scale))
		img.resize(w, w, Image.INTERPOLATE_LANCZOS)
		var sb := StyleBoxTexture.new()
		sb.texture = ImageTexture.create_from_image(img)
		var m := 56.0 * scale
		sb.texture_margin_left = m
		sb.texture_margin_right = m
		sb.texture_margin_top = m
		sb.texture_margin_bottom = m
		var cm := m * 0.72
		sb.content_margin_left = cm
		sb.content_margin_right = cm
		sb.content_margin_top = cm
		sb.content_margin_bottom = cm
		out = sb
	_frame_cache[key] = out
	return out


static func art_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			return r
	return null


static func fullscreen(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
