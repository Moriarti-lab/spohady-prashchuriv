## Універсальна розкладка UI: екрани → елементи з якорями. Формат сумісний з ui_layout.json.
class_name LayoutStore
extends RefCounted

signal changed

const DRAFT_PATH := "user://editor_drafts/ui_layout.json"
const MAX_UNDO := 60

var version: int = 1
var canvas_w: float = 1560.0
var canvas_h: float = 720.0
## screen_id -> {id, title, elements: Array[Dictionary]}
var screens: Dictionary = {}

var _undo: Array = []
var _redo: Array = []


func ensure_defaults() -> void:
	if screens.has("hud"):
		return
	screens["hud"] = _default_hud()
	# інші екрани — лише реєстрація без фейкових кнопок «скоро»
	push_undo()


func _default_hud() -> Dictionary:
	return {
		"id": "hud",
		"title": "HUD",
		"elements": [
			{"id": "portrait_panel", "type": "panel", "text": "Портрет",
				"a": {"l": "l", "t": "t", "r": "l", "b": "t"},
				"o": {"l": 16, "t": 16, "r": 320, "b": 140}, "z": 2, "locked": false, "visible": true},
			{"id": "minimap", "type": "minimap", "text": "Карта",
				"a": {"l": "r", "t": "t", "r": "r", "b": "t"},
				"o": {"l": -180, "t": 16, "r": -16, "b": 150}, "z": 2, "locked": false, "visible": true},
			{"id": "stick", "type": "joystick", "text": "Хід",
				"a": {"l": "l", "t": "b", "r": "l", "b": "b"},
				"o": {"l": 40, "t": -220, "r": 200, "b": -40}, "z": 5, "locked": false, "visible": true},
			{"id": "attack", "type": "attack", "text": "Удар",
				"a": {"l": "r", "t": "b", "r": "r", "b": "b"},
				"o": {"l": -216, "t": -206, "r": -56, "b": -46},
				"ring": {"dist": 156, "angles": [172, 212, 252, 292]},
				"z": 5, "locked": false, "visible": true},
			{"id": "potion_hp", "type": "button", "text": "Життя",
				"a": {"l": "r", "t": "b", "r": "r", "b": "b"},
				"o": {"l": -320, "t": -120, "r": -240, "b": -40}, "z": 4, "locked": false, "visible": true},
			{"id": "potion_mana", "type": "button", "text": "Чар",
				"a": {"l": "r", "t": "b", "r": "r", "b": "b"},
				"o": {"l": -400, "t": -120, "r": -320, "b": -40}, "z": 4, "locked": false, "visible": true},
			{"id": "menu", "type": "button", "text": "Меню",
				"a": {"l": "l", "t": "t", "r": "l", "b": "t"},
				"o": {"l": 16, "t": 160, "r": 120, "b": 220}, "z": 3, "locked": false, "visible": true},
		],
	}


func list_screen_ids() -> Array:
	var keys: Array = screens.keys()
	keys.sort()
	return keys


func screen_title(id: String) -> String:
	var s = screens.get(id, {})
	return str(s.get("title", id))


func get_elements(screen_id: String) -> Array:
	var s = screens.get(screen_id, {})
	return s.get("elements", [])


func set_elements(screen_id: String, els: Array) -> void:
	if not screens.has(screen_id):
		screens[screen_id] = {"id": screen_id, "title": screen_id, "elements": []}
	screens[screen_id]["elements"] = els
	changed.emit()


func push_undo() -> void:
	_undo.append(to_dict())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()


func undo() -> bool:
	if _undo.size() < 2:
		return false
	_redo.append(_undo.pop_back())
	var snap: Dictionary = _undo.back()
	from_dict(snap)
	changed.emit()
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var snap: Dictionary = _redo.pop_back()
	_undo.append(snap)
	from_dict(snap)
	changed.emit()
	return true


func to_dict() -> Dictionary:
	var arr: Array = []
	for id in list_screen_ids():
		arr.append(screens[id].duplicate(true))
	return {
		"version": version,
		"canvas": {"w": canvas_w, "h": canvas_h},
		"screens": arr,
	}


