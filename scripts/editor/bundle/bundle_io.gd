## Пакунок редактора: zip з tree.json + ui_layout.json + theme.json + manifest.json
class_name BundleIO
extends RefCounted

const MANIFEST_NAME := "manifest.json"
const TREE_NAME := "tree.json"
const LAYOUT_NAME := "ui_layout.json"
const THEME_NAME := "theme.json"
const BUNDLE_VERSION := 1


static func export_bundle(path: String, tree: Dictionary, layout: Dictionary, theme: Dictionary, meta: Dictionary = {}) -> String:
	## Повертає "" або українське повідомлення про помилку.
	if path == "":
		return "Не вказано шлях для експорту."
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := "user://editor_drafts/_bundle_tmp"
	_wipe_dir(tmp)
	DirAccess.make_dir_recursive_absolute(tmp)
	var man := {
		"version": BUNDLE_VERSION,
		"created_at": Time.get_datetime_string_from_system(true),
		"app": "spohady-editor",
		"files": [TREE_NAME, LAYOUT_NAME, THEME_NAME],
	}
	for k in meta:
		man[k] = meta[k]
	var err := _write_json("%s/%s" % [tmp, MANIFEST_NAME], man)
	if err != "":
		return err
	err = _write_json("%s/%s" % [tmp, TREE_NAME], tree)
	if err != "":
		return err
	err = _write_json("%s/%s" % [tmp, LAYOUT_NAME], layout)
	if err != "":
		return err
	err = _write_json("%s/%s" % [tmp, THEME_NAME], theme)
	if err != "":
		return err
	# zip via OS.zip if available (Godot 4.4+), else copy folder
	if path.ends_with(".zip"):
		var files := PackedStringArray([
			"%s/%s" % [tmp, MANIFEST_NAME],
			"%s/%s" % [tmp, TREE_NAME],
			"%s/%s" % [tmp, LAYOUT_NAME],
			"%s/%s" % [tmp, THEME_NAME],
		])
		var zerr := _zip_files(path, files, [MANIFEST_NAME, TREE_NAME, LAYOUT_NAME, THEME_NAME])
		if zerr != "":
			return zerr
	else:
		# export as folder
		DirAccess.make_dir_recursive_absolute(path)
		for n in [MANIFEST_NAME, TREE_NAME, LAYOUT_NAME, THEME_NAME]:
			var from_p := "%s/%s" % [tmp, n]
			var to_p := "%s/%s" % [path, n]
			var data := FileAccess.get_file_as_bytes(from_p)
			var f := FileAccess.open(to_p, FileAccess.WRITE)
			if f == null:
				return "Не вдалося записати %s" % n
			f.store_buffer(data)
	return ""


static func import_bundle(path: String) -> Dictionary:
	## {ok, error, tree, layout, theme, manifest}
	var out := {"ok": false, "error": "", "tree": {}, "layout": {}, "theme": {}, "manifest": {}}
	if path == "" or not (FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)):
		out["error"] = "Файл пакунка не знайдено."
		return out
	var tmp := "user://editor_drafts/_bundle_in"
	_wipe_dir(tmp)
	DirAccess.make_dir_recursive_absolute(tmp)
	if path.ends_with(".zip"):
		var uerr := _unzip(path, tmp)
		if uerr != "":
			out["error"] = uerr
			return out
	else:
		for n in [MANIFEST_NAME, TREE_NAME, LAYOUT_NAME, THEME_NAME]:
			var src := "%s/%s" % [path, n]
			if FileAccess.file_exists(src):
				var bytes := FileAccess.get_file_as_bytes(src)
				var f := FileAccess.open("%s/%s" % [tmp, n], FileAccess.WRITE)
				if f:
					f.store_buffer(bytes)
	var man = _read_json("%s/%s" % [tmp, MANIFEST_NAME])
	if typeof(man) != TYPE_DICTIONARY:
		out["error"] = "Немає manifest.json — це не пакунок редактора."
		return out
	var tree = _read_json("%s/%s" % [tmp, TREE_NAME])
	var layout = _read_json("%s/%s" % [tmp, LAYOUT_NAME])
	var theme = _read_json("%s/%s" % [tmp, THEME_NAME])
	if typeof(tree) != TYPE_DICTIONARY:
		out["error"] = "У пакунку немає коректного tree.json."
		return out
	if typeof(layout) != TYPE_DICTIONARY:
		out["error"] = "У пакунку немає коректного ui_layout.json."
		return out
	if typeof(theme) != TYPE_DICTIONARY:
		out["error"] = "У пакунку немає коректного theme.json."
		return out
	out["ok"] = true
	out["manifest"] = man
	out["tree"] = tree
	out["layout"] = layout
	out["theme"] = theme
	return out


static func install_overrides(tree: Dictionary, layout: Dictionary, theme: Dictionary) -> String:
	## Пише в user://overrides/ — гра підхоплює без знищення сейвів.
	DirAccess.make_dir_recursive_absolute("user://overrides")
	for pair in [[TREE_NAME, tree], [LAYOUT_NAME, layout], [THEME_NAME, theme]]:
		var err := _write_json("user://overrides/%s" % pair[0], pair[1])
		if err != "":
			return err
	return ""


static func _write_json(path: String, data: Dictionary) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "Не вдалося записати %s" % path.get_file()
	f.store_string(JSON.stringify(data, "\t"))
	return ""


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


static func _wipe_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n != "." and n != "..":
			if d.current_is_dir():
				_wipe_dir("%s/%s" % [path, n])
			else:
				d.remove(n)
		n = d.get_next()
	DirAccess.remove_absolute(path)


static func _zip_files(zip_path: String, abs_files: PackedStringArray, entry_names: PackedStringArray) -> String:
	# Godot 4: ZIPPacker
	var zipper := ZIPPacker.new()
	var err := zipper.open(zip_path)
	if err != OK:
		return "Не вдалося створити zip (%s)." % err
	for i in range(abs_files.size()):
		var bytes := FileAccess.get_file_as_bytes(abs_files[i])
		zipper.start_file(entry_names[i])
		zipper.write_file(bytes)
		zipper.close_file()
	zipper.close()
	return ""


static func _unzip(zip_path: String, dest: String) -> String:
	var reader := ZIPReader.new()
	var err := reader.open(zip_path)
	if err != OK:
		return "Не вдалося відкрити zip (%s)." % err
	for n in reader.get_files():
		var bytes := reader.read_file(n)
		var out_p := "%s/%s" % [dest, n.get_file()]
		var f := FileAccess.open(out_p, FileAccess.WRITE)
		if f == null:
			reader.close()
			return "Не вдалося розпакувати %s" % n
		f.store_buffer(bytes)
	reader.close()
	return ""
