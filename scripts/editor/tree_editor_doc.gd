## Модель чернетки Древа в пам’яті: вузли/зв’язки, undo, валідація, фон (t76).
## Не чіпає сейви героя. Schema дерева = perk_tree.json; фон лише в project meta.
class_name TreeEditorDoc

signal changed
signal selection_changed(id: String)

const MAX_UNDO := 80
const MIN_SPACING := 180.0  # world units після ×10
const BG_MAX_SIDE := 2048

var title: String = "Чернетка Древа"
var comment: String = ""
var tree_meta: Dictionary = {}
var regions: Array = []
var class_starts: Dictionary = {}
var nodes: Dictionary = {}   # id -> Dictionary
var links: Array = []        # [id_a, id_b]
var selected_id: String = ""

# Background (world-space). origin = top-left corner in tree coords.
var bg_visible: bool = true
var bg_opacity: float = 0.55
var bg_lock: bool = true
var bg_preserve_aspect: bool = true
var bg_origin: Vector2 = Vector2(-4000, -2000)
var bg_size: Vector2 = Vector2(8000, 10000)  # width, height in world units
var bg_image: Image = null
var bg_texture: ImageTexture = null
var bg_pixel_size: Vector2i = Vector2i.ZERO
var bg_rel_file: String = "bg.png"  # relative name inside draft folder

var _undo: Array = []  # snapshots
var _redo: Array = []
var _suspend_undo: bool = false


func clear() -> void:
	nodes.clear()
	links.clear()
	regions.clear()
	class_starts.clear()
	selected_id = ""
	_clear_bg_image()
	_undo.clear()
	_redo.clear()


func load_from_tree_dict(data: Dictionary) -> Array:
	## Повертає список помилок (порожній = ок). Не чіпає фон.
	var errs: Array = []
	if str(data.get("format", "")) != PerkTree.FORMAT and data.has("format"):
		errs.append("Невідомий format: %s" % data.get("format"))
	nodes.clear()
	links.clear()
	regions = data.get("regions", []).duplicate(true)
	class_starts = data.get("class_starts", {}).duplicate(true)
	title = str(data.get("title", title))
	comment = str(data.get("comment", ""))
	var m = data.get("meta", {})
	tree_meta = m.duplicate(true) if typeof(m) == TYPE_DICTIONARY else {}
	var raw_nodes = data.get("nodes", [])
	if typeof(raw_nodes) == TYPE_ARRAY:
		for n in raw_nodes:
			if typeof(n) != TYPE_DICTIONARY:
				continue
			var id := str(n.get("id", ""))
			if id == "":
				continue
			nodes[id] = n.duplicate(true)
	elif typeof(raw_nodes) == TYPE_DICTIONARY:
		for id in raw_nodes.keys():
			var n: Dictionary = raw_nodes[id].duplicate(true)
			n["id"] = str(id)
			nodes[str(id)] = n
	for l in data.get("links", []):
		if typeof(l) == TYPE_ARRAY and l.size() >= 2:
			links.append([str(l[0]), str(l[1])])
	_undo.clear()
	_redo.clear()
	_push_undo_silent()
	changed.emit()
	return errs


func to_tree_dict() -> Dictionary:
	var arr: Array = []
	for id in nodes.keys():
		var n: Dictionary = nodes[id].duplicate(true)
		n["id"] = id
		arr.append(n)
	arr.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	var out := {
		"format": PerkTree.FORMAT,
		"version": PerkTree.VERSION,
		"title": title,
		"comment": comment,
		"regions": regions.duplicate(true),
		"class_starts": class_starts.duplicate(true),
		"nodes": arr,
		"links": links.duplicate(true),
	}
	if not tree_meta.is_empty():
		out["meta"] = tree_meta.duplicate(true)
	return out


func project_meta() -> Dictionary:
	return {
		"background": {
			"file": bg_rel_file if bg_image != null else "",
			"origin_x": bg_origin.x,
			"origin_y": bg_origin.y,
			"width": bg_size.x,
			"height": bg_size.y,
			"opacity": bg_opacity,
			"visible": bg_visible,
			"lock_transform": bg_lock,
			"preserve_aspect": bg_preserve_aspect,
		}
	}


