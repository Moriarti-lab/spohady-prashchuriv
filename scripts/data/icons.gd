## Реєстр іконок: icon_id → малюнок. Дані в res://data/icons.json:
##   {"icons": {"w_sword": {"path": "res://art/icons/weapons/w_sword.png", "label": "Меч", "color": "#B0B8C0"}, ...}}
## Якщо файлу немає, малюється кольорова заглушка з коротким написом. Щоб додати арт БЕЗ зміни коду:
## поклади PNG у art/icons/<будь-яка-папка>/<icon_id>.png (або впиши path у icons.json).
class_name Icons

const REGISTRY_PATH := "res://data/icons.json"
const AUTO_DIRS := ["weapons", "armor", "items", "skills", "passives", "perks", "extra", ""]

static var _loaded := false
static var _reg: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _missing: Dictionary = {}


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_reg = {}
	if not FileAccess.file_exists(REGISTRY_PATH):
		return
	var f := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("icons", null)) == TYPE_DICTIONARY:
		_reg = parsed["icons"]


static func ids() -> Array:
	ensure_loaded()
	return _reg.keys()


static func has_id(id: String) -> bool:
	ensure_loaded()
	return _reg.has(id)


static func entry(id: String) -> Dictionary:
	ensure_loaded()
	var e: Variant = _reg.get(id, {})
	return e if typeof(e) == TYPE_DICTIONARY else {}


## Текстура іконки або null, якщо арту ще немає.
static func texture(id: String) -> Texture2D:
	if id == "":
		return null
	ensure_loaded()
	if _tex_cache.has(id):
		return _tex_cache[id]
	var tex: Texture2D = null
	var path := str(entry(id).get("path", ""))
	if path != "" and ResourceLoader.exists(path):
		var r: Variant = load(path)
		if r is Texture2D:
			tex = r
	if tex == null:
		for d in AUTO_DIRS:
			var p: String = "res://art/icons/%s%s.png" % [(d + "/") if d != "" else "", id]
			if ResourceLoader.exists(p):
				var r2: Variant = load(p)
				if r2 is Texture2D:
					tex = r2
					break
	_tex_cache[id] = tex
	return tex


static func has_art(id: String) -> bool:
	return texture(id) != null


## Іконка навички. «Хвиля стихії» залежить від благословення; «Подих Стрибога» має власну.
static func skill_icon_id(skill_id: String, blessing: String = "") -> String:
	if skill_id == "element_wave" and blessing != "":
		if blessing == "stribog":
			return "sk_stribog_dash"
		var bid := "sk_element_wave_" + blessing
		if has_id(bid) or has_art(bid):
			return bid
	var d: Dictionary = Skills.get_def(skill_id)
	return str(d.get("icon", "sk_" + skill_id))


static func label_of(id: String, fallback: String = "") -> String:
	var l := str(entry(id).get("label", ""))
	if l == "":
		l = fallback
	return l


static func color_of(id: String) -> Color:
	var c := str(entry(id).get("color", ""))
	if c != "":
		return Color(c)
	# стабільний колір із хешу назви
	var h := absi(id.hash())
	return Color.from_hsv(float(h % 360) / 360.0, 0.35, 0.55)


## Малює іконку в прямокутник. Без арту: кольорова заглушка + підпис.
## inset — частка зменшення всередині (0.12 = на 12% з кожного боку). circle — обрізати кругом (фон-заглушка).
static func draw(ci: CanvasItem, id: String, rect: Rect2, fallback_label: String = "", inset: float = 0.0, tint: Color = Color.WHITE) -> void:
	var r := rect.grow(-minf(rect.size.x, rect.size.y) * inset)
	var tex := texture(id)
	if tex != null:
		ci.draw_texture_rect(tex, r, false, tint)
		return
	draw_placeholder(ci, id, r, fallback_label)


static func draw_placeholder(ci: CanvasItem, id: String, r: Rect2, fallback_label: String = "") -> void:
	var col := color_of(id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.45)
	sb.border_color = col.lightened(0.15)
	sb.set_border_width_all(maxi(2, int(r.size.x * 0.04)))
	sb.set_corner_radius_all(int(r.size.x * 0.22))
	ci.draw_style_box(sb, r)
	var txt := label_of(id, fallback_label)
	if txt == "":
		txt = id.get_slice("_", 1).left(2).to_upper()
	txt = short_label(txt)
	var font := ThemeDB.fallback_font
	var fs := maxi(10, int(r.size.x * (0.34 if txt.length() <= 3 else 0.24)))
	var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(r.position.x + (r.size.x - ts.x) * 0.5, r.position.y + (r.size.y + ts.y * 0.62) * 0.5)
	ci.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	ci.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))


## Скорочує підпис заглушки до 2–6 символів.
static func short_label(t: String) -> String:
	t = t.strip_edges()
	if t.length() <= 6:
		return t
	var words := t.split(" ", false)
	if words.size() >= 2:
		return (words[0].left(1) + words[1].left(1)).to_upper()
	return t.left(5)


## Готовий Control з іконкою (для списків UI).
static func make_control(id: String, size_px: float, fallback_label: String = "") -> Control:
	var c := IconControl.new()
	c.icon_id = id
	c.fallback = fallback_label
	c.custom_minimum_size = Vector2(size_px, size_px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


class IconControl:
	extends Control
	var icon_id := ""
	var fallback := ""
	var dim := false

	func _draw() -> void:
		Icons.draw(self, icon_id, Rect2(Vector2.ZERO, size), fallback, 0.0, Color(0.45, 0.45, 0.5, 0.9) if dim else Color.WHITE)
