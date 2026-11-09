## Спільний стан редактора: древо, розкладка, тема, автозбереження.
class_name EditorSession
extends RefCounted

signal tree_changed
signal layout_changed
signal theme_changed
signal status(msg: String, level: String)  # info|warn|error

const AUTOSAVE_SEC := 2.5

var tree_doc: TreeEditorDoc
var layout: LayoutStore
var theme: ThemeStore
var dirty: bool = false
var last_error: String = ""
var gen_source: String = ""  # python|gdscript|default|import

var _autosave_left: float = -1.0


func _init() -> void:
	tree_doc = TreeEditorDoc.new()
	layout = LayoutStore.new()
	theme = ThemeStore.new()
	tree_doc.changed.connect(func(): dirty = true; tree_changed.emit(); _kick_autosave())
	layout.changed.connect(func(): dirty = true; layout_changed.emit(); _kick_autosave())
	theme.changed.connect(func(): dirty = true; theme_changed.emit(); _kick_autosave())


func boot() -> void:
	DirAccess.make_dir_recursive_absolute("user://editor_drafts")
	DirAccess.make_dir_recursive_absolute("user://overrides")
	# theme draft
	var e := theme.load_draft()
	if e != "":
		_emit_err(e)
	theme.apply_to_palette()
	# layout draft
	e = layout.load_draft()
	if e != "":
		_emit_err(e)
	layout.ensure_defaults()
	# tree draft або дефолтний ассет
	e = TreeDraftStore.load_draft(tree_doc, TreeDraftStore.DEFAULT_ID)
	if e != "":
		var d := TreeGeneratorV7.load_default_tree()
		if d.is_empty():
			_emit_err("Немає дефолтного Древа (data/editor/default_perk_tree.json).")
		else:
			tree_doc.load_from_tree_dict(d)
			gen_source = "default"
			status.emit("Завантажено дефолтне Древо v7.3.", "info")
	else:
		gen_source = "draft"
		# Чернетка без meta.seed — підтягнути з дефолтного ассета якщо схоже.
		if not tree_doc.tree_meta.has("seed"):
			var d := TreeGeneratorV7.load_default_tree()
			var dm = d.get("meta", {})
			if typeof(dm) == TYPE_DICTIONARY and not d.is_empty():
				if int(dm.get("seed", -1)) >= 0:
					for k in dm.keys():
						if not tree_doc.tree_meta.has(k):
							tree_doc.tree_meta[k] = dm[k]
		status.emit("Відновлено чернетку Древа.", "info")
	dirty = false


func tick(delta: float) -> void:
	if _autosave_left < 0.0:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = -1.0
		autosave()


func _kick_autosave() -> void:
	_autosave_left = AUTOSAVE_SEC


func autosave() -> void:
	var errs: PackedStringArray = PackedStringArray()
	var e := TreeDraftStore.save_draft(tree_doc, TreeDraftStore.DEFAULT_ID)
	if e != "":
		errs.append(e)
	e = layout.save_draft()
	if e != "":
		errs.append(e)
	e = theme.save_draft()
	if e != "":
		errs.append(e)
	if errs.is_empty():
		dirty = false
		status.emit("Автозбереження ✓", "info")
	else:
		_emit_err("Автозбереження: " + ", ".join(errs))


func load_default_tree() -> void:
	var d := TreeGeneratorV7.load_default_tree()
	if d.is_empty():
		_emit_err("Дефолтне Древо не знайдено.")
		return
	tree_doc.load_from_tree_dict(d)
	gen_source = "default"
	status.emit("Підставлено дефолтне Древо (ассет).", "info")


func generate_tree(seed: int, progress: Callable = Callable()) -> bool:
	var r := TreeGeneratorV7.generate(seed, progress)
	if not r.get("ok", false):
		_emit_err(str(r.get("error", "Помилка генерації.")))
		return false
	tree_doc.load_from_tree_dict(r["tree"])
	gen_source = str(r.get("source", ""))
	status.emit("Згенеровано (джерело: %s)." % gen_source, "info")
	return true


func export_bundle(path: String) -> bool:
	autosave()
	var err := BundleIO.export_bundle(
		path,
		tree_doc.to_tree_dict(),
		layout.to_dict(),
		theme.to_dict(),
		{"seed": tree_doc.to_tree_dict().get("meta", {}).get("seed", 0), "gen_source": gen_source},
	)
	if err != "":
		_emit_err(err)
		return false
	status.emit("Експортовано: %s" % path.get_file(), "info")
	return true


func import_bundle(path: String) -> bool:
	var r := BundleIO.import_bundle(path)
	if not r.get("ok", false):
		_emit_err(str(r.get("error", "Помилка імпорту.")))
		return false
	var tree_errs: Array = tree_doc.load_from_tree_dict(r["tree"])
	if not tree_errs.is_empty():
		_emit_err("Древо з пакунка: " + ", ".join(PackedStringArray(tree_errs)))
		return false
	var layout_err := layout.from_dict(r["layout"])
	if layout_err != "":
		_emit_err(layout_err)
		return false
	var theme_err := theme.from_dict(r["theme"])
	if theme_err != "":
		_emit_err(theme_err)
		return false
	theme.apply_to_palette()
	gen_source = "import"
	autosave()
	status.emit("Імпортовано пакунок.", "info")
	return true


func install_to_game() -> bool:
	autosave()
	var err := BundleIO.install_overrides(
		tree_doc.to_tree_dict(),
		layout.to_dict(),
		theme.to_dict(),
	)
	if err != "":
		_emit_err(err)
		return false
	# також active tree (сумісність із TreeDraftStore)
	err = TreeDraftStore.apply_to_game(tree_doc)
	if err != "":
		_emit_err(err)
		return false
	status.emit("Застосовано в гру (сейви героя не чіпали).", "info")
	return true


func _emit_err(msg: String) -> void:
	last_error = msg
	status.emit(msg, "error")