func apply_project_meta(meta: Dictionary) -> void:
	var bg: Dictionary = meta.get("background", {})
	if bg.is_empty():
		return
	bg_rel_file = str(bg.get("file", bg_rel_file))
	bg_origin = Vector2(float(bg.get("origin_x", bg_origin.x)), float(bg.get("origin_y", bg_origin.y)))
	bg_size = Vector2(float(bg.get("width", bg_size.x)), float(bg.get("height", bg_size.y)))
	bg_opacity = clampf(float(bg.get("opacity", bg_opacity)), 0.0, 1.0)
	bg_visible = bool(bg.get("visible", bg_visible))
	bg_lock = bool(bg.get("lock_transform", bg_lock))
	bg_preserve_aspect = bool(bg.get("preserve_aspect", bg_preserve_aspect))


func set_background_image(img: Image, rel_name: String = "bg.png") -> void:
	if img == null or img.is_empty():
		_clear_bg_image()
		changed.emit()
		return
	var work := img.duplicate()
	var side := maxi(work.get_width(), work.get_height())
	if side > BG_MAX_SIDE:
		var s := float(BG_MAX_SIDE) / float(side)
		work.resize(maxi(1, int(work.get_width() * s)), maxi(1, int(work.get_height() * s)), Image.INTERPOLATE_LANCZOS)
	bg_image = work
	bg_pixel_size = Vector2i(work.get_width(), work.get_height())
	bg_rel_file = rel_name
	if bg_texture == null:
		bg_texture = ImageTexture.create_from_image(work)
	else:
		bg_texture.set_image(work)
	if bg_preserve_aspect and bg_pixel_size.x > 0:
		var aspect := float(bg_pixel_size.y) / float(bg_pixel_size.x)
		bg_size.y = bg_size.x * aspect
	changed.emit()


func _clear_bg_image() -> void:
	bg_image = null
	bg_texture = null
	bg_pixel_size = Vector2i.ZERO


func bg_corners_world() -> PackedVector2Array:
	return PackedVector2Array([
		bg_origin,
		bg_origin + Vector2(bg_size.x, 0),
		bg_origin + bg_size,
		bg_origin + Vector2(0, bg_size.y),
	])


func set_bg_width(w: float) -> void:
	if bg_lock:
		return
	w = maxf(1.0, w)
	bg_size.x = w
	if bg_preserve_aspect and bg_pixel_size.x > 0:
		bg_size.y = w * float(bg_pixel_size.y) / float(bg_pixel_size.x)
	_commit()


func set_bg_height(h: float) -> void:
	if bg_lock:
		return
	h = maxf(1.0, h)
	bg_size.y = h
	if bg_preserve_aspect and bg_pixel_size.y > 0:
		bg_size.x = h * float(bg_pixel_size.x) / float(bg_pixel_size.y)
	_commit()


func set_bg_origin(o: Vector2) -> void:
	if bg_lock:
		return
	bg_origin = o
	_commit()


func snapshot() -> Dictionary:
	return {
		"tree": to_tree_dict(),
		"selected_id": selected_id,
		"bg": project_meta(),
		# image not cloned every undo — only transform meta; image swaps are separate
	}


func _push_undo_silent() -> void:
	_undo.append(snapshot())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()


func _commit() -> void:
	if _suspend_undo:
		changed.emit()
		return
	_redo.clear()
	_push_undo_silent()
	changed.emit()


func undo() -> bool:
	if _undo.size() < 2:
		return false
	var cur = _undo.pop_back()
	_redo.append(cur)
	var prev: Dictionary = _undo.back()
	_restore(prev)
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var s: Dictionary = _redo.pop_back()
	_undo.append(s)
	_restore(s)
	return true


func _restore(s: Dictionary) -> void:
	_suspend_undo = true
	load_from_tree_dict(s.get("tree", {}))
	apply_project_meta(s.get("bg", {}))
	selected_id = str(s.get("selected_id", ""))
	_suspend_undo = false
	# keep last undo entry as current
	changed.emit()
	selection_changed.emit(selected_id)


func select(id: String) -> void:
	selected_id = id
	selection_changed.emit(id)
	changed.emit()


func get_node(id: String) -> Dictionary:
	return nodes.get(id, {})


func set_node_field(id: String, key: String, value: Variant) -> void:
	if not nodes.has(id):
		return
	nodes[id][key] = value
	_commit()


