## Древо звитяги. Дані живуть у res://data/perk_tree.json (формат: docs/perk_tree_format.md).
## Той самий формат пише редактор tools/tree-editor/index.html.
## Вузли: id, name, description, x, y, type, stats{}, skill, icon, region. Зв'язки: пари id.
class_name PerkTree

const FORMAT := "spohady-perk-tree"
const VERSION := 1
const TREE_PATH := "res://data/perk_tree.json"
const NODE_TYPES := ["small", "notable", "keystone", "skill", "start", "core"]
## Ключ бонусу -> шаблон тексту (%s — число зі знаком).
const STAT_TEXT := {
	"str": "%s Сили", "agi": "%s Спритності", "faith": "%s Віри",
	"hp": "%s до життя", "hp_pct": "%s%% до життя",
	"mana_pct": "%s%% до чару", "mana_regen": "%s до відновлення чару за секунду",
	"armor": "%s до броні", "dmg_pct": "%s%% до шкоди",
	"atk_speed_pct": "%s%% до швидкості атаки", "crit_pct": "%s%% до шансу крита",
	"move_pct": "%s%% до швидкості руху", "xp_pct": "%s%% до звитяги",
}
const STAT_ORDER := ["str", "agi", "faith", "hp", "hp_pct", "mana_pct", "mana_regen", "armor",
	"dmg_pct", "atk_speed_pct", "crit_pct", "move_pct", "xp_pct"]

static var _loaded := false
static var _data: Dictionary = {}
static var _nodes: Dictionary = {}
static var _adj: Dictionary = {}
static var _starts: Dictionary = {}
static var _regions: Array = []
static var _links: Array = []
static var load_errors: Array = []


# ---------- Завантаження ----------

static func ensure_loaded() -> void:
	if _loaded:
		return
	load_from_file()


