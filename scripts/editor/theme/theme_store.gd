## Тема редактора/гри: кольори UI + кольори статів. Автозбереження чернеток.
class_name ThemeStore
extends RefCounted

signal changed

const DRAFT_PATH := "user://editor_drafts/theme.json"

var panel: Color = Color("2A2222")
var panel_light: Color = Color("3A2E2C")
var accent: Color = Color("E0A526")
var text: Color = Color("F2EBDD")
var text_dim: Color = Color("B9AE9A")
var embroidery: Color = Color("B3261E")
var night: Color = Color("1E1A1A")
var hp: Color = Color("8B1E1E")
var mana: Color = Color("4FC3F7")
var stat_colors: Dictionary = {
	"str": Color("C62828"),
	"agi": Color("2E7D32"),
	"faith": Color("E0A526"),
}


func reset_to_defaults() -> void:
	panel = Color("2A2222")
	panel_light = Color("3A2E2C")
	accent = Color("E0A526")
	text = Color("F2EBDD")
	text_dim = Color("B9AE9A")
	embroidery = Color("B3261E")
	night = Color("1E1A1A")
	hp = Color("8B1E1E")
	mana = Color("4FC3F7")
	stat_colors = {"str": Color("C62828"), "agi": Color("2E7D32"), "faith": Color("E0A526")}
	changed.emit()


func to_dict() -> Dictionary:
	var sc := {}
	for k in stat_colors:
		sc[k] = _c2h(stat_colors[k])
	return {
		"version": 1,
		"panel": _c2h(panel),
		"panel_light": _c2h(panel_light),
		"accent": _c2h(accent),
		"text": _c2h(text),
		"text_dim": _c2h(text_dim),
		"embroidery": _c2h(embroidery),
		"night": _c2h(night),
		"hp": _c2h(hp),
		"mana": _c2h(mana),
		"stat_colors": sc,
	}


func from_dict(d: Dictionary) -> String:
	## Повертає текст помилки або "".
	if d.is_empty():
		return "Порожня тема."
	panel = _h2c(str(d.get("panel", _c2h(panel))), panel)
	panel_light = _h2c(str(d.get("panel_light", _c2h(panel_light))), panel_light)
	accent = _h2c(str(d.get("accent", _c2h(accent))), accent)
	text = _h2c(str(d.get("text", _c2h(text))), text)
	text_dim = _h2c(str(d.get("text_dim", _c2h(text_dim))), text_dim)
	embroidery = _h2c(str(d.get("embroidery", _c2h(embroidery))), embroidery)
	night = _h2c(str(d.get("night", _c2h(night))), night)
	hp = _h2c(str(d.get("hp", _c2h(hp))), hp)
	mana = _h2c(str(d.get("mana", _c2h(mana))), mana)
	var sc = d.get("stat_colors", {})
	if typeof(sc) == TYPE_DICTIONARY:
		for k in sc.keys():
			stat_colors[str(k)] = _h2c(str(sc[k]), stat_colors.get(str(k), Color.WHITE))
	changed.emit()
	return ""


func save_draft() -> String:
	DirAccess.make_dir_recursive_absolute("user://editor_drafts")
	var f := FileAccess.open(DRAFT_PATH, FileAccess.WRITE)
	if f == null:
		return "Не вдалося зберегти тему: %s" % FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return ""


func load_draft() -> String:
	if not FileAccess.file_exists(DRAFT_PATH):
		return ""
	var f := FileAccess.open(DRAFT_PATH, FileAccess.READ)
	if f == null:
		return "Не вдалося прочитати тему."
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return "Тема пошкоджена."
	return from_dict(data)


func apply_to_palette() -> void:
	## Під час гри/прев’ю: пише в ThemeRuntime (Palette — лише константи-дефолти).
	ThemeRuntime.apply_store(self)


static func _c2h(c: Color) -> String:
	return c.to_html(false)


static func _h2c(h: String, fallback: Color) -> Color:
	var s := h.strip_edges()
	if s.begins_with("#"):
		s = s.substr(1)
	if s.length() < 6:
		return fallback
	return Color.html("#" + s)
