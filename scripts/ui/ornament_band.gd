## Смужка вишивки: плитка з арту (band_top), а якщо арту немає — намальовані ромби.
class_name OrnamentBand
extends Control

var color_a := Palette.EMBROIDERY
var color_b := Palette.GOLD
var cell := 18.0
var bottom := false


func _init(h: float = 22.0, p_bottom: bool = false) -> void:
	custom_minimum_size.y = h
	bottom = p_bottom
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var tex := FolkTheme.art_texture(FolkTheme.UI_DIR + ("band_bottom.png" if bottom else "band_top.png"))
	if tex != null:
		_draw_art(tex)
		return
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


## Плитка зберігає пропорції візерунку (без розтягування): ціла кількість повторів на ширину.
## Малюнок один раз зменшується до висоти смужки (так виходить чіткіше, ніж стискати на льоту).
static var _cache: Dictionary = {}


func _draw_art(tex: Texture2D) -> void:
	var th := maxi(4, int(round(size.y)))
	var key := "%s_%d" % [tex.resource_path, th]
	var small: ImageTexture = _cache.get(key)
	if small == null:
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var tw := maxi(4, int(round(float(img.get_width()) * float(th) / float(img.get_height()))))
		img.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		small = ImageTexture.create_from_image(img)
		_cache[key] = small
	var tile_w := float(small.get_width())
	var n := maxi(1, int(round(size.x / tile_w)))
	var w := size.x / float(n)
	for i in range(n):
		draw_texture_rect(small, Rect2(float(i) * w, 0, w, size.y), false)
