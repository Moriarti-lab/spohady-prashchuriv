## Спільні віджети редактора (кнопки, статус, панелі).
class_name EditorChrome
extends Object

static func make_btn(text: String, color: Color = Palette.EMBROIDERY, font_size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	FolkTheme.apply_button(b, color, font_size)
	b.custom_minimum_size = Vector2(0, 52)
	return b


static func make_label(text: String, size: int = 20, color: Color = Palette.LINEN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func make_line(placeholder: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 48)
	e.add_theme_font_size_override("font_size", 20)
	return e


static func section(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var h := make_label(title, 26, Palette.GOLD)
	box.add_child(h)
	return box


static func hsep() -> HSeparator:
	var s := HSeparator.new()
	s.custom_minimum_size.y = 8
	return s
