## Живі кольори теми: гра й редактор читають звідси; Palette лишається дефолтом.
class_name ThemeRuntime
extends Object

static var panel: Color = Color("2A2222")
static var panel_light: Color = Color("3A2E2C")
static var accent: Color = Color("E0A526")
static var text: Color = Color("F2EBDD")
static var text_dim: Color = Color("B9AE9A")
static var embroidery: Color = Color("B3261E")
static var night: Color = Color("1E1A1A")
static var hp: Color = Color("C7352B")
static var mana: Color = Color("2AA8A2")
static var stat_colors: Dictionary = {
	"str": Color("D8574B"),
	"agi": Color("7CBF5A"),
	"faith": Color("E0A526"),
}
static var loaded: bool = false


static func reset() -> void:
	panel = Color("2A2222")
	panel_light = Color("3A2E2C")
	accent = Color("E0A526")
	text = Color("F2EBDD")
	text_dim = Color("B9AE9A")
	embroidery = Color("B3261E")
	night = Color("1E1A1A")
	hp = Color("C7352B")
	mana = Color("2AA8A2")
	stat_colors = {
		"str": Color("D8574B"),
		"agi": Color("7CBF5A"),
		"faith": Color("E0A526"),
	}


static func apply_store(store) -> void:
	## store — ThemeStore (без typed-ref, щоб не було циклічної залежності class_name).
	panel = store.panel
	panel_light = store.panel_light
	accent = store.accent
	text = store.text
	text_dim = store.text_dim
	embroidery = store.embroidery
	night = store.night
	hp = store.hp
	mana = store.mana
	stat_colors = store.stat_colors.duplicate()
	loaded = true


static func apply_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	var store = load("res://scripts/editor/theme/theme_store.gd").new()
	if store.from_dict(d) == "":
		apply_store(store)


static func load_overrides_if_any() -> void:
	var path := "user://overrides/theme.json"
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return
	apply_dict(data)