func from_dict(d: Dictionary) -> String:
	if d.is_empty():
		return "Порожня розкладка."
	version = int(d.get("version", 1))
	var c = d.get("canvas", {})
	if typeof(c) == TYPE_DICTIONARY:
		canvas_w = float(c.get("w", 1560))
		canvas_h = float(c.get("h", 720))
	screens.clear()
	var arr = d.get("screens", [])
	if typeof(arr) != TYPE_ARRAY:
		return "Немає списку екранів."
	for s in arr:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var sid := str(s.get("id", ""))
		if sid == "":
			continue
		screens[sid] = s.duplicate(true)
	if screens.is_empty():
		return "У розкладці немає жодного екрана."
	changed.emit()
	return ""


func save_draft() -> String:
	DirAccess.make_dir_recursive_absolute("user://editor_drafts")
	var f := FileAccess.open(DRAFT_PATH, FileAccess.WRITE)
	if f == null:
		return "Не вдалося зберегти розкладку."
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return ""


func load_draft() -> String:
	if not FileAccess.file_exists(DRAFT_PATH):
		ensure_defaults()
		return ""
	var f := FileAccess.open(DRAFT_PATH, FileAccess.READ)
	if f == null:
		return "Не вдалося прочитати розкладку."
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return "Розкладка пошкоджена."
	var err := from_dict(data)
	if err != "":
		return err
	if _undo.is_empty():
		push_undo()
	return ""


## Перевірки для екрана: [{level, msg, element_id}]
func check_screen(screen_id: String, phone_w: float = 1560.0, phone_h: float = 720.0) -> Array:
	var out: Array = []
	var els: Array = get_elements(screen_id)
	var rects: Array = []
	for el in els:
		if not el.get("visible", true):
			continue
		var r := element_rect(el, phone_w, phone_h)
		rects.append({"id": str(el.get("id", "")), "r": r})
		if r.position.x < -2 or r.position.y < -2 or r.end.x > phone_w + 2 or r.end.y > phone_h + 2:
			out.append({"level": "warn", "msg": "«%s» вилазить за екран." % el.get("id"), "element_id": el.get("id")})
		if r.size.x < 48 or r.size.y < 48:
			out.append({"level": "warn", "msg": "«%s» замалий для пальця (%.0f×%.0f)." % [el.get("id"), r.size.x, r.size.y], "element_id": el.get("id")})
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if rects[i]["r"].intersects(rects[j]["r"]):
				var inter: Rect2 = rects[i]["r"].intersection(rects[j]["r"])
				if inter.get_area() > 400:
					out.append({"level": "info", "msg": "Перетин «%s» і «%s»." % [rects[i]["id"], rects[j]["id"]], "element_id": rects[i]["id"]})
	return out


func element_rect(el: Dictionary, phone_w: float, phone_h: float) -> Rect2:
	var a: Dictionary = el.get("a", {})
	var o: Dictionary = el.get("o", {})
	var left := _edge(a.get("l", "l"), o.get("l", 0), phone_w, true)
	var right := _edge(a.get("r", "r"), o.get("r", 100), phone_w, true)
	var top := _edge(a.get("t", "t"), o.get("t", 0), phone_h, false)
	var bot := _edge(a.get("b", "b"), o.get("b", 100), phone_h, false)
	# якщо якорі однакові — o задає позицію+розмір як l,t,r,b offsets від того ж краю
	if str(a.get("l", "l")) == str(a.get("r", "r")):
		var base := _anchor_pos(str(a.get("l", "l")), phone_w, true)
		left = base + float(o.get("l", 0))
		right = base + float(o.get("r", 100))
	if str(a.get("t", "t")) == str(a.get("b", "b")):
		var basey := _anchor_pos(str(a.get("t", "t")), phone_h, false)
		top = basey + float(o.get("t", 0))
		bot = basey + float(o.get("b", 100))
	if right < left:
		var tmp := left; left = right; right = tmp
	if bot < top:
		var tmp2 := top; top = bot; bot = tmp2
	return Rect2(left, top, max(1.0, right - left), max(1.0, bot - top))


func _anchor_pos(code: String, span: float, horiz: bool) -> float:
	match code:
		"l", "t":
			return 0.0
		"c", "m":
			return span * 0.5
		"r", "b":
			return span
		_:
			return 0.0


func _edge(code: Variant, off: Variant, span: float, horiz: bool) -> float:
	return _anchor_pos(str(code), span, horiz) + float(off)