## Читає res://data/perk_tree.json. Повертає список помилок (порожній — усе гаразд).
static func load_from_file(path: String = TREE_PATH) -> Array:
	_loaded = true
	var parsed: Variant = null
	if FileAccess.file_exists(path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		load_errors = ["Не вдалося прочитати %s" % path]
		push_error(load_errors[0])
		_apply({"nodes": [], "links": [], "class_starts": {}, "regions": []})
		return load_errors
	return apply_data(parsed)


## Застосовує словник (наприклад, з тесту). Помилки валідації повертає й записує в load_errors.
static func apply_data(data: Dictionary) -> Array:
	_loaded = true
	var res := validate(data)
	load_errors = res["errors"]
	if not load_errors.is_empty():
		for e in load_errors:
			push_error("Древо: " + str(e))
	_apply(data)
	return load_errors


static func _apply(data: Dictionary) -> void:
	_data = data
	_nodes = {}
	_adj = {}
	_links = []
	for n in data.get("nodes", []):
		if typeof(n) != TYPE_DICTIONARY or not n.has("id"):
			continue
		var d: Dictionary = (n as Dictionary).duplicate(true)
		var stats: Dictionary = {}
		var raw: Variant = d.get("stats", {})
		if typeof(raw) == TYPE_DICTIONARY:
			for k in raw.keys():
				if STAT_TEXT.has(str(k)):
					stats[str(k)] = float(raw[k])
		d["stats"] = stats
		d["x"] = float(d.get("x", 0))
		d["y"] = float(d.get("y", 0))
		d["type"] = str(d.get("type", "small"))
		d["skill"] = str(d.get("skill", ""))
		d["icon"] = str(d.get("icon", ""))
		d["description"] = str(d.get("description", ""))
		_nodes[str(d["id"])] = d
		_adj[str(d["id"])] = []
	for l in data.get("links", []):
		if typeof(l) == TYPE_ARRAY and (l as Array).size() == 2:
			var a := str(l[0])
			var b := str(l[1])
			if _nodes.has(a) and _nodes.has(b) and a != b and not (b in _adj[a]):
				_adj[a].append(b)
				_adj[b].append(a)
				_links.append([a, b])
	_starts = {}
	var cs: Variant = data.get("class_starts", {})
	if typeof(cs) == TYPE_DICTIONARY:
		for k in cs.keys():
			_starts[str(k)] = str(cs[k])
	_regions = data.get("regions", []) if typeof(data.get("regions", [])) == TYPE_ARRAY else []


# ---------- Перевірка (дзеркало перевірки в редакторі) ----------

## Повертає {"errors": [...], "warnings": [...]} українською.
static func validate(data: Variant) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	if typeof(data) != TYPE_DICTIONARY:
		return {"errors": ["Файл має бути JSON-об'єктом."], "warnings": []}
	var d: Dictionary = data
	if str(d.get("format", "")) != FORMAT:
		errors.append("Поле format має бути «%s»." % FORMAT)
	if typeof(d.get("version", null)) not in [TYPE_INT, TYPE_FLOAT] or int(d.get("version", 0)) != VERSION:
		errors.append("Поле version має бути %d." % VERSION)
	var nodes: Variant = d.get("nodes", null)
	if typeof(nodes) != TYPE_ARRAY or (nodes as Array).is_empty():
		errors.append("Список nodes порожній або відсутній.")
		return {"errors": errors, "warnings": warnings}
	var ids := {}
	var coords := {}
	for i in range((nodes as Array).size()):
		var n: Variant = nodes[i]
		var tag := "Вузол №%d" % (i + 1)
		if typeof(n) != TYPE_DICTIONARY:
			errors.append("%s: має бути об'єктом." % tag)
			continue
		var nd: Dictionary = n
		var id := str(nd.get("id", ""))
		if typeof(nd.get("id", null)) != TYPE_STRING or id == "":
			errors.append("%s: немає id." % tag)
			continue
		tag = "Вузол «%s»" % id
		if not _valid_id(id):
			errors.append("%s: id може містити лише латинські літери, цифри, _ та -." % tag)
		if ids.has(id):
			errors.append("%s: id повторюється." % tag)
		ids[id] = true
		if typeof(nd.get("name", null)) != TYPE_STRING or str(nd.get("name", "")).strip_edges() == "":
			errors.append("%s: порожня назва (name)." % tag)
		for ax in ["x", "y"]:
			if typeof(nd.get(ax, null)) not in [TYPE_INT, TYPE_FLOAT]:
				errors.append("%s: поле %s має бути числом." % [tag, ax])
		var typ := str(nd.get("type", ""))
		if typ not in NODE_TYPES:
			errors.append("%s: невідомий тип «%s» (дозволено: %s)." % [tag, typ, ", ".join(NODE_TYPES)])
		var st: Variant = nd.get("stats", {})
		if typeof(st) != TYPE_DICTIONARY:
			errors.append("%s: stats має бути об'єктом." % tag)
		else:
			for k in (st as Dictionary).keys():
				if not STAT_TEXT.has(str(k)):
					errors.append("%s: невідомий бонус «%s»." % [tag, str(k)])
				elif typeof(st[k]) not in [TYPE_INT, TYPE_FLOAT]:
					errors.append("%s: бонус «%s» має бути числом." % [tag, str(k)])
		var sk := str(nd.get("skill", ""))
		if sk != "" and not Skills.DATA.has(sk):
			errors.append("%s: невідома навичка «%s»." % [tag, sk])
		if typ == "skill" and sk == "":
			errors.append("%s: тип skill потребує поля skill." % tag)
		if typeof(nd.get("x", null)) in [TYPE_INT, TYPE_FLOAT] and typeof(nd.get("y", null)) in [TYPE_INT, TYPE_FLOAT]:
			var key := "%d,%d" % [int(round(float(nd["x"]))), int(round(float(nd["y"])))]
			if coords.has(key):
				warnings.append("Вузли «%s» і «%s» стоять в одній точці." % [coords[key], id])
			coords[key] = id
	# зв'язки
	var adj := {}
	for id in ids.keys():
		adj[id] = []
	var seen := {}
	var links: Variant = d.get("links", null)
	if typeof(links) != TYPE_ARRAY:
		errors.append("Список links відсутній.")
	else:
		for i in range((links as Array).size()):
			var l: Variant = links[i]
			var tag2 := "Зв'язок №%d" % (i + 1)
			if typeof(l) != TYPE_ARRAY or (l as Array).size() != 2:
				errors.append("%s: має бути парою [id, id]." % tag2)
				continue
			var a := str(l[0])
			var b := str(l[1])
			if not ids.has(a) or not ids.has(b):
				errors.append("%s: невідомий вузол (%s — %s)." % [tag2, a, b])
				continue
			if a == b:
				errors.append("%s: вузол з'єднано сам із собою («%s»)." % [tag2, a])
				continue
			var key2 := (a + "|" + b) if a < b else (b + "|" + a)
			if seen.has(key2):
				errors.append("%s: повтор зв'язку %s — %s." % [tag2, a, b])
				continue
			seen[key2] = true
			adj[a].append(b)
			adj[b].append(a)
	# стартові вузли класів
	var cs: Variant = d.get("class_starts", null)
	var start_ids: Array = []
	if typeof(cs) != TYPE_DICTIONARY:
		errors.append("Немає class_starts (стартових вузлів класів).")
	else:
		for c in Gear.CLASS_IDS:
			if not (cs as Dictionary).has(c):
				errors.append("class_starts: немає класу «%s»." % c)
			elif not ids.has(str(cs[c])):
				errors.append("class_starts: вузла «%s» (клас «%s») не існує." % [str(cs[c]), c])
			else:
				start_ids.append(str(cs[c]))
	# досяжність
	if errors.is_empty() and not start_ids.is_empty():
		var reach := {}
		var queue: Array = start_ids.duplicate()
		for s in queue:
			reach[s] = true
		while not queue.is_empty():
			var cur: String = queue.pop_back()
			for nb in adj[cur]:
				if not reach.has(nb):
					reach[nb] = true
					queue.append(nb)
		for id in ids.keys():
			if not reach.has(id):
				warnings.append("Вузол «%s» недосяжний з жодного старту." % id)
	return {"errors": errors, "warnings": warnings}


static func _valid_id(id: String) -> bool:
	for i in range(id.length()):
		var c := id.unicode_at(i)
		var okc := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95 or c == 45
		if not okc:
			return false
	return true


# ---------- Доступ ----------

static func nodes() -> Dictionary:
	ensure_loaded()
	return _nodes


static func has_node(id: String) -> bool:
	ensure_loaded()
	return _nodes.has(id)


static func get_def(id: String) -> Dictionary:
	ensure_loaded()
	return _nodes.get(id, {})


static func links() -> Array:
	ensure_loaded()
	return _links


static func regions() -> Array:
	ensure_loaded()
	return _regions


static func neighbors(id: String) -> Array:
	ensure_loaded()
	return _adj.get(id, [])


static func class_start(class_id: String) -> String:
	ensure_loaded()
	return str(_starts.get(class_id, ""))


static func pos(id: String) -> Vector2:
	ensure_loaded()
	var d: Dictionary = _nodes[id]
	return Vector2(float(d["x"]), float(d["y"]))


static func stat_of(id: String, key: String) -> float:
	ensure_loaded()
	return float(_nodes[id]["stats"].get(key, 0.0)) if _nodes.has(id) else 0.0


## Лишає тільки вузли, зʼєднані зі стартом через відкриті сусідні вузли.
static func sanitize_unlocked(list: Array, start: String) -> Array:
	ensure_loaded()
	var allowed := {}
	for id in list:
		if _nodes.has(str(id)):
			allowed[str(id)] = true
	if start == "" or not _nodes.has(start):
		return []
	var out: Array = [start]
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for nb in _adj[cur]:
			if allowed.has(nb) and not seen.has(nb):
				seen[nb] = true
				out.append(nb)
				queue.append(nb)
	return out


# ---------- Тексти ----------

static func stat_line(key: String, value: float) -> String:
	return str(STAT_TEXT[key]) % Strings.signed(value)


## Опис ефектів вузла українською: бонуси й навичка.
static func effect_text(id: String) -> String:
	ensure_loaded()
	if not _nodes.has(id):
		return ""
	var d: Dictionary = _nodes[id]
	var parts: Array = []
	for k in STAT_ORDER:
		if d["stats"].has(k) and not is_zero_approx(float(d["stats"][k])):
			parts.append(stat_line(k, float(d["stats"][k])))
	if d["skill"] != "" and Skills.DATA.has(d["skill"]):
		parts.append("Навичка: " + str(Skills.get_def(d["skill"])["name"]))
	return "\n".join(parts)


## Коротка позначка для кружечка вузла: сума характеристик або «%».
static func badge(id: String) -> String:
	ensure_loaded()
	var d: Dictionary = _nodes[id]
	var total := 0.0
	for st in ["str", "agi", "faith"]:
		total += float(d["stats"].get(st, 0.0))
	if total > 0.0:
		return "+%d" % int(round(total))
	return "%"


## Колір вузла за головною характеристикою.
static func color_of(id: String) -> Color:
	ensure_loaded()
	var d: Dictionary = _nodes[id]
	var parts: Array = []
	for st in ["str", "agi", "faith"]:
		if float(d["stats"].get(st, 0.0)) > 0.0:
			parts.append(Palette.STAT_COLORS[st])
	if parts.is_empty():
		return Palette.GOLD
	var c: Color = parts[0]
	for i in range(1, parts.size()):
		c = c.lerp(parts[i], 0.5)
	return c
