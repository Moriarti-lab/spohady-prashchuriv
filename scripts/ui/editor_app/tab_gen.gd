## Вкладка «Генерація»: seed → Древо на пристрої (фон + прогрес + скасування + прев’ю).
class_name EditorTabGen
extends ScrollContainer

var session: EditorSession
var _seed: LineEdit
var _progress: ProgressBar
var _log: Label
var _preview: Label
var _hint: Label
var _busy: bool = false
var _cancel_req: bool = false
var _gen_core = null
var _run_btn: Button
var _cancel_btn: Button
var _accept_btn: Button
var _pending_tree: Dictionary = {}
var _preview_canvas: Control
var _preview_host: PanelContainer


func setup(s: EditorSession) -> void:
	session = s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 20 if m != "margin_top" else 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(body)
	add_child(margin)

	body.add_child(EditorChrome.make_label("Генерація Древа", 30, Palette.GOLD))
	body.add_child(EditorChrome.make_label(
		"Нове Древо з будь-якого seed прямо на телефоні. Після розрахунку — прев’ю метрик і схеми, потім «Прийняти».",
		18, Palette.TEXT_DIM))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var seed_lbl := Label.new()
	seed_lbl.text = "Seed"
	seed_lbl.add_theme_font_size_override("font_size", 22)
	seed_lbl.add_theme_color_override("font_color", Palette.LINEN)
	seed_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	seed_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_lbl.custom_minimum_size = Vector2(70, 48)
	row.add_child(seed_lbl)
	_seed = EditorChrome.make_line("424242")
	_seed.text = "424242"
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed.custom_minimum_size = Vector2(160, 48)
	row.add_child(_seed)

	_run_btn = EditorChrome.make_btn("Згенерувати", Color("2E7D32"))
	_run_btn.pressed.connect(_on_run)
	row.add_child(_run_btn)
	_cancel_btn = EditorChrome.make_btn("Скасувати", Palette.EMBROIDERY)
	_cancel_btn.disabled = true
	_cancel_btn.pressed.connect(func():
		_cancel_req = true
		if _gen_core != null and _gen_core.has_method("request_cancel"):
			_gen_core.request_cancel()
		_log.text = "Скасування…")
	row.add_child(_cancel_btn)
	var def := EditorChrome.make_btn("Дефолтне Древо", Palette.GOLD)
	def.pressed.connect(func():
		session.load_default_tree()
		_pending_tree.clear()
		_accept_btn.disabled = true
		_preview.text = ""
		_preview_canvas.queue_redraw()
		_hint.visible = true
		_log.text = "Підставлено дефолтне Древо (ассет).")
	row.add_child(def)

	_progress = ProgressBar.new()
	_progress.min_value = 0
	_progress.max_value = 1
	_progress.value = 0
	_progress.show_percentage = true
	_progress.custom_minimum_size = Vector2(0, 32)
	body.add_child(_progress)

	_log = EditorChrome.make_label("", 18, Palette.LINEN)
	body.add_child(_log)

	_hint = EditorChrome.make_label(
		"Підказка: введіть seed і натисніть «Згенерувати». Тут з’являться метрики перевірок і міні-схема Древа. Seed 424242 — миттєвий дефолтний ассет.",
		18, Palette.TEXT_DIM)
	body.add_child(_hint)

	_preview = EditorChrome.make_label("", 18, Palette.TEXT_DIM)
	body.add_child(_preview)

	_preview_host = PanelContainer.new()
	_preview_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_host.custom_minimum_size = Vector2(0, 220)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.05, 0.05)
	psb.border_color = Color(Palette.GOLD, 0.35)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(10)
	_preview_host.add_theme_stylebox_override("panel", psb)
	body.add_child(_preview_host)
	_preview_canvas = Control.new()
	_preview_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_canvas.custom_minimum_size = Vector2(0, 200)
	_preview_canvas.draw.connect(_draw_preview)
	_preview_host.add_child(_preview_canvas)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	body.add_child(bottom)
	_accept_btn = EditorChrome.make_btn("Прийняти в редактор", Color("2E7D32"))
	_accept_btn.disabled = true
	_accept_btn.pressed.connect(_on_accept)
	bottom.add_child(_accept_btn)


