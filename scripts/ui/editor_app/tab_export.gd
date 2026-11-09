## Вкладка «Експорт»: пакунок zip / папка, імпорт, install overrides.
class_name EditorTabExport
extends ScrollContainer

var session: EditorSession
var _path: LineEdit
var _log: Label
var _picker: NativeFilePicker


func setup(s: EditorSession) -> void:
	session = s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_picker = NativeFilePicker.new()
	add_child(_picker)
	_picker.file_picked.connect(_on_picked)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 20)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(body)
	add_child(margin)

	body.add_child(EditorChrome.make_label("Експорт / імпорт", 30, Palette.GOLD))
	body.add_child(EditorChrome.make_label(
		"Пакунок: маніфест + древо + розкладка + тема (zip або тека). Застосування в гру не чіпає сейви героя.",
		18, Palette.TEXT_DIM))

	_path = EditorChrome.make_line("шлях до .zip")
	_path.text = ProjectSettings.globalize_path("user://editor_drafts/spohady_editor_bundle.zip")
	body.add_child(_path)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var ex := EditorChrome.make_btn("Експорт пакунка", Color("2E7D32"))
	ex.pressed.connect(func():
		if session.export_bundle(_path.text.strip_edges()):
			_ok("Експортовано."))
	row.add_child(ex)
	var im := EditorChrome.make_btn("Імпорт пакунка", Palette.EMBROIDERY)
	im.pressed.connect(func():
		if session.import_bundle(_path.text.strip_edges()):
			_ok("Імпортовано."))
	row.add_child(im)
	var pick := EditorChrome.make_btn("Обрати файл…", Palette.GOLD)
	pick.pressed.connect(func():
		_picker.pick_json())
	row.add_child(pick)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	body.add_child(row2)
	var inst := EditorChrome.make_btn("Застосувати в гру", Palette.GOLD)
	inst.pressed.connect(func():
		if session.install_to_game():
			_ok("Записано в гру."))
	row2.add_child(inst)

	_log = EditorChrome.make_label("", 18)
	body.add_child(_log)
	session.status.connect(func(msg, level):
		_log.add_theme_color_override("font_color", Palette.EMBROIDERY if level == "error" else Palette.LINEN)
		_log.text = msg)


func _on_picked(path: String) -> void:
	if path == "":
		return
	_path.text = path
	if path.ends_with(".zip") or DirAccess.dir_exists_absolute(path):
		if session.import_bundle(path):
			_ok("Імпортовано з %s" % path.get_file())


func _ok(msg: String) -> void:
	_log.add_theme_color_override("font_color", Color("7CBF5A"))
	_log.text = msg
