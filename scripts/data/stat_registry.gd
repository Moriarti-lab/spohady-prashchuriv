## Єдиний реєстр характеристик для гри та редактора Древа.
## Джерело: res://data/stat_registry.json. Не «оживлює» display_only ключі.
class_name StatRegistry

const PATH := "res://data/stat_registry.json"
const LABEL_WIRED := ""
const LABEL_EXPERIMENTAL := "експериментально / без ефекту в бою"

static var _loaded := false
static var _by_id: Dictionary = {}  # id -> Dictionary
static var _order: Array = []       # ids


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_by_id.clear()
	_order.clear()
	if not FileAccess.file_exists(PATH):
		push_warning("StatRegistry: немає %s" % PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("StatRegistry: битий JSON")
		return
	var entries: Array = parsed.get("entries", [])
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var id := str(e.get("id", ""))
		if id == "":
			continue
		_by_id[id] = e
		_order.append(id)


static func has_stat(id: String) -> bool:
	ensure_loaded()
	return _by_id.has(id)


static func get_entry(id: String) -> Dictionary:
	ensure_loaded()
	return _by_id.get(id, {})


static func all_ids() -> Array:
	ensure_loaded()
	return _order.duplicate()


static func tree_node_ids() -> Array:
	ensure_loaded()
	var out: Array = []
	for id in _order:
		var a: Array = _by_id[id].get("applies_to", [])
		if "tree_node" in a or a.is_empty():
			# weapon_field / nauz_mod alone — skip for tree node editor list
			var mech := str(_by_id[id].get("mechanics", ""))
			if mech == "weapon_field" or mech == "nauz_mod":
				continue
			out.append(id)
	return out


static func is_wired(id: String) -> bool:
	return str(get_entry(id).get("mechanics", "")) == "wired"


static func is_display_only(id: String) -> bool:
	return str(get_entry(id).get("mechanics", "")) == "display_only"


static func ua_template(id: String) -> String:
	var e := get_entry(id)
	if e.has("ua_template"):
		return str(e["ua_template"])
	if PerkTree.STAT_TEXT.has(id):
		return str(PerkTree.STAT_TEXT[id])
	return "%s"


static func ua_short(id: String) -> String:
	var e := get_entry(id)
	var s := str(e.get("ua_short", ""))
	if s != "":
		return s
	return id


static func editor_label(id: String) -> String:
	## Підпис у редакторі: українська назва + мітка, якщо не wired.
	var short := ua_short(id)
	if short == "" or short == id:
		var t := ua_template(id)
		short = t.replace("%s%%", "%").replace("%s", "").strip_edges()
		if short == "":
			short = id
	if is_wired(id):
		return short
	if is_display_only(id):
		return "%s (%s)" % [short, LABEL_EXPERIMENTAL]
	var mech := str(get_entry(id).get("mechanics", ""))
	if mech == "nauz_mod":
		return "%s (мод наузів/ниток)" % short
	if mech == "weapon_field":
		return "%s (поле зброї)" % short
	return "%s (%s)" % [short, LABEL_EXPERIMENTAL]


static func mechanics_badge(id: String) -> String:
	if is_wired(id):
		return "у бою"
	if is_display_only(id):
		return LABEL_EXPERIMENTAL
	return str(get_entry(id).get("mechanics", "?"))
