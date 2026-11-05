## Чернетки редактора Древа в user:// — окремо від сейвів героя.
## Apply пише override у user://tree_active/ (не res://, не слоти героя).
class_name TreeDraftStore

const DRAFTS_ROOT := "user://tree_drafts/"
const ACTIVE_DIR := "user://tree_active/"
const ACTIVE_TREE := "user://tree_active/perk_tree.json"
const BACKUPS_ROOT := "user://tree_backups/"
const DEFAULT_ID := "default"


static func ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(DRAFTS_ROOT)
	DirAccess.make_dir_recursive_absolute(ACTIVE_DIR)
	DirAccess.make_dir_recursive_absolute(BACKUPS_ROOT)


static func draft_dir(draft_id: String = DEFAULT_ID) -> String:
	return DRAFTS_ROOT.path_join(draft_id) + "/"


static func list_drafts() -> PackedStringArray:
	ensure_dirs()
	var out: PackedStringArray = PackedStringArray()
	var d := DirAccess.open(DRAFTS_ROOT)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir() and not n.begins_with("."):
			out.append(n)
		n = d.get_next()
	return out


static func save_draft(doc: TreeEditorDoc, draft_id: String = DEFAULT_ID) -> String:
	## Повертає порожній рядок або текст помилки.
	ensure_dirs()
	var dir := draft_dir(draft_id)
	DirAccess.make_dir_recursive_absolute(dir)
	var tree_path := dir.path_join("tree.json")
	var meta_path := dir.path_join("project.json")
	var f := FileAccess.open(tree_path, FileAccess.WRITE)
	if f == null:
		return "Не вдалося записати tree.json"
	f.store_string(JSON.stringify(doc.to_tree_dict(), "\t"))
	f.close()
	# background copy
	var meta := doc.project_meta()
	if doc.bg_image != null:
		var ext := "png"
		var bg_name := "bg.%s" % ext
		var bg_path := dir.path_join(bg_name)
		var err := doc.bg_image.save_png(bg_path)
		if err != OK:
			return "Не вдалося зберегти фон (код %d)" % err
		meta["background"]["file"] = bg_name
		doc.bg_rel_file = bg_name
	else:
		meta["background"]["file"] = ""
	var mf := FileAccess.open(meta_path, FileAccess.WRITE)
	if mf == null:
		return "Не вдалося записати project.json"
	mf.store_string(JSON.stringify(meta, "\t"))
	mf.close()
	return ""


static func load_draft(doc: TreeEditorDoc, draft_id: String = DEFAULT_ID) -> String:
	ensure_dirs()
	var dir := draft_dir(draft_id)
	var tree_path := dir.path_join("tree.json")
	if not FileAccess.file_exists(tree_path):
		return "Чернетки немає: %s" % draft_id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(tree_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return "Битий tree.json"
	doc.load_from_tree_dict(parsed)
	var meta_path := dir.path_join("project.json")
	if FileAccess.file_exists(meta_path):
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if typeof(meta) == TYPE_DICTIONARY:
			doc.apply_project_meta(meta)
			var bg_file := str(meta.get("background", {}).get("file", ""))
			if bg_file != "":
				var bg_path := dir.path_join(bg_file)
				if FileAccess.file_exists(bg_path):
					var img := Image.new()
					var err := img.load(bg_path)
					if err == OK:
						doc.set_background_image(img, bg_file)
	return ""


static func load_shipped_into(doc: TreeEditorDoc) -> String:
	PerkTree.ensure_loaded()
	var path := PerkTree.TREE_PATH
	# Prefer active override for editing "what game uses now"
	if FileAccess.file_exists(ACTIVE_TREE):
		path = ACTIVE_TREE
	if not FileAccess.file_exists(path):
		return "Немає файлу Древа"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return "Битий JSON Древа"
	doc.load_from_tree_dict(parsed)
	return ""


static func export_tree_json(doc: TreeEditorDoc, abs_or_user_path: String) -> String:
	var f := FileAccess.open(abs_or_user_path, FileAccess.WRITE)
	if f == null:
		return "Запис не вдався: %s" % abs_or_user_path
	f.store_string(JSON.stringify(doc.to_tree_dict(), "\t"))
	f.close()
	return ""


static func import_tree_json(doc: TreeEditorDoc, path: String) -> String:
	## path може бути content:// (Android SAF) або звичайний шлях — FileAccess.open.
	if not FileAccess.file_exists(path) and not path.begins_with("content://"):
		# content URIs may not report via file_exists on all builds — try open
		pass
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return "Не відкрити файл: %s" % path
	var text := fa.get_as_text()
	fa.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return "Це не JSON Древа"
	doc.load_from_tree_dict(parsed)
	return ""


static func import_image_bytes_to_doc(doc: TreeEditorDoc, path: String, draft_id: String = DEFAULT_ID) -> String:
	## Читає зображення (шлях або content://), копіює в draft як PNG, ставить у doc.
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return "Не відкрити зображення: %s" % path
	var bytes := fa.get_buffer(fa.get_length())
	fa.close()
	if bytes.is_empty():
		return "Порожній файл зображення"
	ensure_dirs()
	var dir := draft_dir(draft_id)
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp := dir.path_join("_import_tmp.bin")
	var wf := FileAccess.open(tmp, FileAccess.WRITE)
	if wf == null:
		return "Не записати тимчасовий файл у чернетку"
	wf.store_buffer(bytes)
	wf.close()
	var img := Image.new()
	var err := img.load(tmp)
	# Also try by extension hints
	if err != OK:
		# Godot Image.load needs recognizable format; try PNG/JPG loaders via buffer
		err = img.load_png_from_buffer(bytes)
		if err != OK:
			err = img.load_jpg_from_buffer(bytes)
		if err != OK and img.has_method("load_webp_from_buffer"):
			err = img.load_webp_from_buffer(bytes)
	DirAccess.remove_absolute(tmp)
	if err != OK or img.is_empty():
		return "Не розпізнано PNG/JPEG (код %d). WebP — якщо підтримує рушій." % err
	doc.set_background_image(img, "bg.png")
	# persist immediately into draft folder
	var save_err := save_draft(doc, draft_id)
	if save_err != "":
		return save_err
	return ""


static func apply_to_game(doc: TreeEditorDoc) -> String:
	## Явне застосування: backup поточного active (або shipped snapshot), потім запис ACTIVE_TREE.
	## Не змінює сейви героя. Не переписує res:// (на APK неможливо).
	ensure_dirs()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var backup_path := BACKUPS_ROOT.path_join("perk_tree_%s.json" % stamp)
	var src := ACTIVE_TREE if FileAccess.file_exists(ACTIVE_TREE) else PerkTree.TREE_PATH
	if FileAccess.file_exists(src):
		var data := FileAccess.get_file_as_bytes(src)
		var bf := FileAccess.open(backup_path, FileAccess.WRITE)
		if bf:
			bf.store_buffer(data)
			bf.close()
	var err := export_tree_json(doc, ACTIVE_TREE)
	if err != "":
		return err
	# Reload runtime tree from active override
	PerkTree.reload_from_path(ACTIVE_TREE)
	return ""


static func clear_active_override() -> void:
	if FileAccess.file_exists(ACTIVE_TREE):
		DirAccess.remove_absolute(ACTIVE_TREE)


static func has_active_override() -> bool:
	return FileAccess.file_exists(ACTIVE_TREE)
