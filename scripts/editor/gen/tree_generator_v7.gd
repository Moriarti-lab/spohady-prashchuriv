## Генератор Древа v7. На десктопі — точний Python; на Android — GDScript-порт (≈ той самий seed/метрики).
class_name TreeGeneratorV7
extends RefCounted

const DEFAULT_SEED := 424242
const DEFAULT_TREE_RES := "res://data/editor/default_perk_tree.json"
const PY_TOOL := "res://tools/generate_perk_tree_v7.py"


static func load_default_tree() -> Dictionary:
	if not FileAccess.file_exists(DEFAULT_TREE_RES):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_TREE_RES))
	return data if typeof(data) == TYPE_DICTIONARY else {}


static func generate(seed: int, progress: Callable = Callable()) -> Dictionary:
	## {ok, error, tree, source}  source = "python"|"gdscript"|"default"
	var out := {"ok": false, "error": "", "tree": {}, "source": ""}
	if seed == DEFAULT_SEED:
		# Швидкий шлях: дефолтний ассет уже згенерований цим seed.
		var d := load_default_tree()
		if not d.is_empty() and int(d.get("meta", {}).get("seed", -1)) == seed:
			out["ok"] = true
			out["tree"] = d
			out["source"] = "default"
			return out
	if _python_available():
		var r := _generate_python(seed, progress)
		if r.get("ok", false):
			return r
		# падаємо на GDScript, якщо python звалився
		out["error"] = str(r.get("error", ""))
	# GDScript-порт ще нестабільний (ризик зависання) — на мобільних лише дефолтний ассет.
	if OS.has_feature("android") or OS.has_feature("ios"):
		out["ok"] = false
		out["error"] = "На телефоні зараз доступна генерація лише seed %d (дефолтний ассет). Інші seed — згенеруйте на ПК і імпортуйте пакунок." % DEFAULT_SEED
		return out
	var g := _generate_gdscript(seed, progress)
	if g.get("ok", false):
		return g
	if out["error"] != "":
		g["error"] = "%s; також GDScript: %s" % [out["error"], g.get("error", "")]
	return g


static func _python_available() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios"):
		return false
	var abs_py := ProjectSettings.globalize_path(PY_TOOL)
	if not FileAccess.file_exists(PY_TOOL) and not FileAccess.file_exists(abs_py):
		return false
	# which python3
	var output: Array = []
	var code := OS.execute("python3", PackedStringArray(["--version"]), output, true)
	return code == 0


static func _generate_python(seed: int, progress: Callable) -> Dictionary:
	var out := {"ok": false, "error": "", "tree": {}, "source": "python"}
	var tool := ProjectSettings.globalize_path(PY_TOOL)
	if not FileAccess.file_exists(tool):
		# try workspace-relative
		tool = "tools/generate_perk_tree_v7.py"
	var tmp := "user://editor_drafts/_gen_out.json"
	DirAccess.make_dir_recursive_absolute("user://editor_drafts")
	var abs_out := ProjectSettings.globalize_path(tmp)
	if progress.is_valid():
		progress.call(0.05, "Запуск Python-генератора…")
	var args := PackedStringArray([tool, "--seed", str(seed), "--out", abs_out, "--force"])
	var output: Array = []
	var code := OS.execute("python3", args, output, true, true)
	if code != 0:
		out["error"] = "Python-генератор завершився з кодом %d: %s" % [code, "\n".join(PackedStringArray(output))]
		return out
	if not FileAccess.file_exists(tmp):
		out["error"] = "Генератор не створив файл результату."
		return out
	var data = JSON.parse_string(FileAccess.get_file_as_string(tmp))
	if typeof(data) != TYPE_DICTIONARY:
		out["error"] = "Результат генератора пошкоджений."
		return out
	if progress.is_valid():
		progress.call(1.0, "Готово")
	out["ok"] = true
	out["tree"] = data
	return out


static func _generate_gdscript(seed: int, progress: Callable) -> Dictionary:
	var out := {"ok": false, "error": "", "tree": {}, "source": "gdscript"}
	if progress.is_valid():
		progress.call(0.1, "Генерація (GDScript)…")
	var core_script = load("res://scripts/editor/gen/tree_gen_v7_core.gd")
	if core_script == null:
		out["error"] = "GDScript-порт генератора не завантажився."
		return out
	var gen = core_script.new()
	if gen == null:
		out["error"] = "Не вдалося створити генератор (парсер GDScript-порту)."
		return out
	var err: String = str(gen.build(seed, progress))
	if err != "" and err != "null":
		out["error"] = err
		return out
	out["ok"] = true
	out["tree"] = gen.tree_dict()
	return out
