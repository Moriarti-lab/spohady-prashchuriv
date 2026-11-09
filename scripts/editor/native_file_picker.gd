## Документований пайплайн вибору файлів (Godot 4.7 FileDialog).
## Android: ACCESS_FILESYSTEM + use_native_dialog → SAF URI → FileAccess.open → копія в user://.
## Доказ з docs: native dialog на Android лише з ACCESS_FILESYSTEM; інакше custom fallback.
## Фізичний телефон: перевірка окремо (див. docs/tree_editor/README.md § Android).
class_name NativeFilePicker
extends Node

signal file_picked(path: String)
signal cancelled

var _dialog: FileDialog
var last_error: String = ""
var last_platform_note: String = ""


func _ready() -> void:
	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.add_filter("*.png, *.jpg, *.jpeg", "Зображення", "image/png,image/jpeg")
	_dialog.add_filter("*.json", "JSON Древа", "application/json")
	_dialog.file_selected.connect(_on_file)
	_dialog.canceled.connect(func() -> void: cancelled.emit())
	add_child(_dialog)
	last_platform_note = _platform_note()


func _platform_note() -> String:
	var osn := OS.get_name()
	var feat_android := OS.has_feature("android")
	var native_ok := DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
	return "OS=%s android_feature=%s FEATURE_NATIVE_DIALOG_FILE=%s access=FILESYSTEM use_native=true" % [
		osn, feat_android, native_ok
	]


func pick_image() -> void:
	last_error = ""
	_dialog.clear_filters()
	_dialog.add_filter("*.png, *.jpg, *.jpeg", "Зображення PNG/JPEG", "image/png,image/jpeg")
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.title = "Обрати зображення-шаблон"
	_dialog.popup_file_dialog()


func pick_json() -> void:
	last_error = ""
	_dialog.clear_filters()
	_dialog.add_filter("*.json", "JSON", "application/json")
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.title = "Імпорт JSON Древа"
	_dialog.popup_file_dialog()


func save_json_as(default_name: String = "perk_tree.json") -> void:
	last_error = ""
	_dialog.clear_filters()
	_dialog.add_filter("*.json", "JSON", "application/json")
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.title = "Експорт JSON Древа"
	_dialog.current_file = default_name
	_dialog.popup_file_dialog()


func _on_file(path: String) -> void:
	if path == "":
		last_error = "Порожній шлях"
		cancelled.emit()
		return
	file_picked.emit(path)


## Копіює будь-який відкритий FileAccess-шлях (у т.ч. content://) у user:// ціль.
static func copy_to_user(src_path: String, dest_user_path: String) -> String:
	var fa := FileAccess.open(src_path, FileAccess.READ)
	if fa == null:
		return "Не читається джерело: %s" % src_path
	var bytes := fa.get_buffer(fa.get_length())
	fa.close()
	var parent := dest_user_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent)
	var wf := FileAccess.open(dest_user_path, FileAccess.WRITE)
	if wf == null:
		return "Не записується: %s" % dest_user_path
	wf.store_buffer(bytes)
	wf.close()
	return ""