func set_node_pos(id: String, pos: Vector2) -> void:
	if not nodes.has(id):
		return
	nodes[id]["x"] = pos.x
	nodes[id]["y"] = pos.y
	_commit()


func set_node_stat(id: String, key: String, value: float) -> void:
	if not nodes.has(id):
		return
	var st: Dictionary = nodes[id].get("stats", {})
	if typeof(st) != TYPE_DICTIONARY:
		st = {}
	if is_zero_approx(value):
		st.erase(key)
	else:
		st[key] = value
	nodes[id]["stats"] = st
	_commit()


func add_link(a: String, b: String) -> bool:
	if a == b or not nodes.has(a) or not nodes.has(b):
		return false
	for l in links:
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			return false
	links.append([a, b])
	_commit()
	return true


func remove_link(a: String, b: String) -> void:
	for i in range(links.size() - 1, -1, -1):
		var l = links[i]
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			links.remove_at(i)
	_commit()


func pos_of(id: String) -> Vector2:
	var n := get_node(id)
	return Vector2(float(n.get("x", 0)), float(n.get("y", 0)))


func search(q: String) -> Array:
	q = q.strip_edges().to_lower()
	var out: Array = []
	if q == "":
		return out
	for id in nodes.keys():
		var n: Dictionary = nodes[id]
		var hay := ("%s %s %s" % [id, n.get("name", ""), n.get("description", "")]).to_lower()
		if hay.find(q) >= 0:
			out.append(id)
	out.sort()
	return out


func validate() -> Array:
	## Повертає масив рядків помилок/попереджень. Помилки починаються з «ПОМИЛКА:».
	StatRegistry.ensure_loaded()
	var errs: Array = []
	var seen: Dictionary = {}
	for id in nodes.keys():
		if seen.has(id):
			errs.append("ПОМИЛКА: дубль id «%s»" % id)
		seen[id] = true
		var n: Dictionary = nodes[id]
		var t := str(n.get("type", ""))
		if t != "" and t not in PerkTree.NODE_TYPES:
			errs.append("ПОМИЛКА: %s: невідомий type «%s»" % [id, t])
		var st = n.get("stats", {})
		if typeof(st) == TYPE_DICTIONARY:
			for k in st.keys():
				if not StatRegistry.has_stat(str(k)) and not PerkTree.STAT_TEXT.has(str(k)):
					errs.append("ПОМИЛКА: %s: невідомий бонус «%s»" % [id, k])
	for l in links:
		if not nodes.has(l[0]) or not nodes.has(l[1]):
			errs.append("ПОМИЛКА: зв’язок %s—%s: вузол відсутній" % [l[0], l[1]])
	for cls in class_starts.keys():
		var sid := str(class_starts[cls])
		if sid != "" and not nodes.has(sid):
			errs.append("ПОМИЛКА: class_starts[%s]=%s — немає вузла" % [cls, sid])
	# connectivity warning
	if not nodes.is_empty() and not links.is_empty():
		var start := str(nodes.keys()[0])
		for c in class_starts.values():
			if nodes.has(str(c)):
				start = str(c)
				break
		var adj: Dictionary = {}
		for id in nodes.keys():
			adj[id] = []
		for l in links:
			if adj.has(l[0]) and adj.has(l[1]):
				adj[l[0]].append(l[1])
				adj[l[1]].append(l[0])
		var stack: Array = [start]
		var vis: Dictionary = {start: true}
		while not stack.is_empty():
			var u = stack.pop_back()
			for v in adj.get(u, []):
				if not vis.has(v):
					vis[v] = true
					stack.append(v)
		var orphan := nodes.size() - vis.size()
		if orphan > 0:
			errs.append("УВАГА: %d вузлів поза компонентою від «%s»" % [orphan, start])
	# spacing warning (sample)
	var ids: Array = nodes.keys()
	var warn_n := 0
	for i in range(mini(ids.size(), 200)):
		var a: String = ids[i]
		var pa := pos_of(a)
		for j in range(i + 1, mini(ids.size(), i + 40)):
			var b: String = ids[j]
			if pa.distance_to(pos_of(b)) < MIN_SPACING * 0.35:
				warn_n += 1
				if warn_n <= 5:
					errs.append("УВАГА: вузли %s і %s дуже близько" % [a, b])
	return errs