func _draw_preview() -> void:
	var r := Rect2(Vector2.ZERO, _preview_canvas.size)
	_preview_canvas.draw_rect(r, Color(0.06, 0.05, 0.05))
	if _pending_tree.is_empty():
		var font := ThemeDB.fallback_font
		var msg := "Міні-схема з’явиться після генерації"
		var fs := 18
		var ts := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		_preview_canvas.draw_string(font, Vector2((r.size.x - ts.x) * 0.5, r.size.y * 0.5), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.TEXT_DIM)
		return
	var nodes: Variant = _pending_tree.get("nodes", [])
	var links: Variant = _pending_tree.get("links", [])
	if typeof(nodes) != TYPE_ARRAY or (nodes as Array).is_empty():
		return
	var mn := Vector2(1e12, 1e12)
	var mx := Vector2(-1e12, -1e12)
	var by_id: Dictionary = {}
	for n in nodes:
		if typeof(n) != TYPE_DICTIONARY:
			continue
		var id := str(n.get("id", ""))
		var p := Vector2(float(n.get("x", 0)), float(n.get("y", 0)))
		by_id[id] = {"p": p, "rg": str(n.get("region", "")), "type": str(n.get("type", "small"))}
		mn = mn.min(p)
		mx = mx.max(p)
	var ext := (mx - mn)
	var pad := 16.0
	var sx := (r.size.x - pad * 2.0) / maxf(ext.x, 1.0)
	var sy := (r.size.y - pad * 2.0) / maxf(ext.y, 1.0)
	var sc := minf(sx, sy)
	var mid := (mn + mx) * 0.5
	var to_s := func(p: Vector2) -> Vector2:
		return (p - mid) * sc + r.size * 0.5
	if typeof(links) == TYPE_ARRAY:
		for L in links:
			if typeof(L) != TYPE_ARRAY or (L as Array).size() < 2:
				continue
			var a: String = str(L[0])
			var b: String = str(L[1])
			if not by_id.has(a) or not by_id.has(b):
				continue
			_preview_canvas.draw_line(to_s.call(by_id[a]["p"]), to_s.call(by_id[b]["p"]), Color("6B4A35", 0.7), 1.0, true)
	var cols := {"str": Color("C62828"), "agi": Color("2E7D32"), "faith": Color("E0A526")}
	for id in by_id.keys():
		var info: Dictionary = by_id[id]
		var col: Color = cols.get(info["rg"], Color("C9A227"))
		var rad := 2.2
		if info["type"] in ["keystone", "start", "core"]:
			rad = 3.6
		elif info["type"] == "notable":
			rad = 2.8
		_preview_canvas.draw_circle(to_s.call(info["p"]), rad, col)


func _on_run() -> void:
	if _busy:
		return
	var txt := _seed.text.strip_edges()
	if not txt.is_valid_int():
		_log.add_theme_color_override("font_color", Palette.EMBROIDERY)
		_log.text = "Seed має бути цілим числом."
		return
	var seed := int(txt)
	_busy = true
	_cancel_req = false
	_pending_tree.clear()
	_accept_btn.disabled = true
	_run_btn.disabled = true
	_cancel_btn.disabled = false
	_hint.visible = false
	_log.add_theme_color_override("font_color", Palette.LINEN)
	_log.text = "Генерація…"
	_preview.text = ""
	_preview_canvas.queue_redraw()
	_progress.value = 0.01
	if seed == TreeGeneratorV7.DEFAULT_SEED:
		var d := TreeGeneratorV7.load_default_tree()
		if not d.is_empty():
			_pending_tree = d
			_progress.value = 1
			_log.text = "Дефолтний ассет готовий до прийняття."
			_preview.text = _fmt_preview(d, {"source": "default"})
			_accept_btn.disabled = false
			_busy = false
			_run_btn.disabled = false
			_cancel_btn.disabled = true
			_preview_canvas.queue_redraw()
			return
	WorkerThreadPool.add_task(func():
		var prog := func(frac, msg):
			call_deferred("_on_prog", float(frac), str(msg))
		var r: Dictionary
		var core_script = load("res://scripts/editor/gen/tree_gen_v7_core.gd")
		_gen_core = core_script.new() if core_script else null
		if _gen_core == null:
			r = {"ok": false, "error": "Генератор не завантажився.", "tree": {}, "metrics": {}}
		else:
			var err: String = str(_gen_core.build(seed, prog))
			if _cancel_req or err == "Скасовано":
				r = {"ok": false, "error": "Скасовано.", "tree": {}, "metrics": {}}
			elif err != "" and err != "null":
				r = {"ok": false, "error": err, "tree": {}, "metrics": {}}
			else:
				var m: Dictionary = _gen_core.metrics()
				var tree: Dictionary = _gen_core.tree_dict()
				r = {"ok": _gen_core.validators_ok(m), "error": "" if _gen_core.validators_ok(m) else "Не пройшло перевірки.", "tree": tree, "metrics": m, "source": "gdscript"}
		_gen_core = null
		call_deferred("_on_gen_done", r)
	)


