## Вкладка «Древо»: повний редактор на спільному TreeEditorDoc сесії.
class_name EditorTabTree
extends Control

var session: EditorSession
var _view: TreeEditorView
var _status: Label
var _host: Control


func setup(s: EditorSession) -> void:
	session = s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Prefer embedding the full TreeEditorScreen if we can inject doc —
	# TreeEditorScreen owns its own doc, so we use TreeEditorView + toolbar instead.
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 56
	top.add_theme_constant_override("separation", 8)
	add_child(top)

	var fit := EditorChrome.make_btn("Вмістити", Palette.PANEL_LIGHT, 18)
	fit.custom_minimum_size = Vector2(120, 48)
	top.add_child(fit)
	var undo := EditorChrome.make_btn("↶", Palette.PANEL_LIGHT, 18)
	undo.custom_minimum_size = Vector2(48, 48)
	top.add_child(undo)
	var redo := EditorChrome.make_btn("↷", Palette.PANEL_LIGHT, 18)
	redo.custom_minimum_size = Vector2(48, 48)
	top.add_child(redo)
	var save := EditorChrome.make_btn("Зберегти", Color("2E7D32"), 18)
	save.custom_minimum_size = Vector2(130, 48)
	top.add_child(save)
	var reload := EditorChrome.make_btn("Дефолт v7.3", Palette.EMBROIDERY, 16)
	reload.custom_minimum_size = Vector2(150, 48)
	top.add_child(reload)

	_status = EditorChrome.make_label("", 16, Palette.TEXT_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status)

	_view = TreeEditorView.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.offset_top = 56
	add_child(_view)
	_view.bind_doc(session.tree_doc)
	if _view.has_signal("status"):
		_view.status.connect(func(m): _status.text = str(m))
	fit.pressed.connect(func():
		if _view.has_method("fit_all"):
			_view.fit_all())
	undo.pressed.connect(func():
		if session.tree_doc.has_method("undo"):
			session.tree_doc.undo())
	redo.pressed.connect(func():
		if session.tree_doc.has_method("redo"):
			session.tree_doc.redo())
	save.pressed.connect(func():
		session.autosave()
		_status.text = "Чернетку збережено.")
	reload.pressed.connect(func():
		session.load_default_tree()
		if _view.has_method("fit_all"):
			_view.fit_all()
		_status.text = "Підставлено дефолтне Древо.")
	session.tree_changed.connect(func():
		_status.text = "Вузлів: %d · зв’язків: %d" % [session.tree_doc.nodes.size(), session.tree_doc.links.size()])
	call_deferred("_fit")


func _fit() -> void:
	if _view and _view.has_method("fit_all"):
		_view.fit_all()