func _on_prog(frac: float, msg: String) -> void:
	_progress.value = clampf(frac, 0.0, 1.0)
	if msg != "":
		_log.text = msg


func _on_gen_done(r: Dictionary) -> void:
	_busy = false
	_run_btn.disabled = false
	_cancel_btn.disabled = true
	_gen_core = null
	if _cancel_req or str(r.get("error", "")) == "Скасовано.":
		_progress.value = 0
		_log.text = "Скасовано."
		_hint.visible = true
		return
	if not r.get("ok", false):
		_log.add_theme_color_override("font_color", Palette.EMBROIDERY)
		_log.text = str(r.get("error", "Помилка генерації."))
		var m: Dictionary = r.get("metrics", {})
		if not m.is_empty():
			_preview.text = "Метрики (не прийнято): перетини=%s сироти=%s свої=%s" % [m.get("crossings"), m.get("orphans"), str(m.get("own"))]
		_hint.visible = true
		return
	_progress.value = 1
	_pending_tree = r.get("tree", {})
	_log.add_theme_color_override("font_color", Palette.LINEN)
	_log.text = "Готово — перегляньте прев’ю і натисніть «Прийняти»."
	_preview.text = _fmt_preview(_pending_tree, r)
	_accept_btn.disabled = _pending_tree.is_empty()
	_hint.visible = false
	_preview_canvas.queue_redraw()


func _fmt_preview(tree: Dictionary, r: Dictionary) -> String:
	var nodes = tree.get("nodes", [])
	var links = tree.get("links", [])
	var meta = tree.get("meta", {})
	var m: Dictionary = r.get("metrics", {})
	var own = m.get("own", {})
	var seed_s := "?"
	if typeof(meta) == TYPE_DICTIONARY:
		var sv: Variant = meta.get("seed", null)
		if typeof(sv) in [TYPE_INT, TYPE_FLOAT]:
			seed_s = str(int(sv))
		elif sv != null:
			seed_s = str(sv)
	var own_s := "—"
	if typeof(own) == TYPE_DICTIONARY and not (own as Dictionary).is_empty():
		own_s = str(own)
	var mind_s := "—"
	if m.has("min_node_dist"):
		mind_s = "%.1f" % float(m.get("min_node_dist", 0))
	return "Вузлів: %d · зв’язків: %d · seed %s · джерело: %s\nПеревірки: перетини=%s сироти=%s мін.відст=%s свої=%s" % [
		nodes.size() if typeof(nodes) == TYPE_ARRAY else 0,
		links.size() if typeof(links) == TYPE_ARRAY else 0,
		seed_s,
		str(r.get("source", "")),
		str(m.get("crossings", "—")),
		str(m.get("orphans", "—")),
		mind_s,
		own_s,
	]


func _on_accept() -> void:
	if _pending_tree.is_empty():
		return
	session.tree_doc.load_from_tree_dict(_pending_tree)
	session.gen_source = "gdscript"
	session.status.emit("Прийнято згенероване Древо.", "info")
	_log.text = "Прийнято в редактор."
	_accept_btn.disabled = true
